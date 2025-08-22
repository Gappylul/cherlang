%%%-------------------------------------------------------------------
%% @doc chat_server top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(chat_sup).

-behaviour(supervisor).

-export([start_link/0]).

-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    Child = #{
        id => chat_server,
        start => {chat_server, start_link, []},
        restart => permanent,
        shutdown => 5000,
        type => worker,
        modules => [chat_server]
    },
    {ok, {{one_for_one, 5, 10}, [Child]}}.

%% internal functions
