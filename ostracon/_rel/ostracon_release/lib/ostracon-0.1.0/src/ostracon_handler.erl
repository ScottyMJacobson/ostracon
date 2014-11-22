-module(ostracon_handler).
-behaviour(cowboy_http_handler).
-behaviour(cowboy_websocket_handler).

-export([init/3]).
-export([handle/2]).
-export([terminate/3]).
-export([
    websocket_init/3, websocket_handle/3,
    websocket_info/3, websocket_terminate/3
]).

init({tcp, http}, _Req, _Opts) ->
  {upgrade, protocol, cowboy_websocket}.

% no 'get' requests should hit here
handle(_Req, State) ->
    {ok, Response} = cowboy_http_req:reply(404, [{'Content-Type', <<"text/html">>}]),
    {ok, Response, State}.

terminate(_Reason, _Req, _State) ->
	ok.


% websocket logic

websocket_init(_TransportName, Req, _Opts) ->
    {ok, Req, undefined_state}.

websocket_handle({votes, Vote}, Req, State) -> 
    ets:insert(voteDB, {self(), Vote}),
    {reply, {text, << "received vote: ", Vote/binary >>}, Req, State, hibernate };
websocket_handle({state}, Req, State) ->
    AppState = ets:tab2list(stateDB),
    {reply, {text, << AppState/binary >>}, Req, State, hibernate };
websocket_handle(_Any, Req, State) ->
    {reply, {text, << "unknown request">>}, Req, State, hibernate }.

websocket_info({timeout, _Ref, Msg}, Req, State) ->
    {reply, {text, Msg}, Req, State};
websocket_info(_Info, Req, State) ->
    {ok, Req, State, hibernate}.

websocket_terminate(_Reason, _Req, _State) ->
    ok.