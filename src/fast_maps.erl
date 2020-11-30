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
-export([iterator_based/2, mixed/2, filter_based/2]).

filter_based(S1, S2) when map_size(S1) >= map_size(S2) ->
    filter(fun (E) -> is_element(E, S1) end, S2);
filter_based(S1, S2) ->
    filter_based(S2, S1).

is_element(E,S) ->
    case S of
        #{E := _} -> true;
        _ -> false
    end.

filter(Fun, Set) ->
    maps:from_keys(filter_1(Fun, maps:iterator(Set)), []).

filter_1(Fun, Iter) ->
    case maps:next(Iter) of
        {K, _, NextIter} ->
            case Fun(K) of
                true ->
                    [K | filter_1(Fun, NextIter)];
                false ->
                    filter_1(Fun, NextIter)
            end;
        none ->
            []
    end.

%%

iterator_based(LHS, RHS) when is_map(LHS), is_map(RHS) ->
    case map_size(LHS) < map_size(RHS) of
        true ->
            Iterator = maps:iterator(LHS),
            iterator_based(maps:next(Iterator), LHS, RHS);
        false ->
            Iterator = maps:iterator(RHS),
            iterator_based(maps:next(Iterator), RHS, LHS)
    end;
iterator_based(_LHS, _RHS) ->
    erlang:error(badarg).

iterator_based({Key, _Value, Iterator}, Acc0, Reference) ->
    Acc1 = case Reference of
      #{Key := _} -> Acc0;
      #{} -> maps:remove(Key, Acc0)
    end,
    iterator_based(maps:next(Iterator), Acc1, Reference);
iterator_based(none, Acc, _Reference) ->
    Acc.

%%

mixed(LHS, RHS) when is_map(LHS), is_map(RHS) ->
    case map_size(LHS) < map_size(RHS) of
        true ->
            Iterator = maps:iterator(LHS),
            mixed_heuristic(maps:next(Iterator), [], [], floor(map_size(LHS) * 0.75), LHS, RHS);
        false ->
            Iterator = maps:iterator(RHS),
            mixed_heuristic(maps:next(Iterator), [], [], floor(map_size(RHS) * 0.75), RHS, LHS)
    end;
mixed(_LHS, _RHS) ->
    erlang:error(badarg).

%% If we are keeping more than 40% of the keys, then it is
%% cheaper to delete them. Stop accumulating and start deleting.
mixed_heuristic(Next, _Keep, Delete, 0, Acc, Reference) ->
  mixed_decided(Next, remove_keys(Delete, Acc), Reference);
mixed_heuristic({Key, _Value, Iterator}, Keep, Delete, KeepCount, Acc, Reference) ->
    Next = maps:next(Iterator),
    case Reference of
        #{Key := _} ->
            mixed_heuristic(Next, [Key | Keep], Delete, KeepCount - 1, Acc, Reference);
        _ ->
            mixed_heuristic(Next, Keep, [Key | Delete], KeepCount, Acc, Reference)
    end;
mixed_heuristic(none, Keep, _Delete, _Count, _Acc, _Reference) ->
    maps:from_keys(Keep, []).

mixed_decided({Key, _Value, Iterator}, Acc0, Reference) ->
    Acc1 = case Reference of
      #{Key := _} -> Acc0;
      #{} -> maps:remove(Key, Acc0)
    end,
    mixed_decided(maps:next(Iterator), Acc1, Reference);
mixed_decided(none, Acc, _Reference) ->
    Acc.

remove_keys([K | Ks], Map) -> remove_keys(Ks, maps:remove(K, Map));
remove_keys([], Map) -> Map.
