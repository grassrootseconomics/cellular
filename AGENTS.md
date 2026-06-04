# Agent Defaults

- This repository is `grassrootseconomics/cellular`.
- Cellular is a deterministic C# simulation core and Godot .NET game.
- There is a web shim GD script and C# rendering going on - these all need to be consistent and updated. 
- Keep menus and lightweight UX in GDScript where useful; keep heavy simulation, swap, scoring, and validation logic in C#.
- Keep simulation code independent of Godot APIs.
- Prefer deterministic logic, explicit domain types, and allocation-conscious hot loops.
- Keep AGPL licensing and replace old mycofig/legacy branding as Cellular work advances.
- Do not run Godot, tests, or runtime verification commands automatically.
- Only run checks when explicitly requested by the user.
- If verification is needed but not requested, provide manual verification steps instead.
