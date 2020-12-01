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
    Limit = floor(map_size(SmallMap) * 0.75),
    intersect_with_heuristic(Next, [], [], Limit, SmallMap, BigMap, Combiner).

%% If we are keeping/changing more than 75% of the keys,
%% then it is cheaper to update in place. Stop accumulating
%% and start replacing and deleting.
intersect_with_heuristic(Next, Keep, Delete, 0, Map1, Map2, Combiner) ->
    intersect_with_decided(Next, replace(Keep, without(Delete, Map1)), Map2, Combiner);
intersect_with_heuristic({K, V1, Iterator}, Keep, Delete, Count, Map1, Map2, Combiner) ->
    Next = maps:next(Iterator),
    case Map2 of
        #{ K := V2 } ->
            V = Combiner(K, V1, V2),
            intersect_with_heuristic(Next, [{K,V}|Keep], Delete, Count-1, Map1, Map2, Combiner);
        _ ->
            intersect_with_heuristic(Next, Keep, [K|Delete], Count, Map1, Map2, Combiner)
    end;
intersect_with_heuristic(none, Keep, _Delete, _Count, _Map1, _Map2, _Combiner) ->
    maps:from_list(Keep).

intersect_with_decided({K, V1, Iterator}, Map1, Map2, Combiner) ->
    case Map2 of
        #{ K := V2 } ->
            NewMap1 = Map1#{ K := Combiner(K, V1, V2) },
            intersect_with_decided(maps:next(Iterator), NewMap1, Map2, Combiner);
        _ ->
            intersect_with_decided(maps:next(Iterator), maps:remove(K, Map1), Map2, Combiner)
    end;
intersect_with_decided(none, Res, _, _) ->
    Res.

replace([{K,V}|KVs],M) -> replace(KVs, M#{K := V});
replace([],M) -> M.

without(Ks,M) when is_list(Ks), is_map(M) ->
    without_1(Ks, M).

without_1([K|Ks],M) -> without_1(Ks, maps:remove(K, M));
without_1([],M) -> M.


subtract_iterator(LHS, RHS) when is_map(LHS), is_map(RHS) ->
    case map_size(LHS) =< map_size(RHS) of
        true ->
            Next = maps:next(maps:iterator(LHS)),
            subtract_decided_lhs(Next, LHS, RHS);
        false ->
            Next = maps:next(maps:iterator(RHS)),
            subtract_decided_rhs(Next, LHS)
    end.

subtract_filter(S1, S2) ->
    filter(fun (E) -> not is_element(E, S2) end, S1).

%% Subtract mixed

subtract(LHS, RHS) when is_map(LHS), is_map(RHS) ->
    case map_size(LHS) =< map_size(RHS) of
        true ->
            Next = maps:next(maps:iterator(LHS)),
            subtract_heuristic_lhs(Next, [], [], floor(map_size(LHS) * 0.75), LHS, RHS);
        false ->
            Next = maps:next(maps:iterator(RHS)),
            subtract_heuristic_rhs(Next, [], [], floor(map_size(LHS) * 0.75), LHS)
    end;
subtract(_LHS, _RHS) ->
    erlang:error(badarg).

subtract_heuristic_lhs(Next, _Keep, Delete, 0, Acc, Reference) ->
  subtract_decided_lhs(Next, remove_keys(Delete, Acc), Reference);
subtract_heuristic_lhs({Key, _Value, Iterator}, Keep, Delete, KeepCount, Acc, Reference) ->
    Next = maps:next(Iterator),
    case Reference of
        #{Key := _} ->
            subtract_heuristic_lhs(Next, Keep, [Key | Delete], KeepCount, Acc, Reference);
        _ ->
            subtract_heuristic_lhs(Next, [Key | Keep], Delete, KeepCount - 1, Acc, Reference)
    end;
subtract_heuristic_lhs(none, Keep, _Delete, _Count, _Acc, _Reference) ->
    maps:from_keys(Keep, []).

subtract_decided_lhs({Key, _Value, Iterator}, Acc, Reference) ->
    case Reference of
        #{Key := _} ->
            subtract_decided_lhs(maps:next(Iterator), maps:remove(Key, Acc), Reference);
        _ ->
            subtract_decided_lhs(maps:next(Iterator), Acc, Reference)
    end;
subtract_decided_lhs(none, Acc, _Reference) ->
    Acc.

subtract_heuristic_rhs(Next, _Keep, Delete, 0, Acc) ->
  subtract_decided_rhs(Next, remove_keys(Delete, Acc));
subtract_heuristic_rhs({Key, _Value, Iterator}, Keep, Delete, KeepCount, Acc) ->
    Next = maps:next(Iterator),
    case Acc of
        #{Key := _} ->
            subtract_heuristic_rhs(Next, Keep, [Key | Delete], KeepCount, Acc);
        _ ->
            subtract_heuristic_rhs(Next, [Key | Keep], Delete, KeepCount - 1, Acc)
    end;
subtract_heuristic_rhs(none, Keep, _Delete, _Count, _Acc) ->
    maps:from_keys(Keep, []).

subtract_decided_rhs({Key, _Value, Iterator}, Acc) ->
    subtract_decided_rhs(maps:next(Iterator), maps:remove(Key, Acc));
subtract_decided_rhs(none, Acc) ->
    Acc.
