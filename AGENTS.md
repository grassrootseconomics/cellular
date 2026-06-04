# Agent Defaults

- This repository is `grassrootseconomics/cellular`.
- Cellular is a deterministic C# simulation core and Godot .NET game with a GDScript web shim.
- Keep `sim/CellularSim` pure C#/.NET and independent of Godot APIs.
- C# is the authoritative simulation path; the GDScript web shim must match C# gameplay semantics.
- Rendering and gameplay must stay consistent across Puzzle, Arcade, native C#, GD renderer, fallback drawing, and web shim paths.
- Keep menus, HUDs, drag/drop UX, and lightweight scene orchestration in GDScript where useful.
- Prefer deterministic logic, explicit domain types, existing repo patterns, and allocation-conscious hot loops.
- Do not regenerate or replace shipped puzzle levels unless explicitly requested.
- Add or update focused unit/proof tests for behavior changes; only run Godot, tests, exports, profilers, or runtime verification when explicitly requested.
- Source inspection and non-mutating searches are OK. If verification is needed but not requested, provide manual verification steps.
- Prefer small, testable changes with clear verification steps.