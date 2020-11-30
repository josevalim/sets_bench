%%
%% %CopyrightBegin%
%%
%% Copyright Ericsson AB 2013-2019. All Rights Reserved.
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
%%
%% %CopyrightEnd%
%%

-module(fast_maps).

-export([intersect/2]).

%% Copy from Erlang/OTP 24 master.
intersect(LHS, RHS) when is_map(LHS), is_map(RHS) ->
    case map_size(LHS) < map_size(RHS) of
        true ->
            Iterator = maps:iterator(LHS),
            intersect_lhs(maps:next(Iterator), LHS, RHS);
        false ->
            Iterator = maps:iterator(RHS),
            intersect_rhs(maps:next(Iterator), RHS, LHS)
    end;
intersect(_LHS, _RHS) ->
    erlang:error(badarg).

intersect_lhs({Key, LHS_Value, Iterator}, LHS0, RHS) ->
    LHS = case RHS of
              #{ Key := LHS_Value } ->
                  LHS0;
              #{ Key := RHS_Value } ->
                  %% The value in RHS has precedence, so we must overwrite the
                  %% current value if it differs.
                  LHS0#{ Key := RHS_Value };
              _ ->
                  maps:remove(Key, LHS0)
          end,
    intersect_lhs(maps:next(Iterator), LHS, RHS);
intersect_lhs(none, Res, _) ->
    Res.

intersect_rhs({Key, _RHS_Value, Iterator}, RHS0, LHS) ->
    RHS = case LHS of
              #{ Key := _LHS_Value } ->
                  %% The value in RHS has precedence, so it doesn't need to
                  %% be updated even if they differ.
                  RHS0;
              _ ->
                  maps:remove(Key, RHS0)
          end,
    intersect_rhs(maps:next(Iterator), RHS, LHS);
intersect_rhs(none, Res, _) ->
    Res.
