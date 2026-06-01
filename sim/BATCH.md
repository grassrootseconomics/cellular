# Cellular Remote Puzzle Batch

This batch workflow searches for shipped Puzzle levels whose solution circuits
stay alive, not just levels that briefly latch `won`.

The remote server does not need Godot. It only needs the C# simulation and the
CLI level generator.

## Stability Rule

The remote stable rebuild now requires a circuit to stay alive for `200`
consecutive ticks at least once during the solver run. The puzzle scene
currently advances one sim tick every `0.12` seconds, so this is roughly:

```text
200 * 0.12 = 24 seconds
```

For the 20-level stable rebuild, use:

```text
STABLE_TICKS=200
WIN_DURATION_TICKS=200
REQUIRED_ALIVE_TICKS_AT_END=0
```

This means a candidate must:

- become a valid full directed circuit,
- keep that circuit alive long enough to satisfy the win duration.

Use `REQUIRED_ALIVE_TICKS_AT_END=200` only for a stricter soak test where the
circuit must also still be alive at the final solver tick.

## Remote Install

Connect:

```bash
ssh -i ~/.ssh/id_ed25519 root@128.140.120.36
```

Install system tools:

```bash
apt-get update
apt-get install -y git tmux rsync curl ca-certificates htop
apt-get install -y dotnet-sdk-8.0
```

If `dotnet-sdk-8.0` is not available from the server image package sources,
install Microsoft packages for the server's Ubuntu version and retry:

```bash
. /etc/os-release
curl -fsSL -o packages-microsoft-prod.deb "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb"
dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
apt-get update
apt-get install -y dotnet-sdk-8.0
```

Verify:

```bash
dotnet --version
tmux -V
rsync --version
```

## Clone And Build

On the remote:

```bash
cd /root
git clone https://github.com/grassrootseconomics/cellular.git
cd /root/cellular
dotnet restore sim/CellularSim.sln
dotnet build -c Release sim/CellularSim.Examples/CellularSim.Examples.csproj
```

If the GitHub repo is private or you prefer SSH, use your normal SSH Git remote
instead of the HTTPS clone URL.

## Smoke Run

Start with one level and fewer candidates. For a quick smoke run, use a lower
threshold explicitly so the command finishes quickly:

```bash
cd /root/cellular
LEVEL_START=1 LEVEL_END=1 WORKERS=1 NEED_ATTEMPTS=8 LAYOUT_CANDIDATES=11 \
STABLE_TICKS=20 WIN_DURATION_TICKS=20 REQUIRED_ALIVE_TICKS_AT_END=20 SOLUTION_TICKS=180 \
  scripts/run_puzzle_level_batch.sh stable-smoke
```

Inspect:

```bash
cat sim/batches/stable-smoke/summary.csv
cat sim/batches/stable-smoke/levels/level-001/results.txt
cat sim/batches/stable-smoke/levels/level-001/solution-map.txt
```

The result should show:

```text
stable at end: True
final sustained ticks: 20
```

or higher.

## Full 20-Level Stable-200 Batch

Run detached in `tmux` with 15 workers:

```bash
cd /root/cellular
scripts/start_stable_200_puzzle_levels_tmux.sh stable-levels-001-020-200
```

The wrapper uses:

```text
WORKERS=15
STABLE_TICKS=200
WIN_DURATION_TICKS=200
REQUIRED_ALIVE_TICKS_AT_END=0
SOLUTION_TICKS=600
NEED_ATTEMPTS=64
LAYOUT_CANDIDATES=11
```

This is a fast first pass. Rerun only failed levels with deeper settings.

Monitor:

```bash
tail -f sim/batches/stable-levels-001-020-200/stable-levels-001-020-200.log
tmux attach -t cellular-levels-200
```

The main log prints heartbeat lines like:

```text
[batch] progress 2026-06-01T11:20:00+00:00 finished=7/20 (35.0%) pass=7 fail=0 running=13 pending=0 unknown=0 active_workers=13
[batch] log_dir=sim/batches/stable-levels-001-020-200/logs summary=sim/batches/stable-levels-001-020-200/summary.csv
[batch] completed_levels=001,002,003,004,005,006,007
```

Per-level logs are under:

```text
sim/batches/stable-levels-001-020-200/logs/level-NNN.log
```

Each level log also prints internal solver progress every `PROGRESS_STRIDE`
layout candidates:

```text
[level-003] ... progress needAttempt=4/64 candidate=11/11 overall=44/704 (6.2%) best=stable=False won=True finalSustained=19 ...
```

Detach from tmux with `Ctrl-b`, then `d`.

Check status:

```bash
cat sim/batches/stable-levels-001-020-200/summary.csv
find sim/batches/stable-levels-001-020-200/logs -maxdepth 1 -type f -name '*.log' | sort
```

Each level writes:

```text
sim/batches/stable-levels-001-020-200/levels/level-NNN/level.json
sim/batches/stable-levels-001-020-200/levels/level-NNN/starting-fixture.json
sim/batches/stable-levels-001-020-200/levels/level-NNN/solution-fixture.json
sim/batches/stable-levels-001-020-200/levels/level-NNN/starting-map.txt
sim/batches/stable-levels-001-020-200/levels/level-NNN/solution-map.txt
sim/batches/stable-levels-001-020-200/levels/level-NNN/results.txt
```

## If A Level Fails

The generator changes resource needs across `NEED_ATTEMPTS`. Each attempt keeps
the rule that every cell produces its own unique resource and needs exactly
three non-self resources.

If one or more levels fail, rerun only those levels with a wider search:

```bash
cd /root/cellular
LEVEL_START=8 LEVEL_END=8 \
WORKERS=1 \
STABLE_TICKS=200 \
WIN_DURATION_TICKS=200 \
REQUIRED_ALIVE_TICKS_AT_END=0 \
SOLUTION_TICKS=1200 \
NEED_ATTEMPTS=1024 \
LAYOUT_CANDIDATES=11 \
scripts/start_puzzle_level_batch_tmux.sh stable-level-008-deep
```

For hard levels, increase in this order:

1. `NEED_ATTEMPTS`
2. `SOLUTION_TICKS`

`LAYOUT_CANDIDATES` is currently capped by the generator at `11`: one compact
canonical layout plus ten match-aware layouts. A deeper run should search more
need graphs, not more blind layouts.

Do not use `--allow-near-win` for shipped puzzle levels.

## Rsync Back

From the local machine:

```bash
rsync -avz -e "ssh -i ~/.ssh/id_ed25519" \
  root@128.140.120.36:/root/cellular/sim/batches/stable-levels-001-020-200/ \
  /home/wor/src/cellular/sim/batches/stable-levels-001-020-200/
```

Review locally before replacing shipped levels:

```bash
cd /home/wor/src/cellular
cat sim/batches/stable-levels-001-020-200/summary.csv
cat sim/batches/stable-levels-001-020-200/levels/level-008/results.txt
cat sim/batches/stable-levels-001-020-200/levels/level-008/solution-map.txt
```

After review, copy approved `level.json` files into `levels/puzzle/` using the
existing naming convention:

```bash
cp sim/batches/stable-levels-001-020-200/levels/level-008/level.json levels/puzzle/level-008-definition.json
```

Repeat for each approved level.

## Useful Remote Commands

Stop a running batch:

```bash
tmux kill-session -t cellular-levels-200
```

Start a second batch under a different tmux session:

```bash
SESSION=cellular-levels-deep LEVEL_START=8 LEVEL_END=8 scripts/start_puzzle_level_batch_tmux.sh stable-level-008-deep
```

Check CPU load:

```bash
htop
```

Check disk usage:

```bash
du -sh sim/batches/*
df -h
```
