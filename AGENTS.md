# Agent Defaults

- This repository is `grassrootseconomics/cellular`.
- Cellular is a deterministic C# simulation core and later Godot .NET game.
- First milestone is the standalone C# sim under `sim/`; do not create Godot scenes or convert the project to Godot .NET yet.
- Keep simulation code independent of Godot APIs.
- Prefer deterministic logic, explicit domain types, and allocation-conscious hot loops.
- Keep AGPL licensing and replace old mycofig/Social Soil branding as Cellular work advances.
- Do not run Godot, tests, or runtime verification commands automatically.
- Only run checks when explicitly requested by the user.
- If verification is needed but not requested, provide manual verification steps instead.
