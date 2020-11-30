small_int_list = Enum.to_list(1..10)
medium_int_list = Enum.to_list(1..1000)
large_int_list = Enum.to_list(1..100_000)

small_other_int_list = Enum.to_list(11..20)
medium_other_int_list = Enum.to_list(1001..2000)
large_other_int_list = Enum.to_list(100_001..200_000)

small_bin_list = Enum.map(1..10, fn _ -> :crypto.strong_rand_bytes(10) end)
medium_bin_list = Enum.map(1..1000, fn _ -> :crypto.strong_rand_bytes(10) end)
large_bin_list = Enum.map(1..100_000, fn _ -> :crypto.strong_rand_bytes(10) end)

small_other_bin_list = Enum.map(1..10, fn _ -> :crypto.strong_rand_bytes(10) end)
medium_other_bin_list = Enum.map(1..1000, fn _ -> :crypto.strong_rand_bytes(10) end)
large_other_bin_list = Enum.map(1..100_000, fn _ -> :crypto.strong_rand_bytes(10) end)

Benchee.run(
  %{
    "cerl_sets (filter)" =>
      {fn [arg1, arg2] -> :cerl_sets.intersection(arg1, arg2) end,
       before_scenario: fn args -> Enum.map(args, &:cerl_sets.from_list/1) end},
    "cerl_sets (iterator)" =>
      {fn [arg1, arg2] -> :fast_maps.intersection(arg1, arg2) end,
       before_scenario: fn args -> Enum.map(args, &:cerl_sets.from_list/1) end},
    # "sets" =>
    #   {fn [arg1, arg2] -> :sets.intersection(arg1, arg2) end,
    #    before_scenario: fn args -> Enum.map(args, &:sets.from_list/1) end},
    "ordsets" =>
      {fn [arg1, arg2] -> :ordsets.intersection(arg1, arg2) end,
       before_scenario: fn args -> Enum.map(args, &:ordsets.from_list/1) end},
    "gb_sets" =>
      {fn [arg1, arg2] -> :gb_sets.intersection(arg1, arg2) end,
       before_scenario: fn args -> Enum.map(args, &:gb_sets.from_list/1) end}
  },
  inputs: %{
    "small eq int" => [small_int_list, small_int_list],
    "medium eq int" => [medium_int_list, medium_int_list],
    "large eq int" => [large_int_list, large_int_list],
    "small eq bin" => [small_bin_list, small_bin_list],
    "medium eq bin" => [medium_bin_list, medium_bin_list],
    "large eq bin" => [large_bin_list, large_bin_list],
    "small distinct int" => [small_int_list, small_other_int_list],
    "medium distinct int" => [medium_int_list, medium_other_int_list],
    "large distinct int" => [large_int_list, large_other_int_list],
    "small distinct bin" => [small_bin_list, small_other_bin_list],
    "medium distinct bin" => [medium_bin_list, medium_other_bin_list],
    "large distinct bin" => [large_bin_list, large_other_bin_list]
  }
)
