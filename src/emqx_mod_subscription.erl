%%--------------------------------------------------------------------
%% Copyright (c) 2019 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(emqx_mod_subscription).

-behaviour(emqx_gen_mod).

-include_lib("emqx.hrl").
-include_lib("emqx_mqtt.hrl").

%% emqx_gen_mod callbacks
-export([ load/1
        , unload/1
        ]).

%% APIs
-export([on_client_connected/4]).

%%--------------------------------------------------------------------
%% Load/Unload Hook
%%--------------------------------------------------------------------

load(Topics) ->
    emqx_hooks:add('client.connected', {?MODULE, on_client_connected, [Topics]}).

on_client_connected(#{client_id := ClientId,
                      username  := Username}, ?RC_SUCCESS, _ConnInfo, Topics) ->
    Replace = fun(Topic) ->
                      rep(<<"%u">>, Username, rep(<<"%c">>, ClientId, Topic))
              end,
    TopicFilters = [{Replace(Topic), #{qos => QoS}} || {Topic, QoS} <- Topics],
    self() ! {subscribe, TopicFilters}.

unload(_) ->
    emqx_hooks:del('client.connected', {?MODULE, on_client_connected}).

%%------------------------------------------------------------------------------
%% Internal functions
%%------------------------------------------------------------------------------

rep(<<"%c">>, ClientId, Topic) ->
    emqx_topic:feed_var(<<"%c">>, ClientId, Topic);
rep(<<"%u">>, undefined, Topic) ->
    Topic;
rep(<<"%u">>, Username, Topic) ->
    emqx_topic:feed_var(<<"%u">>, Username, Topic).

