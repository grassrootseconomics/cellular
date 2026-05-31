# Cellular Design Notes

## Core Frame

Cellular is a puzzle game about making circulation trustworthy, not merely fast.

The player is invited into stewardship: helping local cells exchange, fulfill needs, respect limits, recover from strain, and become less dependent on direct intervention. Scores are useful, but they should remain humble, plural, and answerable to real fulfillment.

Flow is not settlement. A bright loop that moves resources without fulfillment should not be treated as a healthy circuit.

## Commitment-Pooling Semantics

Use commitment-pooling ideas as architectural inspiration, not strict blockchain or ERC20 behavior.

A pool is a bounded local rule-space:

- Curation: what resources can enter.
- Valuation: how exchange is quoted.
- Limitation: caps, slots, throughput, and safety boundaries.
- Exchange: swaps, settlement, receipts, and events.

In Cellular, a cell is a simplified local pool. The current generated gameplay model gives each producer cell one produced resource and three needed resources. Later levels may include myco cells with no source: they produce nothing, render as `0` in ASCII maps, and matter because they can route and settle resources they receive. Routing may emerge when a cell trades resources it has received, but routing-only roles should remain experimental until the puzzle design clearly needs them.

## Durable Mechanic Tests

Before finalizing a mechanic, check:

1. Does this reward fulfillment rather than raw motion?
2. Does this preserve local limits?
3. Does this make strain visible?
4. Does this discourage hoarding and central control?
5. Does this make repair possible?
6. Does this keep scores humble and plural?
7. Does this help the player notice the difference between flow and settlement?
8. Does this invite stewardship rather than extraction?

If a mechanic fails these tests, pause and propose an alternative.

## Milestone 1 Boundaries

Milestone 1 implements only the minimum deterministic sim needed for:

- Direct reciprocity.
- Limits.
- Routing.
- Generated backend scenarios.
- Human-readable debug output.
- Basic scoring and stability summaries.
- Offline Puzzle mode level generation with recorded start and solution layouts.

The first implementation includes structure for richer scoring and strain, but should not overbuild dead-loop, repair, hoarding, autonomy, or Godot visual systems yet.

Generated scenario stability must not reward a tiny isolated loop as a healthy level. A stable-looking result should include broad participation, low strain, sustained swaps, and sustained reactions.

## Public Language

Use careful language:

- playable abstraction
- simulation core
- coordination model
- inspired by commitment pooling
- not strict blockchain behavior
- designed to teach and test assumptions

Do not claim that Cellular proves real-world reciprocal economies will work.
