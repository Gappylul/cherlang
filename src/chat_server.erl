-module(chat_server).
-behaviour(gen_server).

-export([start_link/0, stop/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
  terminate/2, code_change/3]).

-define(SERVER, ?MODULE).
-define(PORT, 4040).

-record(state, {lsock, clients=[]}).

%% --- API ---
start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

stop() ->
  gen_server:call(?SERVER, stop).

%% --- Callbacks ---
init([]) ->
  {ok, LSock} = gen_tcp:listen(?PORT, [binary, {packet, line}, {active, false}, {reuseaddr, true}]),
  io:format("Chat server listening on port ~p~n", [?PORT]),
  spawn(fun() -> accept_loop(LSock) end),
  {ok, #state{lsock=LSock}}.

handle_call(stop, _From, State=#state{lsock=LSock}) ->
  gen_tcp:close(LSock),
  {stop, normal, ok, State};
handle_call(_Req, _From, State) ->
  {reply, ok, State}.

handle_cast({broadcast, From, Msg}, State=#state{clients=Clients}) ->
  Line = <<From/binary, ": ", Msg/binary, "\n">>,
  [gen_tcp:send(S, Line) || {S, _} <- Clients],
  {noreply, State};

handle_cast({add_client, Sock, Username}, State=#state{clients=Clients}) ->
  Line = <<Username/binary, " has joined the chat\n">>,
  [gen_tcp:send(S, Line) || {S, _} <- Clients],
  {noreply, State#state{clients=[{Sock, Username} | Clients]}};

handle_cast({remove_client, Sock}, State=#state{clients=Clients}) ->
  case lists:keyfind(Sock, 1, Clients) of
    {_, Username} ->
      Line = <<Username/binary, " has left the chat\n">>,
      [gen_tcp:send(S, Line) || {S, _} <- Clients];
    false -> ok
  end,
  {noreply, State#state{clients=lists:filter(fun({S,_}) -> S =/= Sock end, Clients)}}.

handle_info(_, State) ->
  {noreply, State}.

terminate(_Reason, State) ->
  gen_tcp:close(State#state.lsock),
  ok.

code_change(_, State, _) ->
  {ok, State}.

%% --- Internal ---
accept_loop(LSock) ->
  {ok, Sock} = gen_tcp:accept(LSock),
  spawn(fun() -> client_handshake(Sock) end),
  accept_loop(LSock).

strip_newline(Bin) ->
  re:replace(Bin, "\r?\n$", <<>>, [global, {return, binary}]).

client_handshake(Sock) ->
  gen_tcp:send(Sock, <<"Enter your username:\n">>),
  case gen_tcp:recv(Sock, 0) of
    {ok, UsernameBin} ->
      Username = strip_newline(UsernameBin),
      gen_server:cast(?SERVER, {add_client, Sock, Username}),
      client_loop(Sock, Username);
    {error, closed} ->
      ok
  end.

client_loop(Sock, Username) ->
  case gen_tcp:recv(Sock, 0) of
    {ok, Data} ->
      Msg = strip_newline(Data),
      gen_server:cast(?SERVER, {broadcast, Username, Msg}),
      client_loop(Sock, Username);
    {error, closed} ->
      gen_server:cast(?SERVER, {remove_client, Sock}),
      ok
  end.
