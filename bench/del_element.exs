small_int_list = Enum.to_list(1..10)
medium_int_list = Enum.to_list(1..1000)
large_int_list = Enum.to_list(1..100_000)

small_bin_list = Enum.map(1..10, fn _ -> :crypto.strong_rand_bytes(10) end)
medium_bin_list = Enum.map(1..1000, fn _ -> :crypto.strong_rand_bytes(10) end)
large_bin_list = Enum.map(1..100_000, fn _ -> :crypto.strong_rand_bytes(10) end)

Benchee.run(
  %{
    "cerl_sets" =>
      {fn [arg1, arg2] -> :cerl_sets.del_element(arg1, arg2) end,
       before_scenario: fn [arg1, arg2] -> [arg1, :cerl_sets.from_list(arg2)] end},
    # "sets" =>
    #   {fn [arg1, arg2] -> :sets.del_element(arg1, arg2) end,
    #    before_scenario: fn [arg1, arg2] -> [arg1, :sets.from_list(arg2)] end},
    "gb_sets" =>
      {fn [arg1, arg2] -> :gb_sets.del_element(arg1, arg2) end,
       before_scenario: fn [arg1, arg2] -> [arg1, :gb_sets.from_list(arg2)] end},
    "ordsets" =>
      {fn [arg1, arg2] -> :ordsets.del_element(arg1, arg2) end,
       before_scenario: fn [arg1, arg2] -> [arg1, :ordsets.from_list(arg2)] end},
  },
  inputs: %{
    "small eq int" => [5, small_int_list],
    "medium eq int" => [500, medium_int_list],
    "large eq int" => [50000, large_int_list],
    "small eq bin" => [Enum.random(small_bin_list), small_bin_list],
    "medium eq bin" => [Enum.random(medium_bin_list), medium_bin_list],
    "large eq bin" => [Enum.random(large_bin_list), large_bin_list]
  }
)
