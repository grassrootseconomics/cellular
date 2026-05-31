# Level Generation

Cellular has two planned game modes.

## Puzzle Mode

Puzzle levels are generated offline, checked by the C# sim, and shipped only after they have an accepted solution.

Rules for the first puzzle progression:

- Level `1` has `4` producer cells.
- Level `2` has `5` producer cells.
- Level `3` has `6` producer cells.
- In general, cell count is `levelNumber + 3`.
- Every producer cell has one unique produced resource.
- Every producer cell has exactly three `Need` resources chosen from resources that exist in that level.
- A cell never needs its own produced resource.
- Level `1` has four resources, so every cell necessarily needs the other three resources.

Generated puzzle levels record both:

- `startingLayout`: the separated player-facing starting position on a compact board one tile larger on each side than the solution bounds.
- `solutionLayout`: the best known arrangement found by backend search.

The solution is used for verification, hints, and post-level review. The start layout should usually leave empty movement space so the player can drag cells into better contact without forcing the board into a long horizontal row.

Approved solution layouts should fit inside that level's starting grid, so a player can reproduce the hint map without needing cells outside the playable board.

Levels 1-20 are currently shipped in `levels/puzzle/`. Each has:

- `level-NNN.json`: compact randomized player start fixture.
- `level-NNN-solution.json`: verified backend solution fixture.
- `level-NNN-solution.txt`: compact ASCII solution map.
- `level-NNN-definition.json`: generation seed, cells, start layout, solution layout, and solver summary.

The first levels use a seeded solvable need graph and an optimized compact 2D solution search. The solver checks folded-line serpentines before the full straight-line fallback, and it keeps searching later need graphs when the only win so far is a long one-row layout.

## Arrangement Search

The puzzle generator creates cell definitions first, then searches layouts.

For each candidate layout it:

- builds a fixture,
- runs the deterministic C# sim,
- records swaps, reactions, glowing cells, strain, score, and win state,
- keeps the best winning layout, or a near-winning layout only when explicitly allowed.

Strict puzzle generation rejects unsolved levels. Near-winning output is useful for design exploration but should not become a shipped puzzle unless manually approved.

Example command:

```bash
dotnet run --no-restore --project sim/CellularSim.Examples -- --generate-puzzle-level --level 1 --level-seed 1001 --need-attempts 1 --layout-candidates 256 --solution-ticks 200 --save-dir sim/generated/level-001
```

Generated files:

- `level.json`: level metadata, cells, start layout, solution layout, and solver summary.
- `starting-fixture.json`: fixture for the player start.
- `solution-fixture.json`: fixture for the best known solution.
- `solution-map.txt`: compact ASCII solution map.
- `results.txt`: human-readable solver summary.

Generated output directories also include `starting-map.txt` for quick inspection before copying fixtures into `levels/puzzle/`.

## Arcade Mode

Arcade mode is planned after puzzle generation and movement are stable.

Initial direction:

- continuous board,
- hand of three random cells,
- drag one cell from the hand onto the board,
- completed circuits clear from the board,
- game over when no placement remains.

Arcade should reuse the same C# swap/reaction engine, but its generation and scoring can be looser than Puzzle mode.
