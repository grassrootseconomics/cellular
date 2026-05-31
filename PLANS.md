# Cellular Plan

## Current Phase

Milestone 2: Godot visual MVP shell on top of the deterministic C# simulation work.

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
- [x] Push fresh-history `main` to `https://github.com/grassrootseconomics/cellular.git`.
- [x] Add a four-cell `ABCD` line fixture for inspecting routing decisions.
- [x] Add first-pass swap decision scoring: prefer unmet needs and useful counterparty offers.
- [x] Add a five-cell `ABCDE` line fixture where `E` produces `E` and needs `B`, `C`, and `D`.
- [x] Add a five-cell `ABCDE` line fixture where `D` needs `E`, allowing all five cells to glow.
- [x] Add a six-cell `ABCDEF` line fixture for inspecting larger glow flicker behavior.
- [x] Add a two-row `ABC/FED` fixture and adjacency test for orthogonal touching pairs.
- [x] Add a two-row `ABC/DEF` fixture for comparing spatial routing and strain.
- [x] Add a twelve-cell `ABCD/EFGH/IJKL` seeded-random needs fixture and `G` adjacency test.
- [x] Document myco/no-source cells and render them as `0` in ASCII maps.
- [x] Add offline puzzle level model with start layout, solution layout, and solver summary.
- [x] Add arrangement search for generated puzzle levels.
- [x] Add CLI output for saving generated puzzle-level artifacts.
- [x] Document Puzzle mode, Arcade mode, and simple-token visual MVP.
- [x] Rename the Godot title screen to Cellular.
- [x] Add Puzzle and Arcade title buttons while keeping the Grassroots Economics link/logo.
- [x] Add saved Highest Puzzle Level state and a title-screen reset option.
- [x] Show Arcade High Score from the existing high-score save.
- [x] Add a minimal draggable Godot Puzzle Level scene for Level 1 testing.
- [x] Add a Puzzle scene Next Level button that appears after a full circuit is solved.
- [x] Tighten Godot puzzle prototype flow so visual links and lit needs require reciprocal swap paths, not arbitrary touching.
- [x] Convert project structure to Godot .NET with a root `Cellular.csproj`.
- [x] Add `CellularSimBridge` C# autoload referencing the pure `sim/CellularSim` library.
- [x] Route the Puzzle scene through the C# bridge when running under Godot .NET.
- [x] Add swap particles and inventory fullness arcs/percent labels from C# sim snapshots.
- [x] Add the first shipped Puzzle fixture at `levels/puzzle/level-001.json`.
- [x] Add a Puzzle Hint button that highlights one reciprocal matching pair.
- [x] Change fallback generated needs to a reciprocal ring pattern so temporary levels have visible matching pairs.
- [x] Generate and ship Puzzle levels 1-10 with verified solution fixtures and ASCII solution maps.
- [x] Make generated Puzzle needs follow a seeded solvable line order so early shipped levels verify quickly.
- [x] Remove tiny percent text from puzzle cells and make resource letters larger/bolder.
- [x] Move reciprocal need pips toward matching adjacent partners so they touch without overlap before swaps begin.
- [x] Replace straight-line Puzzle solutions 1-10 with optimized compact 2D solution layouts.
- [x] Keep line layouts as fallback/debug candidates, but rank shipped solutions by reciprocal/useful contacts and sim outcomes.
- [x] Reset Puzzle sim state after each successful move so shipped solution maps validate from a clean layout state.
- [x] Make generated start and solution fixtures use the same stable cell order so verified solutions match live Puzzle play.
- [x] Make grid adjacency edge ordering stable by board position instead of fixture insertion order.
- [x] Allow cells to accept returned `SourceOutput` resources during swaps, discarding returned overflow above cap.
- [x] Replace broad swap scoring with deterministic need-first arbitration for shared resource claims.
- [x] Add bundled reciprocal swaps so relay cells can receive surplus and pass resources onward.
- [x] Change generated Puzzle start layouts from long rows to randomized compact boards one tile larger than the solution bounds.
- [x] Add folded-line serpentine solution candidates before falling back to full straight-line solutions.
- [x] Keep searching need graphs when the first winning layout is only a long one-row fallback.
- [x] Generate and ship Puzzle levels 11-20 with verified solution fixtures and ASCII solution maps.
- [x] Review shipped solution maps so levels 1-20 fit inside their playable start grids.

## In Progress

- [ ] Generate Puzzle levels 21+ with more varied geometry after Level 1-20 playtesting.
- [ ] Optimize the C# bridge snapshot format for large boards after the visual contract settles.
- [ ] Use generated scenarios to search for stable 100+ cell configurations.
- [ ] Extend arrangement search to accept arbitrary hand-authored fixtures, not only generated puzzle levels.
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
- Offline Puzzle mode level generation with separated start layouts and recorded solution layouts.

## Manual Verification

Run only when explicitly requested:

```bash
dotnet test sim/CellularSim.Tests
```

Do not run Godot or tests unless explicitly requested.

Latest recorded result before puzzle-level generator additions: `dotnet test sim/CellularSim.Tests` passed 33 tests. Run the suite again before committing these new changes.

Fresh-history status: `main` tracks `origin/main` at `https://github.com/grassrootseconomics/cellular.git`. The old copied history is preserved locally on `mycofig-history-backup`.

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

Puzzle level command:

```bash
dotnet run --no-restore --project sim/CellularSim.Examples -- --generate-puzzle-level --level 1 --level-seed 1001 --need-attempts 1 --layout-candidates 256 --solution-ticks 200 --save-dir sim/generated/level-001
```

Godot visual check:

```bash
dotnet restore Cellular.csproj
dotnet build Cellular.csproj
godot --path .
```

Use the .NET build of Godot 4.6.3. Open the title screen, press Puzzle, and test Level 1 dragging.
