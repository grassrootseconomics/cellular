# Cellular Remote Puzzle Batch

This batch workflow searches for shipped Puzzle levels whose solution circuits
stay alive, not just levels that briefly latch `won`.

The remote server does not need Godot. It only needs the C# simulation and the
CLI level generator.

## Stability Rule

The puzzle scene currently advances one sim tick every `0.12` seconds.
Ten seconds is therefore:

```text
ceil(10 / 0.12) = 84 ticks
```

For the first stable batch, use:

```text
STABLE_TICKS=84
WIN_DURATION_TICKS=84
REQUIRED_ALIVE_TICKS_AT_END=84
```

This means a candidate must:

- become a valid full directed circuit,
- keep that circuit alive long enough to satisfy the win duration,
- still be alive at the end of the solver run with at least `84` consecutive
  alive ticks.

This prevents transient cases such as a level that completes briefly and then
breaks apart.

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

Start with one level and fewer candidates:

```bash
cd /root/cellular
LEVEL_START=1 LEVEL_END=1 WORKERS=1 NEED_ATTEMPTS=8 LAYOUT_CANDIDATES=64 SOLUTION_TICKS=180 \
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
final sustained ticks: 84
```

or higher.

## Full 20-Level Batch

Run detached in `tmux` with 15 workers:

```bash
cd /root/cellular
WORKERS=15 \
STABLE_TICKS=84 \
WIN_DURATION_TICKS=84 \
REQUIRED_ALIVE_TICKS_AT_END=84 \
SOLUTION_TICKS=420 \
NEED_ATTEMPTS=256 \
LAYOUT_CANDIDATES=2048 \
scripts/start_puzzle_level_batch_tmux.sh stable-levels-001-020
```

Monitor:

```bash
tail -f sim/batches/stable-levels-001-020/stable-levels-001-020.log
tmux attach -t cellular-levels
```

Detach from tmux with `Ctrl-b`, then `d`.

Check status:

```bash
cat sim/batches/stable-levels-001-020/summary.csv
find sim/batches/stable-levels-001-020/logs -maxdepth 1 -type f -name '*.log' | sort
```

Each level writes:

```text
sim/batches/stable-levels-001-020/levels/level-NNN/level.json
sim/batches/stable-levels-001-020/levels/level-NNN/starting-fixture.json
sim/batches/stable-levels-001-020/levels/level-NNN/solution-fixture.json
sim/batches/stable-levels-001-020/levels/level-NNN/starting-map.txt
sim/batches/stable-levels-001-020/levels/level-NNN/solution-map.txt
sim/batches/stable-levels-001-020/levels/level-NNN/results.txt
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
STABLE_TICKS=84 \
WIN_DURATION_TICKS=84 \
REQUIRED_ALIVE_TICKS_AT_END=84 \
SOLUTION_TICKS=600 \
NEED_ATTEMPTS=1024 \
LAYOUT_CANDIDATES=8192 \
scripts/start_puzzle_level_batch_tmux.sh stable-level-008-deep
```

For hard levels, increase in this order:

1. `LAYOUT_CANDIDATES`
2. `NEED_ATTEMPTS`
3. `SOLUTION_TICKS`

Do not use `--allow-near-win` for shipped puzzle levels.

## Rsync Back

From the local machine:

```bash
rsync -avz -e "ssh -i ~/.ssh/id_ed25519" \
  root@128.140.120.36:/root/cellular/sim/batches/stable-levels-001-020/ \
  /home/wor/src/cellular/sim/batches/stable-levels-001-020/
```

Review locally before replacing shipped levels:

```bash
cd /home/wor/src/cellular
cat sim/batches/stable-levels-001-020/summary.csv
cat sim/batches/stable-levels-001-020/levels/level-008/results.txt
cat sim/batches/stable-levels-001-020/levels/level-008/solution-map.txt
```

After review, copy approved `level.json` files into `levels/puzzle/` using the
existing naming convention:

```bash
cp sim/batches/stable-levels-001-020/levels/level-008/level.json levels/puzzle/level-008-definition.json
```

Repeat for each approved level.

## Useful Remote Commands

Stop a running batch:

```bash
tmux kill-session -t cellular-levels
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
