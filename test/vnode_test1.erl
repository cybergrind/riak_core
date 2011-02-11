%%
%% Copyright (c) 2011 Basho Technologies, Inc.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

-module(vnode_test1).

-compile(export_all).

-define(PURE_DRIVER, gen_fsm_test_driver).
-define(MUT, riak_core_vnode).

pure_1st_trivial_test() ->
    FsmID = trivial_1st,
    MyPart = 42,                                % 42 is a nice partition #....
    PureOpts = make_general_pure_opts(FsmID, MyPart),
    InitIter = ?MUT:pure_start(FsmID, riak_bogus_vnode, MyPart, PureOpts),
    Events = [],

    {need_events, _, _} = X =
        ?PURE_DRIVER:run_to_completion(FsmID, ?MUT, InitIter, Events),
    [{res, X},
     {trace, ?PURE_DRIVER:get_trace(FsmID)}].

make_general_pure_opts(FsmID, PartitionInterval = PI)
  when PartitionInterval > 0 ->
    NumParts = 8,
    SeedNode = r1@node,
    Ring = {NumParts, [{Idx, SeedNode} ||
                          Idx <- lists:seq(0, (NumParts*PI) - 1, PI)]},
    ChState = {chstate, SeedNode, [], Ring, dict:new()}, % ugly hack
    NoReplyFun = fun(Args) -> {noreply, lists:last(Args)} end,
    [{debug, true},
     {{erlang, node}, SeedNode},
     {{riak_core_ring_manager, get_my_ring}, {ok, ChState}},
     {{riak_core_node_watcher, node_watcher_nodes}, [SeedNode]},
     {{app_helper, get_env},
      fun([riak_core, vnode_inactivity_timeout, _Default]) ->
              9999999999
      end},
     {{error_logger, error_msg},
      fun([Fmt, Args]) ->
              Str = io_lib:format(Fmt, Args),
              ?PURE_DRIVER:add_trace(FsmID, {error_logger, error_msg,
                                             lists:flatten(Str)})
      end},
     {{error_logger, info_msg},
      fun([Fmt, Args]) ->
              Str = io_lib:format(Fmt, Args),
              ?PURE_DRIVER:add_trace(FsmID, {error_logger, info_msg,
                                             lists:flatten(Str)})
      end},
     {{mod, reply},
      fun([Sender, Reply]) ->
              ?PURE_DRIVER:add_trace(FsmID, {reply, Sender, Reply})
      end},
     {{mod, init}, {ok, foo_mod_state}},
     {{mod, handle_command}, NoReplyFun},
     {{mod, handle_handoff_command}, NoReplyFun},
     {{mod, handle_handoff_data}, NoReplyFun},
     {{mod, handoff_starting}, NoReplyFun},
     {{mod, handoff_finished}, NoReplyFun},
     {{mod, handoff_cancelled}, NoReplyFun},
     {{mod, delete}, NoReplyFun},
     {{mod, is_empty}, NoReplyFun},
     {{mod, terminate}, NoReplyFun}
    ].
