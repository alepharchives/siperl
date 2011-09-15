%%%----------------------------------------------------------------
%%% @author  Ivan Dubrov <dubrov.ivan@gmail.com>
%%% @doc
%%% RFC 3261 17.1.2 Non-INVITE Client Transaction
%%% @end
%%% @copyright 2011 Ivan Dubrov. See LICENSE file.
%%%----------------------------------------------------------------
-module(sip_transaction_client).
-extends(sip_transaction_base).

%-behaviour(gen_fsm).

%%-----------------------------------------------------------------
%% Include files
%%-----------------------------------------------------------------
-include("../sip_common.hrl").
-include("sip_transaction.hrl").
-include("sip.hrl").

%% FSM callbacks (the rest are provided by `sip_transaction_base')
-export(['INIT'/3, 'TRYING'/2, 'TRYING'/3, 'PROCEEDING'/2, 'PROCEEDING'/3, 'COMPLETED'/2, 'COMPLETED'/3]).

%%-----------------------------------------------------------------
%% FSM callbacks.
%%-----------------------------------------------------------------
%% @doc `INIT' state is for heavy-weight initialization (sending request, starting timers)
%% @end
-spec 'INIT'({init, #tx_state{}}, term(), undefined) -> {reply, ok, 'TRYING', #tx_state{}}.
'INIT'({init, TxState}, _From, undefined) ->
    gproc:mreg(p, l, TxState#tx_state.props),

    % start Timer E only for unreliable transports
    IsReliable = TxState#tx_state.reliable,
    TxState2 = case IsReliable of
                true -> TxState;
                false -> ?START(timerE, ?T1, TxState)
            end,
    % timer F
    TxState3 = ?START(timerF, 64 * ?T1, TxState2),
    % send request
    TxState4 = ?REQUEST(TxState3),
    {reply, ok, 'TRYING', TxState4}.

%% @doc
%% Handle retransmission timer (Timer E).
%% @end
-spec 'TRYING'(term(), #tx_state{}) -> term().
'TRYING'({timeout, _Ref, {timerE, Interval}}, TxState) ->
    TxState2 = ?REQUEST(TxState),
    % request is retransmitted with intervals that double after each transmission
    NewInterval = min(2 * Interval, ?T2),
    TxState3 = ?START(timerE, NewInterval, TxState2),
    {next_state, 'TRYING', TxState3};

%% @doc
%% Transaction timed out.
%% @end
'TRYING'({timeout, _Ref, {timerF, _}}, TxState) ->
    {stop, {timeout, timerF}, TxState}.

%% @doc
%% Handle provisional (1xx) responses. This handles both 'TRYING' and 'PROCEEDING'
%% states as they are similar.
%% @end
-spec 'TRYING'(term(), term(), #tx_state{}) -> term().
'TRYING'({response, Status, Response}, _From, TxState)
  when Status >= 100, Status =< 199 ->
    %% Provisional response, transition to PROCEEDING state.

    ok = ?TU(Response, TxState),
    {reply, ok, 'PROCEEDING', TxState};

'TRYING'({response, Status, Response}, _From, TxState)
  when Status >= 200, Status =< 699 ->
    %% Final response, transition to COMPLETED state.

    ok = ?TU(Response, TxState),

    % cancel the timers E and F
    TxState2 = ?CANCEL(timerE, TxState),
    TxState3 = ?CANCEL(timerF, TxState2),

    % start timer K
    case TxState3#tx_state.reliable of
        true ->
            % skip COMPLETED state and proceed immediately to TERMINATED state
            {stop, normal, ok, TxState3};
        false ->
            TxState4 = ?START(timerK, ?T4, TxState3),
            {reply, ok, 'COMPLETED', TxState4}
    end.

%% @doc
%% In 'PROCEEDING' state, act the same way as in 'TRYING' state.
%% @end
-spec 'PROCEEDING'(term(), term(), #tx_state{}) -> term().
'PROCEEDING'({response, Status, Msg}, From, TxState) ->
    'TRYING'({response, Status, Msg}, From, TxState).

-spec 'PROCEEDING'(term(), #tx_state{}) -> term().
'PROCEEDING'({timeout, _Ref, {timerE, _Interval}}, TxState) ->
    TxState2 = ?REQUEST(TxState),
    TxState3 = ?START(timerE, ?T2, TxState2),
    {next_state, 'PROCEEDING', TxState3};

%% @doc
%% Transaction timed out.
%% @end
'PROCEEDING'({timeout, _Ref, {timerF, _}}, TxState) ->
    {stop, {timeout, timerF}, TxState}.

%% @doc
%% Buffer additional response retransmissions.
%% @end
-spec 'COMPLETED'(term(), term(), #tx_state{}) -> term().
'COMPLETED'({response, _Status, _Response}, _From, TxState) ->
    {reply, ok, 'COMPLETED', TxState}.

%% @doc
%% When Timer K fires while in 'COMPLETED' state, transition to the 'TERMINATED'
%% state.
%% @end
-spec 'COMPLETED'(term(), #tx_state{}) -> term().
'COMPLETED'({timeout, _Ref, {timerK, _}}, TxState) ->
    {stop, normal, TxState}.
