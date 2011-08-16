%%%----------------------------------------------------------------
%%% @author Ivan Dubrov <wfragg@gmail.com>
%%% @doc Pinger UAC implementations. Sends OPTIONS request to the
%%% given destination.
%%% @end
%%% @copyright 2011 Ivan Dubrov
%%%----------------------------------------------------------------
-module(sip_pinger).

-behaviour(sip_ua).

%% Exports

%% Include files
-include_lib("sip.hrl").
-include_lib("sip_test.hrl").

%% API
-export([start_link/0, ping/2]).

%% Server callbacks
-export([init/1, terminate/2, code_change/3]).
-export([handle_info/2, handle_call/3, handle_cast/2, handle_request/3, handle_response/3]).

-record(state, {}).

%%-----------------------------------------------------------------
%% External functions
%%-----------------------------------------------------------------
start_link() ->
    sip_ua:start_link(?MODULE, {}, []).

ping(Pid, To) ->
    gen_server:call(Pid, {ping, To}, 100000).

%%-----------------------------------------------------------------
%% Server callbacks
%%-----------------------------------------------------------------
%% @private
init({}) ->
    {ok, #state{}}.

%% @private
handle_response(Response, UserData, State) ->
    gen_server:reply(UserData, Response),
    {noreply, State}.

%% @private
handle_request(_Request, _UserData, State) ->
    {noreply, State}.

%% @private
handle_info(Req, State) ->
    {noreply, State}.

%% @private
handle_call({ping, To}, Client, State) ->
    From = sip_headers:address(<<"Mr. Pinger">>, <<"sip:pinger@127.0.0.1">>, []),
    Request = sip_ua:create_request('OPTIONS', To, From),
    ok = sip_ua:send_request(Request, Client),
    {noreply, State};
handle_call(Req, _From, State) ->
    {reply, ok, State}.

%% @private
handle_cast(Req, State) ->
    {noreply, State}.

%% @private
terminate(_Reason, _State) ->
    ok.

%% @private
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

