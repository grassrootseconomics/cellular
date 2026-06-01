# Pool Semantics

Each cell has a bounded public pool.

## Resource Slots

A pool can have at most four resource slots. Each slot has a default capacity of `100`.

Generated milestone 1 scenarios currently use exactly four slots per producer cell:

- one `SourceOutput`: the resource this cell produces, offers to neighbors, and can accept back as returned output.
- three `Need` slots: resources this cell accepts from neighbors because it needs them.

Later fixtures may also include myco cells: cells with no source and no `SourceOutput` slot. A myco cell can still have `Need` slots, receive resources, swap resources it has already received, and react if all active slots are filled. In ASCII maps, myco cells render as `0`.

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
- `cell-a` can accept returned `A` from a neighbor; any returned `A` above cap `100` is discarded.
- `cell-a` accepts `B`, `C`, and `D` from neighbors.
- `cell-a` glows only when it has at least `1` each of `A`, `B`, `C`, and `D`.
- On reaction, it consumes `1` from each active slot.

If a cell must both keep one unit for its own reaction and give one unit away, its source must produce enough quantity for both purposes.

## Swap Validation

Swaps are bundled reciprocal trades. A touching edge can resolve at most one swap per tick, but that swap can move up to `4` units each way.

The base engine keeps conservative one-round swap behavior for older fixtures. Generated puzzle levels can opt into puzzle intent settings in fixture `engine` metadata:

- `swapRoundsPerTick`: allows unused edges to resolve in later rounds of the same tick, so relay cells can pass resources through chains without waiting a full tick per hop.
- `needDesiredQuantity`: a cell stops actively requesting a `Need` resource once it has this working stock, even though the slot cap remains `100`.
- `needOfferReserve`: a cell only offers a `Need` resource outward from surplus above this reserve.
- `allowNeedOverflowPayments`: lets a full `Need` slot accept a swap payment and discard overflow above cap, preventing gridlock from payment refusal. This is opt-in for puzzle fixtures; strict older fixtures still block full `Need` payments.

For `cell-a swapped 4 A for 4 C from cell-c`, the sim checks all of these before mutating state:

- `cell-a` has enough `A` available after prior reservations.
- `cell-c` has a slot that accepts `A`.
- If `cell-c` accepts `A` through a `Need` or `AcceptOnly` slot, it will not exceed the `A` slot capacity, normally `100`, unless the fixture has opted into `allowNeedOverflowPayments` for `Need` payment overflow.
- If `cell-c` accepts returned `A` through its own `SourceOutput` slot, the swap is allowed and any amount above cap is discarded.
- `cell-c` has enough `C` available after prior reservations.
- `cell-a` has a slot that accepts `C`.
- The same capacity rule applies: strict for `AcceptOnly`; strict for `Need` unless puzzle overflow payments are enabled; overflow-discard always applies for returned `SourceOutput`.
- If either side offers a `Need` resource, it may only offer surplus above the configured reserve, usually one unit in legacy fixtures and a larger relay reserve in puzzle fixtures.
- Producer cells also keep one unit of their own `SourceOutput` when they have needs, so a bundled swap cannot drain the produced resource needed for that same tick's reaction.

Only after those checks pass are both sides updated.

## Swap Arbitration

When two touching pairs want the same limited resource in the same tick, the engine does not let the first scanned edge win by accident. It gathers valid proposals first, then reserves swaps with this deterministic priority:

- the cell with the lowest balance of the requested `Need` resource gets first claim;
- if requested balances match, an offer that fills a counterparty's missing `Need` is preferred;
- returned `SourceOutput` payments are then preferred over non-missing top-ups as a gridlock release path;
- remaining top-ups prefer the counterparty with the lower balance of that resource;
- larger bundled swaps are preferred after those need-first priorities;
- if there is still a true tie, stable board/cell/resource ordering decides it.

This keeps cases like `C` needing `D=0` from losing `F`'s available `D` to `G` when `G` already has some `D`.

## Generated ASCII Maps

Generated maps render each cell by the first character of the resource it produces:

```text
A = cell producing A
B = cell producing B
0 = myco cell with no source
# = rock
. = empty
```

This makes the text map useful for reading local production patterns before opening the fixture JSON.
