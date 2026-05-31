# Debug Mode

Use debug mode to inspect a fixture setup and step the simulation without Godot.

## Start Interactive Debugging

```bash
dotnet run --project sim/CellularSim.Examples -- --debug sim/fixtures/routing.json
```

Verbose mode prints setup, an ASCII map, touching pairs, and richer per-tick context:

```bash
dotnet run --project sim/CellularSim.Examples -- --debug --verbose sim/fixtures/routing.json
```

## Run Scripted Commands

```bash
dotnet run --project sim/CellularSim.Examples -- --debug sim/fixtures/routing.json --commands "setup;state;tick;events;cell cell-a;tick 2;score"
```

Scripted verbose example:

```bash
dotnet run --project sim/CellularSim.Examples -- --debug --verbose sim/fixtures/routing.json --commands "setup;tick;events;cell cell-c"
```

## Commands

- `help`: show commands.
- `setup`: show each cell's produced resources, needed resources, any routing-only resources, and reaction set.
- `map`: show an ASCII grid. Cells are shown by produced-resource character, rocks as `#`, empty tiles as `.`.
- `touching`: show orthogonally touching cell pairs. Only these pairs can attempt swaps.
- `state`: show all current pool balances, glow state, strain, score, and circuit state.
- `cell <id>`: inspect one cell.
- `tick [n]`: advance one or more ticks and print outputs.
- `events`: show non-flow events for the current tick.
- `events all`: show all non-flow events currently in the bounded event buffer.
- `score`: show score and circuit state.
- `quit`: exit debug mode.

Debug mode hides raw `FlowEvent`s by default and shows human-facing `SwapEvent`, `ReactionEvent`, strain, overflow, and win-state output. Raw flow events still exist for future visuals and circuit checks.

Cells that are diagonal or separated by empty/rock tiles cannot swap. The future Godot game will move cells on this grid, and the sim should be rebuilt or updated after movement so touching pairs reflect the current map.

## Generate Larger Scenarios

Generated scenarios are deterministic from their seed and stay inside the same pool rules as fixtures: one produced `SourceOutput`, exactly three `Need` resources, four pool slots total, and a cap of `100` per slot.

Print a square 100-cell scenario and run a stability summary:

```bash
dotnet run --project sim/CellularSim.Examples -- --generate --seed 12345 --size 20 --cells 100 --resources 6 --rocks 30 --ticks 500
```

Save the generated fixture, ASCII map, and summary as text files:

```bash
dotnet run --project sim/CellularSim.Examples -- --generate --seed 12345 --size 20 --cells 100 --resources 6 --rocks 30 --ticks 500 --save-dir sim/generated/seed-12345
```

Generated outputs:

- `scenario.json`: reusable fixture.
- `map.txt`: human-readable setup plus compact ASCII map. Cell characters show produced resources.
- `results.txt`: swaps, reactions, strain, active cells, score breakdown, and stable-signal summary.

Example map legend:

```text
A = cell producing A
B = cell producing B
# = rock
. = empty
```

The stable signal is deliberately strict. A tiny pair of cells cycling late in the run is not considered stable if most cells are strained or inactive.

Use generated scenarios in debug mode:

```bash
dotnet run --project sim/CellularSim.Examples -- --generate --seed 12345 --size 20 --cells 100 --resources 6 --rocks 30 --debug --commands "map;touching;tick 10;score"
```
