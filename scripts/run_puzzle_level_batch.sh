#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

JOB="${1:-stable-levels-001-020}"
OUTPUT_ROOT="${OUTPUT_ROOT:-sim/batches/$JOB}"
LEVEL_START="${LEVEL_START:-1}"
LEVEL_END="${LEVEL_END:-20}"
WORKERS="${WORKERS:-15}"
SEED_BASE="${SEED_BASE:-1000}"
NEED_ATTEMPTS="${NEED_ATTEMPTS:-256}"
LAYOUT_CANDIDATES="${LAYOUT_CANDIDATES:-2048}"
SOLUTION_TICKS="${SOLUTION_TICKS:-420}"
SIM_TICK_SECONDS="${SIM_TICK_SECONDS:-0.12}"
STABLE_TICKS="${STABLE_TICKS:-84}"
WIN_DURATION_TICKS="${WIN_DURATION_TICKS:-$STABLE_TICKS}"
REQUIRED_ALIVE_TICKS_AT_END="${REQUIRED_ALIVE_TICKS_AT_END:-$STABLE_TICKS}"
EVENT_CAPACITY="${EVENT_CAPACITY:-1048576}"
CONFIGURATION="${CONFIGURATION:-Release}"

mkdir -p "$OUTPUT_ROOT/logs" "$OUTPUT_ROOT/status" "$OUTPUT_ROOT/levels"

if ! command -v dotnet >/dev/null 2>&1; then
  echo "[batch] dotnet is required." >&2
  exit 127
fi

cat > "$OUTPUT_ROOT/run.env" <<EOF
JOB=$JOB
OUTPUT_ROOT=$OUTPUT_ROOT
LEVEL_START=$LEVEL_START
LEVEL_END=$LEVEL_END
WORKERS=$WORKERS
SEED_BASE=$SEED_BASE
NEED_ATTEMPTS=$NEED_ATTEMPTS
LAYOUT_CANDIDATES=$LAYOUT_CANDIDATES
SOLUTION_TICKS=$SOLUTION_TICKS
SIM_TICK_SECONDS=$SIM_TICK_SECONDS
STABLE_TICKS=$STABLE_TICKS
WIN_DURATION_TICKS=$WIN_DURATION_TICKS
REQUIRED_ALIVE_TICKS_AT_END=$REQUIRED_ALIVE_TICKS_AT_END
EVENT_CAPACITY=$EVENT_CAPACITY
CONFIGURATION=$CONFIGURATION
EOF

echo "[batch] job=$JOB"
echo "[batch] output_root=$OUTPUT_ROOT"
echo "[batch] levels=$LEVEL_START..$LEVEL_END workers=$WORKERS"
echo "[batch] stable_ticks=$STABLE_TICKS (~$(awk "BEGIN { printf \"%.2f\", $STABLE_TICKS * $SIM_TICK_SECONDS }") seconds at $SIM_TICK_SECONDS s/tick)"
echo "[batch] need_attempts=$NEED_ATTEMPTS layout_candidates=$LAYOUT_CANDIDATES solution_ticks=$SOLUTION_TICKS"
echo "[batch] restoring and building $CONFIGURATION"

dotnet restore sim/CellularSim.sln
dotnet build --no-restore -c "$CONFIGURATION" sim/CellularSim.Examples/CellularSim.Examples.csproj

running_jobs() {
  jobs -rp | wc -l
}

wait_for_slot() {
  while [[ "$(running_jobs)" -ge "$WORKERS" ]]; do
    sleep 2
  done
}

run_level() {
  local level="$1"
  local level_padded
  printf -v level_padded "%03d" "$level"
  local seed=$((SEED_BASE + level))
  local out_dir="$OUTPUT_ROOT/levels/level-$level_padded"
  local log_file="$OUTPUT_ROOT/logs/level-$level_padded.log"
  local status_file="$OUTPUT_ROOT/status/level-$level_padded.status"

  mkdir -p "$out_dir"
  {
    echo "[level-$level_padded] start $(date -Is)"
    echo "[level-$level_padded] seed=$seed"
    echo "[level-$level_padded] out_dir=$out_dir"
    dotnet run --no-restore --no-build -c "$CONFIGURATION" --project sim/CellularSim.Examples -- \
      --generate-puzzle-level \
      --level "$level" \
      --level-seed "$seed" \
      --need-attempts "$NEED_ATTEMPTS" \
      --layout-candidates "$LAYOUT_CANDIDATES" \
      --solution-ticks "$SOLUTION_TICKS" \
      --win-duration-ticks "$WIN_DURATION_TICKS" \
      --required-alive-ticks-at-end "$REQUIRED_ALIVE_TICKS_AT_END" \
      --event-capacity "$EVENT_CAPACITY" \
      --save-dir "$out_dir"
    echo "[level-$level_padded] complete $(date -Is)"
  } >"$log_file" 2>&1

  {
    echo "status=pass"
    echo "level=$level"
    echo "seed=$seed"
    echo "output=$out_dir"
    echo "log=$log_file"
  } >"$status_file"
}

pids=()
for level in $(seq "$LEVEL_START" "$LEVEL_END"); do
  wait_for_slot
  run_level "$level" &
  pids+=("$!")
done

status=0
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then
    status=1
  fi
done

{
  echo "level,status,seed,output,log"
  for level in $(seq "$LEVEL_START" "$LEVEL_END"); do
    printf -v level_padded "%03d" "$level"
    status_file="$OUTPUT_ROOT/status/level-$level_padded.status"
    if [[ -f "$status_file" ]]; then
      seed="$(awk -F= '$1 == "seed" { print $2 }' "$status_file")"
      output="$(awk -F= '$1 == "output" { print $2 }' "$status_file")"
      log="$(awk -F= '$1 == "log" { print $2 }' "$status_file")"
      echo "$level,pass,$seed,$output,$log"
    else
      echo "$level,fail,,,${OUTPUT_ROOT}/logs/level-$level_padded.log"
    fi
  done
} > "$OUTPUT_ROOT/summary.csv"

echo "[batch] done status=$status"
echo "[batch] summary=$OUTPUT_ROOT/summary.csv"
echo "[batch] logs=$OUTPUT_ROOT/logs"
exit "$status"
