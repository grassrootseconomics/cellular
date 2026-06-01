# Cellular

Cellular is a deterministic simulation core and future Godot puzzle game from Grassroots Economics.

It is a living-circuit puzzle about pools, limits, routing, mutual fulfillment, and settlement. The goal is not simply to maximize flow. The goal is to make circulation trustworthy.

The game is inspired by Social Soil, commitment pooling, and work on games, agency, scoring, and value capture. Cellular treats each cell as a small bounded pool: it can produce one resource, need other resources, become strained, glow when fulfilled, and participate in wider circuits. Some cells may be myco cells with no source; these can route and fulfill received resources without producing their own.

This is not a blockchain implementation and not a proof of real-world economic outcomes. It is a playable coordination model for testing assumptions about flow, limits, repair, and fulfillment.

## Current Milestone

The backend milestone is a standalone C# simulation core under `sim/CellularSim` with tests under `sim/CellularSim.Tests`.

Godot visual testing has started with a small title screen and shipped Puzzle levels 1-20. The project now targets Godot .NET so GDScript can handle menus and UX while C# owns swaps, reactions, scoring, strain, inventory state, and generated level validation.

## Manual Verification

Run tests manually from the repository root when needed:

```bash
dotnet test sim/CellularSim.Tests
```

Run the Godot project manually from the .NET build of Godot. The main scene is `res://scenes/title_screen.tscn`.

## Documentation Map

- [AGENTS.md](AGENTS.md): durable agent and contributor rules.
- [DESIGN.md](DESIGN.md): design philosophy and mechanic guardrails.
- [GODOT_NET.md](GODOT_NET.md): Godot .NET architecture and bridge contract.
- [LEVELS.md](LEVELS.md): puzzle/arcade level generation and solver artifacts.
- [VISUAL_MVP.md](VISUAL_MVP.md): simple token visuals and future liquid-cell direction.
- [PLANS.md](PLANS.md): current milestone, status, and next work.
- [sim/POOLS.md](sim/POOLS.md): pool, slot, swap, and reaction semantics.
- [sim/DEBUG.md](sim/DEBUG.md): fixture inspection, ASCII maps, generated scenarios.
- [sim/BATCH.md](sim/BATCH.md): remote tmux batch workflow for stable puzzle-level generation.
- [sim/SCORING.md](sim/SCORING.md): current score and stability calculations.
- [sim/TESTING.md](sim/TESTING.md): unit/proof test map and fixture rules.
- [sim/PERFORMANCE.md](sim/PERFORMANCE.md): current hot-path constraints and next optimizations.

Print a human-readable three-pool example:

```bash
dotnet run --project sim/CellularSim.Examples -- sim/fixtures/routing.json 3
```

Start interactive debug mode:

```bash
dotnet run --project sim/CellularSim.Examples -- --debug sim/fixtures/routing.json
```

Start verbose debug mode with ASCII map and touching-pair inspection:

```bash
dotnet run --project sim/CellularSim.Examples -- --debug --verbose sim/fixtures/routing.json
```

Generate and inspect a deterministic 100-cell backend scenario:

```bash
dotnet run --project sim/CellularSim.Examples -- --generate --seed 12345 --size 20 --cells 100 --resources 6 --rocks 30 --ticks 500 --save-dir sim/generated/seed-12345
```

Generated scenario outputs:

- `scenario.json`: reusable fixture.
- `map.txt`: setup plus ASCII map, where producer-cell characters show produced resources and `0` marks myco/no-source cells.
- `results.txt`: swaps, reactions, strain, score breakdown, and stability signal.

Generate an offline puzzle level with a recorded start and solution layout:

```bash
dotnet run --no-restore --project sim/CellularSim.Examples -- --generate-puzzle-level --level 1 --level-seed 1001 --need-attempts 1 --layout-candidates 256 --solution-ticks 200 --save-dir sim/generated/level-001
```

Approved Puzzle fixtures are under `levels/puzzle/`. Each shipped level has a player start fixture, a verified solution fixture, and a compact ASCII solution map.

The existing older Godot gameplay files are temporary reference material from the copied repository. The active Cellular Godot entry point is the title screen, with `res://scenes/cellular_puzzle_level.tscn` as the first Puzzle mode test scene.

Do not run Godot or test commands automatically in this repository unless explicitly requested.
