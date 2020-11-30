small_int_list = Enum.to_list(1..10) |> Enum.shuffle()
medium_int_list = Enum.to_list(1..1000) |> Enum.shuffle()
large_int_list = Enum.to_list(1..100_000) |> Enum.shuffle()

small_bin_list = Enum.map(1..10, fn _ -> :crypto.strong_rand_bytes(10) end)
medium_bin_list = Enum.map(1..1000, fn _ -> :crypto.strong_rand_bytes(10) end)
large_bin_list = Enum.map(1..100_000, fn _ -> :crypto.strong_rand_bytes(10) end)

Benchee.run(
  %{
    "cerl_sets" => &:cerl_sets.from_list/1,
    # "sets" => &:sets.from_list/1,
    "gb_sets" => &:gb_sets.from_list/1,
    "ordsets" => &:ordsets.from_list/1
  },
  inputs: %{
    "small eq int" => small_int_list,
    "medium eq int" => medium_int_list,
    "large eq int" => large_int_list,
    "small eq bin" => small_bin_list,
    "medium eq bin" => medium_bin_list,
    "large eq bin" => large_bin_list,
  })
