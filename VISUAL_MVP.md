# Visual MVP

Godot should start with simple readable 2D tokens. The final liquid-cell look can come after movement, swapping, and level generation are playable.

## Token Readability

Each producer cell should show:

- a colored circular body,
- the produced resource letter or icon in the center,
- three small need pips around the edge,
- brighter pips when that resource is present,
- dim pips when missing,
- a clear glow when the cell has recently reacted.

Current visual meaning:

- **Produced resource:** center letter/icon.
- **Need resources:** three outer pips or wedges.
- **Glow:** recent reaction.
- **Flow/current:** active transfer across adjacent cells.
- **Strain:** subtle warning tint or pulse when needs stay unmet.
- **Myco cell:** no produced resource; shown as `0` in ASCII/debug and later as a distinct neutral token.

## Drag Feedback

Dragging should feel tactile even before final art:

- large soft glow under the finger,
- slight token lift/scale while dragging,
- valid adjacent contacts pulse,
- invalid/blocked contacts stay muted,
- release snaps to a valid empty tile.

## Future Liquid Cell Direction

Later art can replace the token shell with:

- translucent membrane,
- visible inner particles,
- soft nucleus/resource core,
- subtle membrane wobble,
- flowing luminous strands between touching cells,
- stronger bloom for sustained circuits.

The visual upgrade should not change the sim contract: Godot presents state, while C# decides swaps, reactions, strain, score, and win state.

## Sketch Prompts

Use these prompts later for concept images or production references:

```text
Top-down 2D game token: translucent slime-like cell, soft membrane, glowing inner resource core, three small need pips around edge, readable mobile UI, dark clean background.
```

```text
Puzzle board concept: tiled grid with colorful liquid cells, visible resource letters/icons, glowing connection currents between adjacent cells, simple readable mobile game layout.
```

```text
Finger drag effect: mobile touch glow around a dragged cell, soft radial light, subtle particle trail, valid adjacent cells pulsing.
```
