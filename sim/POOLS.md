# Pool Semantics

Each cell has a bounded public pool.

## Resource Slots

A pool can have at most four resource slots. Each slot has a default capacity of `100`.

Generated milestone 1 scenarios use exactly four slots per cell:

- one `SourceOutput`: the resource this cell produces and offers to neighbors.
- three `Need` slots: resources this cell accepts from neighbors because it needs them.

The code still supports `AcceptOnly`, a routing-only resource that can be received without being part of the reaction set. It is retained for small proof cases and design experiments, but it is not used by generated scenarios and may be removed or renamed after v1 pool rules settle.

## Reaction Set

A cell glows when it has at least `1` unit in every active resource slot.

Active resource slots are:

- `SourceOutput`
- `Need`

When the cell reacts, it consumes `1` unit from each active slot.

`AcceptOnly` slots do not trigger reactions and are not consumed by reactions. Current generated gameplay should avoid `AcceptOnly` unless a test is explicitly proving routing-only behavior.

## Basic Swap Pattern

A cell generally offers what it produces first. If it has extra received resources, the engine can also use those in later swaps. Resources move through atomic swaps, not loose gifts.

Example:

```text
cell-a
  produces/offers: A
  accepts/needs: B, C, D
  glows after holding: A + B + C + D
```

This means:

- `cell-a` produces `A` into its own pool.
- `cell-a` can swap `A` with a neighbor that needs `A`.
- `cell-a` accepts `B`, `C`, and `D` from neighbors.
- `cell-a` glows only when it has at least `1` each of `A`, `B`, `C`, and `D`.
- On reaction, it consumes `1` from each active slot.

If a cell must both keep one unit for its own reaction and give one unit away, its source must produce enough quantity for both purposes.

## Swap Validation

For `cell-a swapped 1 A for 1 C from cell-c`, the sim checks all of these before mutating state:

- `cell-a` has at least `1 A` available after prior reservations.
- `cell-c` has a non-`SourceOutput` slot that accepts `A`.
- `cell-c` will not exceed the `A` slot capacity, normally `100`.
- `cell-c` has at least `1 C` available after prior reservations.
- `cell-a` has a non-`SourceOutput` slot that accepts `C`.
- `cell-a` will not exceed the `C` slot capacity, normally `100`.

Only after those checks pass are both sides updated.

## Generated ASCII Maps

Generated maps render each cell by the first character of the resource it produces:

```text
A = cell producing A
B = cell producing B
# = rock
. = empty
```

This makes the text map useful for reading local production patterns before opening the fixture JSON.
