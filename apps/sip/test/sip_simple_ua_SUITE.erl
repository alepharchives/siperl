%%% @author Ivan Dubrov <dubrov.ivan@gmail.com>
%%% @doc Simple (dialogless) regression tests for UA
%%% @end
%%% @copyright 2011 Ivan Dubrov. See LICENSE file.
-module(sip_simple_ua_SUITE).

%% Exports
-export([all/0, init_per_suite/1, end_per_suite/1, init_per_testcase/2, end_per_testcase/2]).
-export([options_200/1, options_302/1, options_501/1]).

%% Include files
-include_lib("common_test/include/ct.hrl").
-include("sip.hrl").

-define(HOST, "sip.example.org").

%% Common tests
all() ->
    [options_200, options_302, options_501].

init_per_suite(Config) ->
    ok = application:start(gproc),
    ok = application:start(sip),
    ok = application:set_env(sip, self, ?HOST),
    Config.

end_per_suite(_Config) ->
    ok = application:stop(sip),
    ok = application:stop(gproc),
    ok.

init_per_testcase(_TestCase, Config) ->
    {ok, UAS} = sip_test_uas:start_link(),
    {ok, UAC} = sip_test_uac:start_link(),
    [{uac, UAC}, {uas, UAS} | Config].

end_per_testcase(_TestCase, Config) ->
    ok = sip_test_uac:stop(?config(uac, Config)),
    ok = sip_test_uas:stop(?config(uas, Config)),
    ok.

options_200(Config) ->
    UAC = ?config(uac, Config),
    UAS = ?config(uas, Config),

    % configure UAS to reply with 200 Ok
    Handler = fun (Request) ->
                       sip_message:create_response(Request, 200)
              end,
    sip_test_uas:set_handler(UAS, Handler),

    RequestURI = sip_headers:address(<<>>, <<"sip:127.0.0.1">>, []),
    {ok, Response} = sip_test_uac:request(UAC, 'OPTIONS', RequestURI),

    % Validate response
    #sip_response{status = 200, reason = <<"Ok">>} = Response#sip_message.kind,

    0 = sip_message:header_top_value('content-length', Response),

    [Via] = sip_message:header_values(via, Response),
    #sip_hdr_via{transport = udp, host = ?HOST, port = 5060} = Via,
    {received, {127, 0, 0, 1}} = lists:keyfind(received, 1, Via#sip_hdr_via.params),

    #sip_hdr_address{} = sip_message:header_top_value(to, Response),
    #sip_hdr_address{} = sip_message:header_top_value(from, Response),
    #sip_hdr_cseq{method = 'OPTIONS'} = sip_message:header_top_value(cseq, Response),
    ['OPTIONS'] = sip_message:header_values(allow, Response),

    _Bin = sip_message:header_top_value('call-id', Response),
    ok.


options_302(Config) ->
    UAC = ?config(uac, Config),
    UAS = ?config(uas, Config),

    % configure UAS to reply with "301 Moved Temporarily" for username "first" and
    % to reply "200 Ok" on username "second".
    Handler = fun(#sip_message{kind = #sip_request{uri = #sip_uri{user = <<"first">>}}} = Request) ->
                      Response = sip_message:create_response(Request, 302),
                      Contact = sip_headers:address(<<>>, <<"sip:second@127.0.0.1">>, []),
                      sip_message:append_header(contact, Contact, Response);
                 (#sip_message{kind = #sip_request{uri = #sip_uri{user = <<"second">>}}} = Request) ->
                      sip_message:create_response(Request, 200)
              end,
    sip_test_uas:set_handler(UAS, Handler),

    RequestURI = sip_headers:address(<<>>, <<"sip:first@127.0.0.1">>, []),
    {ok, Response} = sip_test_uac:request(UAC, 'OPTIONS', RequestURI),

    % Validate response
    #sip_response{status = 200, reason = <<"Ok">>} = Response#sip_message.kind,

    0 = sip_message:header_top_value('content-length', Response),

    [Via] = sip_message:header_values(via, Response),
    #sip_hdr_via{transport = udp, host = ?HOST, port = 5060} = Via,
    {received, {127, 0, 0, 1}} = lists:keyfind(received, 1, Via#sip_hdr_via.params),

    #sip_hdr_address{} = sip_message:header_top_value(to, Response),
    #sip_hdr_address{} = sip_message:header_top_value(from, Response),
    #sip_hdr_cseq{method = 'OPTIONS'} = sip_message:header_top_value(cseq, Response),
    ['OPTIONS'] = sip_message:header_values(allow, Response),

    _Bin = sip_message:header_top_value('call-id', Response),
    ok.



options_501(Config) ->
    UAC = ?config(uac, Config),
    UAS = ?config(uas, Config),

    % configure UAS to reply with 501 Not Implemented
    Handler = fun (Request) ->
                       sip_message:create_response(Request, 501)
              end,
    sip_test_uas:set_handler(UAS, Handler),

    RequestURI = sip_headers:address(<<>>, <<"sip:127.0.0.1">>, []),
    {ok, Response} = sip_test_uac:request(UAC, 'OPTIONS', RequestURI),

    % Validate response
    #sip_response{status = 501, reason = <<"Not Implemented">>} = Response#sip_message.kind,

    0 = sip_message:header_top_value('content-length', Response),

    [Via] = sip_message:header_values(via, Response),
    #sip_hdr_via{transport = udp, host = ?HOST, port = 5060} = Via,
    {received, {127, 0, 0, 1}} = lists:keyfind(received, 1, Via#sip_hdr_via.params),

    #sip_hdr_address{} = sip_message:header_top_value(to, Response),
    #sip_hdr_address{} = sip_message:header_top_value(from, Response),
    #sip_hdr_cseq{method = 'OPTIONS'} = sip_message:header_top_value(cseq, Response),
    ['OPTIONS'] = sip_message:header_values(allow, Response),

    _Bin = sip_message:header_top_value('call-id', Response),
    ok.