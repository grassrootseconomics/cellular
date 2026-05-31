# Godot .NET Architecture

Cellular uses Godot .NET so the project can keep fast iteration in GDScript while running heavy simulation logic in C#.

## Shape

- `Cellular.csproj` is the Godot .NET project.
- `src/CellularSimBridge.cs` is the Godot-facing C# autoload.
- `sim/CellularSim` remains a pure `net8.0` C# library with no Godot APIs.
- GDScript scenes should call the bridge for simulation snapshots instead of reimplementing swap/reaction rules.

## Runtime Contract

The bridge owns:

- fixture loading,
- cell movement in the sim grid,
- deterministic ticks,
- source production,
- swaps,
- reactions,
- glow state,
- score and win state,
- inventory quantities and fullness.

Godot scenes own:

- title/menu flow,
- drag/drop input,
- board drawing,
- cell art,
- swap particles,
- HUD labels.

## Manual Setup

Use the .NET build of Godot 4.6.3 for this project. The standard non-.NET Godot editor will not load `src/CellularSimBridge.cs`.

Manual checks:

```bash
dotnet restore Cellular.csproj
dotnet build Cellular.csproj
godot --path .
```

Depending on how Godot .NET is installed, the executable may instead be named:

```bash
godot4-mono --path .
godot-mono --path .
Godot_v4.6.3-stable_mono_linux.x86_64 --path .
```

The non-.NET executable usually appears as `godot`, `godot4`, or `godot4 --path .`; those can run the GDScript fallback but cannot load the C# bridge.

Run these manually only when requested by the repo owner.
