# Performance Notes

Cellular must handle thousands of cells on low-end computers. The sim core should keep the per-tick path predictable and allocation-conscious.

## Current Hot-Path Rules

- Resource IDs are dense integers.
- Pools are capped at four slots, so slot lookups are short linear scans instead of dictionaries.
- Adjacency edges are cached by `GridWorld` and reused until occupancy changes.
- Swap proposal buffers are reused each tick.
- Swap reservations use dense `[cell, resource]` integer arrays, not dictionaries.
- Reaction tracking reuses a list.
- Score and win scans avoid LINQ allocation in the tick path.
- Event buffers are bounded by `EngineOptions.EventCapacity`.
- Generated scenarios can create repeatable 100+ cell maps for backend inspection without Godot.
- Offline puzzle generation can search many small candidate layouts before a level is shipped.

## Current Known Costs

- Events are still reference records. This is useful for clarity and Godot-facing audit trails, but high-density visual mode may need aggregated value-type event streams later.
- Win graph checks still use string cell IDs because fixture/win requirements are currently string-based. A future optimization should compile required cells into dense cell indexes after fixture load.
- `SwapPoolState.GetSlot` is a short linear scan over at most four slots. This is intentional for milestone 1.

## Next Optimization Steps

1. Compile `EngineOptions.RequiredCellIds` into integer cell indexes.
2. Add a non-allocating recent-event iterator for fixed tick windows.
3. Add optional aggregate flow counters for visuals so Godot does not need every individual transfer.
4. Add a benchmark runner with target sizes such as 2k, 10k, and 50k cells.
5. Consider struct event buffers for hot gameplay builds while keeping record events for tests/debug output.
6. Add stable-configuration search tooling that sweeps seeds and records the best scoring scenarios.
7. Add search pruning for larger puzzle candidates so arrangement search does not become brute-force-only.

## Manual Check

The test `DenseGrid_CanRunThousandsOfCellsWithBoundedEvents` builds 2,048 cells and runs multiple ticks with a bounded event buffer. It is a shape test, not a final benchmark.

For generated scenario inspection:

```bash
dotnet run --project sim/CellularSim.Examples -- --generate --seed 12345 --size 20 --cells 100 --resources 6 --rocks 30 --ticks 500 --save-dir sim/generated/seed-12345
```
