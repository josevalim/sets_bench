# sets_bench

Benchmarks between different sets implementation in Erlang/OTP. Example:

```
$ mix deps.get
$ mix run bench/intersection.exs
```

Requires Erlang/OTP 24 master.

## Summary

1. If you need take_largest, take_smallest, etc: gb_sets

2. If you only want to traverse, perform unions, intersections, or subtractions, of values that are quick to compare (integers, atoms, etc) and they are up to 1k-10k in size: ordsets

3. Everything else: cerl_sets
