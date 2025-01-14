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

-module(emqx_zone).

-behaviour(gen_server).

-include("emqx.hrl").
-include("logger.hrl").
-include("types.hrl").

-logger_header("[Zone]").

%% APIs
-export([start_link/0, stop/0]).

-export([ use_username_as_clientid/1
        , enable_stats/1
        , enable_acl/1
        , enable_ban/1
        , enable_flapping_detect/1
        , ignore_loop_deliver/1
        , server_keepalive/1
        , max_inflight/1
        , session_expiry_interval/1
        , force_gc_policy/1
        , force_shutdown_policy/1
        ]).

-export([ get_env/2
        , get_env/3
        , set_env/3
        , unset_env/2
        ]).

-export([force_reload/0]).

%% gen_server callbacks
-export([ init/1
        , handle_call/3
        , handle_cast/2
        , handle_info/2
        , terminate/2
        , code_change/3
        ]).

-export_type([zone/0]).

%% dummy state
-record(state, {}).

-type(zone() :: atom()).

-define(TAB, ?MODULE).
-define(SERVER, ?MODULE).
-define(KEY(Zone, Key), {?MODULE, Zone, Key}).

%%--------------------------------------------------------------------
%% APIs
%%--------------------------------------------------------------------

-spec(start_link() -> startlink_ret()).
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

-spec(use_username_as_clientid(zone()) -> boolean()).
use_username_as_clientid(Zone) ->
    get_env(Zone, use_username_as_clientid, false).

-spec(enable_stats(zone()) -> boolean()).
enable_stats(Zone) ->
    get_env(Zone, enable_stats, true).

-spec(enable_acl(zone()) -> boolean()).
enable_acl(Zone) ->
    get_env(Zone, enable_acl, true).

-spec(enable_ban(zone()) -> boolean()).
enable_ban(Zone) ->
    get_env(Zone, enable_ban, false).

-spec(enable_flapping_detect(zone()) -> boolean()).
enable_flapping_detect(Zone) ->
    get_env(Zone, enable_flapping_detect, false).

-spec(ignore_loop_deliver(zone()) -> boolean()).
ignore_loop_deliver(Zone) ->
    get_env(Zone, ignore_loop_deliver, false).

-spec(server_keepalive(zone()) -> pos_integer()).
server_keepalive(Zone) ->
    get_env(Zone, server_keepalive).

-spec(max_inflight(zone()) -> 0..65535).
max_inflight(Zone) ->
    get_env(Zone, max_inflight, 65535).

-spec(session_expiry_interval(zone()) -> non_neg_integer()).
session_expiry_interval(Zone) ->
    get_env(Zone, session_expiry_interval, 0).

-spec(force_gc_policy(zone()) -> maybe(emqx_gc:opts())).
force_gc_policy(Zone) ->
    get_env(Zone, force_gc_policy).

-spec(force_shutdown_policy(zone()) -> maybe(emqx_oom:opts())).
force_shutdown_policy(Zone) ->
    get_env(Zone, force_shutdown_policy).

-spec(get_env(maybe(zone()), atom()) -> maybe(term())).
get_env(undefined, Key) -> emqx:get_env(Key);
get_env(Zone, Key) ->
    get_env(Zone, Key, undefined).

-spec(get_env(maybe(zone()), atom(), term()) -> maybe(term())).
get_env(undefined, Key, Def) ->
    emqx:get_env(Key, Def);
get_env(Zone, Key, Def) ->
    try persistent_term:get(?KEY(Zone, Key))
    catch error:badarg ->
        emqx:get_env(Key, Def)
    end.

-spec(set_env(zone(), atom(), term()) -> ok).
set_env(Zone, Key, Val) ->
    persistent_term:put(?KEY(Zone, Key), Val).

-spec(unset_env(zone(), atom()) -> boolean()).
unset_env(Zone, Key) ->
    persistent_term:erase(?KEY(Zone, Key)).

-spec(force_reload() -> ok).
force_reload() ->
    gen_server:call(?SERVER, force_reload).

-spec(stop() -> ok).
stop() ->
    gen_server:stop(?SERVER, normal, infinity).

%%--------------------------------------------------------------------
%% gen_server callbacks
%%--------------------------------------------------------------------

init([]) ->
    _ = do_reload(),
    {ok, #state{}}.

handle_call(force_reload, _From, State) ->
    _ = do_reload(),
    {reply, ok, State};

handle_call(Req, _From, State) ->
    ?LOG(error, "Unexpected call: ~p", [Req]),
    {reply, ignored, State}.

handle_cast(Msg, State) ->
    ?LOG(error, "Unexpected cast: ~p", [Msg]),
    {noreply, State}.

handle_info(Info, State) ->
    ?LOG(error, "Unexpected info: ~p", [Info]),
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%% Internal functions
%%--------------------------------------------------------------------

do_reload() ->
    [persistent_term:put(?KEY(Zone, Key), Val)
      || {Zone, Opts} <- emqx:get_env(zones, []), {Key, Val} <- Opts].

