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

-module(emqx_banned_SUITE).

-compile(export_all).
-compile(nowarn_export_all).

-include("emqx.hrl").
-include_lib("eunit/include/eunit.hrl").

all() -> emqx_ct:all(?MODULE).

init_per_suite(Config) ->
    application:load(emqx),
    ok = ekka:start(),
    %% for coverage
    ok = emqx_banned:mnesia(copy),
    Config.

end_per_suite(_Config) ->
    ekka:stop(),
    ekka_mnesia:ensure_stopped(),
    ekka_mnesia:delete_schema().

t_add_delete(_) ->
    Banned = #banned{who = {client_id, <<"TestClient">>},
                     reason = <<"test">>,
                     by = <<"banned suite">>,
                     desc = <<"test">>,
                     until = erlang:system_time(second) + 1000
                    },
    ok = emqx_banned:add(Banned),
    ?assertEqual(1, emqx_banned:info(size)),
    ok = emqx_banned:delete({client_id, <<"TestClient">>}),
    ?assertEqual(0, emqx_banned:info(size)).

t_check(_) ->
    ok = emqx_banned:add(#banned{who = {client_id, <<"BannedClient">>}}),
    ok = emqx_banned:add(#banned{who = {username, <<"BannedUser">>}}),
    ok = emqx_banned:add(#banned{who = {ipaddr, {192,168,0,1}}}),
    ?assertEqual(3, emqx_banned:info(size)),
    ClientInfo1 = #{client_id => <<"BannedClient">>,
                    username => <<"user">>,
                    peerhost => {127,0,0,1}
                   },
    ClientInfo2 = #{client_id => <<"client">>,
                    username => <<"BannedUser">>,
                    peerhost => {127,0,0,1}
                   },
    ClientInfo3 = #{client_id => <<"client">>,
                    username => <<"user">>,
                    peerhost => {192,168,0,1}
                   },
    ClientInfo4 = #{client_id => <<"client">>,
                    username => <<"user">>,
                    peerhost => {127,0,0,1}
                   },
    ?assert(emqx_banned:check(ClientInfo1)),
    ?assert(emqx_banned:check(ClientInfo2)),
    ?assert(emqx_banned:check(ClientInfo3)),
    ?assertNot(emqx_banned:check(ClientInfo4)),
    ok = emqx_banned:delete({client_id, <<"BannedClient">>}),
    ok = emqx_banned:delete({username, <<"BannedUser">>}),
    ok = emqx_banned:delete({ipaddr, {192,168,0,1}}),
    ?assertNot(emqx_banned:check(ClientInfo1)),
    ?assertNot(emqx_banned:check(ClientInfo2)),
    ?assertNot(emqx_banned:check(ClientInfo3)),
    ?assertNot(emqx_banned:check(ClientInfo4)),
    ?assertEqual(0, emqx_banned:info(size)).

t_unused(_) ->
    {ok, Banned} = emqx_banned:start_link(),
    ok = emqx_banned:add(#banned{who = {client_id, <<"BannedClient">>},
                                 until = erlang:system_time(second)
                                }),
    ?assertEqual(ignored, gen_server:call(Banned, unexpected_req)),
    ?assertEqual(ok, gen_server:cast(Banned, unexpected_msg)),
    ?assertEqual(ok, Banned ! ok),
    timer:sleep(500), %% expiry timer
    ok = emqx_banned:stop().

