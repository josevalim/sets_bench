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
-export([iterator_based/2, mixed/2, filter_based/2, intersect/2, intersect_with/3,
         subtract/2, subtract_iterator/2, subtract_filter/2]).

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


%% maps:intersect

intersect(Map1, Map2) when is_map(Map1), is_map(Map2) ->
    case map_size(Map1) =< map_size(Map2) of
        true ->
            intersect_with_sorted(fun intersect_combiner_v2/3, Map1, Map2);
        false ->
            intersect_with_sorted(fun intersect_combiner_v1/3, Map2, Map1)
    end;
intersect(_Map1, _Map2) ->
    error(badarg).

intersect_combiner_v1(_K, V1, _V2) -> V1.
intersect_combiner_v2(_K, _V1, V2) -> V2.

-spec intersect_with(Combiner, Map1, Map2) -> Map3 when
    Map1 :: #{Key => Value1},
    Map2 :: #{term() => Value2},
    Combiner :: fun((Key, Value1, Value2) -> CombineResult),
    Map3 :: #{Key => CombineResult}.

intersect_with(Combiner, Map1, Map2) when is_map(Map1),
                                          is_map(Map2),
                                          is_function(Combiner, 3) ->
    %% Use =< because we want to avoid reversing the combiner if we can
    case map_size(Map1) =< map_size(Map2) of
        true ->
            intersect_with_sorted(Combiner, Map1, Map2);
        false ->
            RCombiner = fun(K, V1, V2) -> Combiner(K, V2, V1) end,
            intersect_with_sorted(RCombiner, Map2, Map1)
    end;
intersect_with(_Combiner, _Map1, _Map2) ->
    error(badarg).

intersect_with_sorted(Combiner, SmallMap, BigMap) ->
    Next = maps:next(maps:iterator(SmallMap)),
    intersect_with_iterate(Next, [], SmallMap, BigMap, Combiner).

intersect_with_iterate({K, V1, Iterator}, Keep, Map1, Map2, Combiner) ->
    Next = maps:next(Iterator),
    case Map2 of
        #{ K := V2 } ->
            V = Combiner(K, V1, V2),
            intersect_with_iterate(Next, [{K,V}|Keep], Map1, Map2, Combiner);
        _ ->
            intersect_with_iterate(Next, Keep, Map1, Map2, Combiner)
    end;
intersect_with_iterate(none, Keep, _Map1, _Map2, _Combiner) ->
    maps:from_list(Keep).

subtract_iterator(LHS, RHS) when is_map(LHS), is_map(RHS) ->
    Next = maps:next(maps:iterator(LHS)),
    subtract_decided(Next, LHS, RHS).

subtract_filter(S1, S2) ->
    filter(fun (E) -> not is_element(E, S2) end, S1).

%% Subtract mixed

subtract(LHS, RHS) when is_map(LHS), is_map(RHS) ->
    Next = maps:next(maps:iterator(LHS)),
    subtract_heuristic(Next, [], [], floor(map_size(LHS) * 0.75), LHS, RHS);
subtract(_LHS, _RHS) ->
    erlang:error(badarg).

subtract_heuristic(Next, _Keep, Delete, 0, Acc, Reference) ->
  subtract_decided(Next, remove_keys(Delete, Acc), Reference);
subtract_heuristic({Key, _Value, Iterator}, Keep, Delete, KeepCount, Acc, Reference) ->
    Next = maps:next(Iterator),
    case Reference of
        #{Key := _} ->
            subtract_heuristic(Next, Keep, [Key | Delete], KeepCount, Acc, Reference);
        _ ->
            subtract_heuristic(Next, [Key | Keep], Delete, KeepCount - 1, Acc, Reference)
    end;
subtract_heuristic(none, Keep, _Delete, _Count, _Acc, _Reference) ->
    maps:from_keys(Keep, []).

subtract_decided({Key, _Value, Iterator}, Acc, Reference) ->
    case Reference of
        #{Key := _} ->
            subtract_decided(maps:next(Iterator), maps:remove(Key, Acc), Reference);
        _ ->
            subtract_decided(maps:next(Iterator), Acc, Reference)
    end;
subtract_decided(none, Acc, _Reference) ->
    Acc.
