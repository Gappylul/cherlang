-module(chat_server).
-behaviour(gen_server).

%% API
-export([start_link/0, stop/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-define(SERVER, ?MODULE).
-define(PORT, 4040).

-record(state, {lsock, clients = []}). % clients = [{Pid, Username, Socket}]

%%% --- API ---
start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

stop() ->
  gen_server:call(?SERVER, stop).

%%% --- Callbacks ---
init([]) ->
  {ok, LSock} = gen_tcp:listen(?PORT,
    [binary, {packet, line}, {active, false}, {reuseaddr, true}]),
  io:format("Chat server listening on port ~p~n", [?PORT]),
  spawn(fun() -> accept_loop(LSock) end),
  {ok, #state{lsock = LSock}}.

handle_call(stop, _From, State = #state{lsock = LSock}) ->
  gen_tcp:close(LSock),
  {stop, normal, ok, State};
handle_call(_Req, _From, State) ->
  {reply, ok, State}.

handle_cast({broadcast, From, Msg}, State = #state{clients = Clients}) ->
  Line = <<From/binary, ": ", Msg/binary, "\n">>,
  lists:foreach(fun({_Pid, _Username, Sock}) ->
    catch gen_tcp:send(Sock, Line)
                end, Clients),
  {noreply, State};

handle_cast({add_client, Pid, Username, Sock}, State = #state{clients = Clients}) ->
  Line = <<Username/binary, " has joined the chat\n">>,
  lists:foreach(fun({_Pid, _U, S}) -> catch gen_tcp:send(S, Line) end, Clients),
  {noreply, State#state{clients = [{Pid, Username, Sock} | Clients]}};

handle_cast({remove_client, Pid}, State = #state{clients = Clients}) ->
  case lists:keyfind(Pid, 1, Clients) of
    {_, Username, _Sock} ->
      Line = <<Username/binary, " has left the chat\n">>,
      lists:foreach(fun({_Pid2, _U, S}) -> catch gen_tcp:send(S, Line) end, Clients);
    false -> ok
  end,
  NewClients = lists:filter(fun({P, _, _}) -> P =/= Pid end, Clients),
  {noreply, State#state{clients = NewClients}}.

handle_info(_Msg, State) ->
  {noreply, State}.

terminate(_Reason, State) ->
  gen_tcp:close(State#state.lsock),
  ok.

code_change(_, State, _) ->
  {ok, State}.

%%% --- Internal functions ---
accept_loop(LSock) ->
  case gen_tcp:accept(LSock) of
    {ok, Sock} ->
      spawn(fun() -> client_process(Sock) end),
      accept_loop(LSock);
    {error, closed} ->
      ok
  end.

client_process(Sock) ->
  gen_tcp:send(Sock, <<"Enter your username:\n">>),
  case gen_tcp:recv(Sock, 0) of
    {ok, UsernameBin} ->
      Username = strip_newline(UsernameBin),
      Pid = self(),
      gen_server:cast(?SERVER, {add_client, Pid, Username, Sock}),
      % set socket to active once for async messages
      inet:setopts(Sock, [{active, once}]),
      loop(Sock, Username, Pid);
    {error, closed} ->
      ok
  end.

loop(Sock, Username, Pid) ->
  receive
    {tcp, Sock, Data} ->
      Msg = strip_newline(Data),
      gen_server:cast(?SERVER, {broadcast, Username, Msg}),
      inet:setopts(Sock, [{active, once}]),
      loop(Sock, Username, Pid);

    {tcp_closed, Sock} ->
      gen_server:cast(?SERVER, {remove_client, Pid}),
      gen_tcp:close(Sock);

    {tcp_error, Sock, _Reason} ->
      gen_server:cast(?SERVER, {remove_client, Pid}),
      gen_tcp:close(Sock)
  end.

strip_newline(Bin) ->
  re:replace(Bin, "\r?\n$", <<>>, [global, {return, binary}]).
