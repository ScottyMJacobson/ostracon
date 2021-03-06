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

% No 'get' requests should hit here unless there is a 404. 
handle(_Req, State) ->
    {ok, Response} = 
        cowboy_http_req:reply(404, [{'Content-Type', <<"text/html">>}]),
    {ok, Response, State}.

terminate(_Reason, _Req, _State) ->
	ok.


%%%%%%%%%%% WEBSOCKET LOGIC %%%%%%%%%%%

% Starts the websocket and increments the number of connections
websocket_init(_TransportName, Req, _Opts) ->
    Result = ets:lookup(stateDB, connections),
    case Result of 
        [] -> ets:insert(stateDB, {connections, 1});
        [{connections, X}|_] -> ets:insert(stateDB, {connections, X + 1})
    end,
    {ok, Req, undefined_state}.

% Handles requests of type "vote" or "statequery"
websocket_handle({text, JSON}, Req, State) ->
    Body = jiffy:decode(JSON),
    case Body of
        {[{<< "type" >>, << "vote" >>}, 
        {<< "vote" >>, V}, {<< "team" >>, T}]} ->
            ets:insert(voteDB, {self(), {V, T}}),
            Response = 
                jiffy:encode({[{type, voteresponse}, {response, V}]}),
            {reply, {text, Response}, Req, State, hibernate };
        {[{<< "type" >>, << "statequery" >>}]} ->
            AppState = ets:tab2list(stateDB),
            Response = 
                jiffy:encode({[{type, stateresponse}, {response, {AppState}}]}),
            {reply, {text, Response}, Req, State, hibernate };
        _ ->
            Response = jiffy:encode({[{type, error}, 
                                    {error, << "Unrecognized query." >>}]}),
            {reply, {text, Response}, Req, State, hibernate }
    end;
websocket_handle(_, Req, State) ->
    {reply, {text, << "Bad Request" >>}, Req, State, hibernate }.


websocket_info({timeout, _Ref, Msg}, Req, State) ->
    {reply, {text, Msg}, Req, State};
websocket_info(_Info, Req, State) ->
    {ok, Req, State, hibernate}.

websocket_terminate(_Reason, _Req, _State) ->
    [{connections, X}|_] = ets:lookup(stateDB, connections),
    ets:insert(stateDB, {connections, X - 1}),
    ok.