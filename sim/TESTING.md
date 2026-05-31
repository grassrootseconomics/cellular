# Cellular Sim Testing

The test suite is organized around two goals:

1. Unit tests for small deterministic invariants.
2. Proof-style scenario tests that demonstrate game rules with concrete fixtures.

Run manually from the repository root:

```bash
dotnet test sim/CellularSim.Tests
```

Print the current three-pool example:

```bash
dotnet run --project sim/CellularSim.Examples -- sim/fixtures/routing.json 3
```

## Unit Test Map

- `CoreTests`
  - dense resource IDs
  - slot caps
  - four-slot pool limit
  - private inventory movement
  - reaction consumption rules
  - experimental `AcceptOnly` slots do not trigger reactions
- `EngineTests`
  - source production
  - cap pressure and overflow events
  - reciprocal adjacent swaps
  - rock-blocked edges
  - routing through accepted resources
  - deterministic repeated runs
- `FixtureTests`
  - fixture loading
  - duplicate cell rejection
  - cells on rocks
  - invalid resources
  - more than four slots
  - starting quantity above cap
  - source resource missing from pool
  - missing required win entities
- `ProofTests`
  - unpaired resources do not move without a valid swap
  - no diagonal exchange
  - source output plus needed input consumed by reaction
  - edge throughput limit
  - sustained living-circuit win
- `GeneratedScenarioTests`
  - deterministic generation by seed
  - generated cells use one `SourceOutput` and three `Need` slots
  - generated cells and rocks do not overlap
  - generated summaries can inspect larger runs
- `LevelGenerationTests`
  - puzzle level 1 has four unique resources and all-other needs
  - higher levels keep one unique producer and three non-self needs per cell
  - generated puzzle levels record start layout, solution layout, and solver summary
  - strict puzzle generation rejects unsolved candidates
  - separated start layouts do not solve before player movement

## Proof Fixtures

Fixtures under `sim/fixtures/proof-*.json` are intentionally small. Each one should demonstrate one rule without depending on the whole game loop.

When adding a rule, add a proof fixture or direct proof test that shows:

- the exact initial state,
- the tick count needed,
- the expected events,
- the expected final state.

This keeps rules auditable before they are turned into Godot visuals.

Latest recorded run before puzzle-level generator additions: `dotnet test sim/CellularSim.Tests` passed 33 tests. Run the suite again before committing the new level-generation work.
