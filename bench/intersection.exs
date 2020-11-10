small_int_list = Enum.to_list(1..10)
medium_int_list = Enum.to_list(1..1000)
large_int_list = Enum.to_list(1..100_000)

small_bin_list = Enum.map(1..10, fn _ -> :crypto.strong_rand_bytes(10) end)
medium_bin_list = Enum.map(1..1000, fn _ -> :crypto.strong_rand_bytes(10) end)
large_bin_list = Enum.map(1..100_000, fn _ -> :crypto.strong_rand_bytes(10) end)

Benchee.run(
  %{
    "cerl_sets" =>
      {fn [arg1, arg2] -> :cerl_sets.intersection(arg1, arg2) end,
       before_scenario: fn args -> Enum.map(args, &:cerl_sets.from_list/1) end},
    "sets" =>
      {fn [arg1, arg2] -> :sets.intersection(arg1, arg2) end,
       before_scenario: fn args -> Enum.map(args, &:sets.from_list/1) end}
  },
  inputs: %{
    "small eq int" => [small_int_list, small_int_list],
    "medium eq int" => [medium_int_list, medium_int_list],
    "large eq int" => [large_int_list, large_int_list],
    "small eq bin" => [small_bin_list, small_bin_list],
    "medium eq bin" => [medium_bin_list, medium_bin_list],
    "large eq bin" => [large_bin_list, large_bin_list]
  }
)
