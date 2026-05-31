# Scoring And Stability

Scoring is provisional. It exists to make generated runs inspectable, not to define final player-facing level scores.

## Current Score Formula

`ScoreState.TotalScore` is currently:

```text
ReactionScore
+ FlowDiversityScore
+ SettlementScore
+ ResilienceScore
+ RepairScore
+ AutonomyScore
- StrainPenalty
- HoardingPenalty
- DeadLoopPenalty
```

Only these components are active in milestone 1:

- `ReactionScore`: `+10` for each cell reaction.
- `FlowDiversityScore`: `+2` for each distinct resource seen in the bounded flow event buffer.
- `SettlementScore`: `+1` for each reaction event in the bounded event buffer.
- `StrainPenalty`: total accumulated strain across all cells.

The other score fields exist as placeholders for later design work.

## Strain Penalty

Each cell has a `StrainState`:

```text
UnmetNeedTicks
+ FailedSwapCount
+ SourceBlockedTicks
+ OverCapacityPressureTicks
```

`StrainPenalty` is the sum of that total across every cell. A large negative score usually means many cells are idle with unmet needs, blocked production, full source slots, or overflow pressure.

## Generated Stability Signal

Generated scenario summaries report `stable signal`. This is not a win condition. It is a search heuristic for finding interesting backend configurations.

A generated run currently needs all of these to count as stable:

- at least one swap in the last summary window,
- at least one reaction in the last summary window,
- last-window reactions not collapsed below a quarter of the first-window reactions,
- active cells in the last window at least `max(3, cellCount / 5)`,
- cells with strain no more than half of all cells.

This deliberately rejects tiny isolated loops. For example, a 100-cell map where only two cells keep cycling should not be considered stable.

## Current Limitation

The score is cumulative and blunt. It is useful for backend search, but final game scoring should separate:

- settlement,
- breadth of participation,
- sustained flow,
- repair,
- low strain,
- efficient use of limits,
- visual chain-reaction beauty.
