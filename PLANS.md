# Cellular Plan

## Current Phase

Milestone 1: standalone deterministic C# simulation core.

## Completed

- [x] Define project process and documentation structure.
- [x] Keep `AGENTS.md` short and enforceable.
- [x] Stop ignoring `AGENTS.md` so project instructions can be committed.
- [x] Move design guardrails into `DESIGN.md`.
- [x] Replace root `README.md` with Cellular orientation.
- [x] Point local `origin` at `https://github.com/grassrootseconomics/cellular.git`.
- [x] Scaffold C# solution and projects under `sim/`.
- [x] Implement milestone 1 sim core.
- [x] Add JSON fixtures for direct reciprocity, limits, and routing.
- [x] Add tests for milestone 1 behavior.
- [x] Restore and run the C# test suite.
- [x] Add a testing map in `sim/TESTING.md`.
- [x] Add proof fixtures for one-way flow, no diagonal flow, source-output reaction, and edge throughput.
- [x] Add proof-focused tests for core rule examples.
- [x] Clarify pool semantics in `sim/POOLS.md`.
- [x] Add `CellularSim.Examples` for human-readable scenario output.
- [x] Update fixtures so produced resources are `SourceOutput` and accepted resources are `Need`.
- [x] Add explicit `SwapEvent` output with initiator and capacity checks.
- [x] Remove LINQ and per-tick dictionary reservations from the core swap/reaction hot path.
- [x] Cache grid adjacency edges in `GridWorld`.
- [x] Add a 2,048-cell bounded-event performance shape test.
- [x] Document performance constraints in `sim/PERFORMANCE.md`.
- [x] Add interactive/scripted debug mode for fixture setup, state, cells, events, ticks, and scores.
- [x] Add verbose debug output with ASCII map and orthogonal touching-pair inspection.
- [x] Add deterministic random scenario generation for larger backend maps.
- [x] Add generated scenario text outputs for `scenario.json`, `map.txt`, and `results.txt`.
- [x] Add stability-summary metrics for generated backend runs.
- [x] Add generated-scenario unit tests.
- [x] Switch generated cells to four slots: one produced resource and three needed resources.
- [x] Render generated ASCII maps with the produced-resource character on each cell tile.
- [x] Add score breakdown output to generated scenario results.
- [x] Tighten stable-signal checks so tiny isolated loops do not count as stable.
- [x] Run the C# test suite after generator/map/scoring updates.
- [x] Create fresh local root commit for the Cellular baseline.

## In Progress

- [ ] Push fresh-history `main` to `https://github.com/grassrootseconomics/cellular.git`.
- [ ] Use generated scenarios to search for stable 100+ cell configurations.
- [ ] Decide whether `AcceptOnly` should be removed, renamed, or kept as an experimental routing role.

## Milestone 1 Scope

- Dense integer `ResourceId` and `ResourceCatalog`.
- Four-slot cell pools with default cap `100`.
- Primary generated gameplay roles: `PoolSlotRole.SourceOutput` and `PoolSlotRole.Need`.
- `PoolSlotRole.AcceptOnly` exists in code for experimental routing/proof cases, but is not part of generated v1 scenarios.
- Sources produce into any matching existing slot.
- Deterministic fixed ticks.
- Orthogonal grid adjacency only.
- Rocks block swaps.
- Swap proposals generated before mutation.
- Deterministic atomic swaps between adjacent cells.
- Reactions consume each active resource slot: `SourceOutput` and `Need`.
- Basic strain events, score state, event buffering, fixture loading, fixture validation, generated scenarios, and text summaries.

## Manual Verification

Run only when explicitly requested:

```bash
dotnet test sim/CellularSim.Tests
```

Do not run Godot for this milestone.

Latest result: `dotnet test sim/CellularSim.Tests` passed 29 tests.

Fresh-history status: local `main` is a root commit named `Initial Cellular baseline`. The old copied history is preserved locally on `mycofig-history-backup`. Push is blocked until the GitHub repo exists and this environment has access.

Latest example command:

```bash
dotnet run --project sim/CellularSim.Examples -- sim/fixtures/routing.json 3
```

Latest debug command:

```bash
dotnet run --project sim/CellularSim.Examples -- --debug sim/fixtures/routing.json
```

Verbose:

```bash
dotnet run --project sim/CellularSim.Examples -- --debug --verbose sim/fixtures/routing.json
```

Generated scenario command:

```bash
dotnet run --project sim/CellularSim.Examples -- --generate --seed 12345 --size 20 --cells 100 --resources 6 --rocks 30 --ticks 500 --save-dir sim/generated/seed-12345
```
