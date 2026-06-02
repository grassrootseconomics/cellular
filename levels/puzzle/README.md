# Puzzle Level Fixtures

Godot looks here first for approved puzzle fixtures:

```text
res://levels/puzzle/level-001.json
res://levels/puzzle/level-002.json
...
```

If a shipped fixture is missing during development, the Puzzle scene builds a temporary open-board fallback and still runs it through the C# bridge.

Generated C# artifacts can be copied here from:

```text
sim/generated/level-001/starting-fixture.json
```

## Shipped Levels

Current shipped playable levels are the Godot-loaded start fixtures:

- `level-NNN.json`: separated player start fixture loaded by Godot.
- `level-NNN.txt`: ASCII map of the initial live fixture setup.
- `level-NNN-solution.txt`: full-board ASCII map of a known live solution layout, when known.

The latest generated setup artifacts are saved under:

```text
sim/generated/playable-1-200/level-NNN/
```

Setup and solution maps use two-character tokens so duplicate producers are
unambiguous:

- `A1`, `A2`, ... for normal resource-producing cells.
- `01`, `02`, ... for white-myco cells.
- `*1`, `*2`, ... for red-myco cells.
- `##` for rocks/blocked spaces.
- `..` for fully empty spaces.

When a marker has more than nine cells, the suffix continues with single
characters such as `A`, `B`, and so on, keeping each token exactly two
characters.

Each `.txt` map includes a legend with the concrete cell id, produced resource
or myco type, and needs for every numbered cell token.
