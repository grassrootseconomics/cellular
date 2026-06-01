#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

export SESSION="${SESSION:-cellular-levels-200}"
export WORKERS="${WORKERS:-15}"
export LEVEL_START="${LEVEL_START:-1}"
export LEVEL_END="${LEVEL_END:-20}"
export STABLE_TICKS="${STABLE_TICKS:-200}"
export WIN_DURATION_TICKS="${WIN_DURATION_TICKS:-$STABLE_TICKS}"
export REQUIRED_ALIVE_TICKS_AT_END="${REQUIRED_ALIVE_TICKS_AT_END:-$STABLE_TICKS}"
export SOLUTION_TICKS="${SOLUTION_TICKS:-600}"
export NEED_ATTEMPTS="${NEED_ATTEMPTS:-64}"
export LAYOUT_CANDIDATES="${LAYOUT_CANDIDATES:-512}"
export EVENT_CAPACITY="${EVENT_CAPACITY:-1048576}"
export HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-60}"
export PROGRESS_STRIDE="${PROGRESS_STRIDE:-128}"

JOB="${1:-stable-levels-001-020-200}"
exec bash scripts/start_puzzle_level_batch_tmux.sh "$JOB"
