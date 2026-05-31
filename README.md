# Cellular

Cellular is a deterministic simulation core and future Godot puzzle game from Grassroots Economics.

It is a living-circuit puzzle about pools, limits, routing, mutual fulfillment, and settlement. The goal is not simply to maximize flow. The goal is to make circulation trustworthy.

The game is inspired by Social Soil, commitment pooling, and work on games, agency, scoring, and value capture. Cellular treats each cell as a small bounded pool: it can produce one resource, need other resources, become strained, glow when fulfilled, and participate in wider circuits.

This is not a blockchain implementation and not a proof of real-world economic outcomes. It is a playable coordination model for testing assumptions about flow, limits, repair, and fulfillment.

## Current Milestone

The first milestone is a standalone C# simulation core under `sim/CellularSim` with tests under `sim/CellularSim.Tests`.

Godot integration is intentionally deferred until the sim core is stable.

## Manual Verification

Run tests manually from the repository root when needed:

```bash
dotnet test sim/CellularSim.Tests
```

## Documentation Map

- [AGENTS.md](AGENTS.md): durable agent and contributor rules.
- [DESIGN.md](DESIGN.md): design philosophy and mechanic guardrails.
- [PLANS.md](PLANS.md): current milestone, status, and next work.
- [sim/POOLS.md](sim/POOLS.md): pool, slot, swap, and reaction semantics.
- [sim/DEBUG.md](sim/DEBUG.md): fixture inspection, ASCII maps, generated scenarios.
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
- `map.txt`: setup plus ASCII map, where cell characters show the resource produced by each cell.
- `results.txt`: swaps, reactions, strain, score breakdown, and stability signal.

The existing Godot project files are temporary reference material from the copied repository. Do not treat the old Play Store, Android, web export, or scene docs as current Cellular release material.

Do not run Godot or test commands automatically in this repository unless explicitly requested.
