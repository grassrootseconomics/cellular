#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

JOB="${1:-shape-first-021-200}"
OUTPUT_ROOT="${OUTPUT_ROOT:-sim/batches/$JOB}"
LEVEL_START="${LEVEL_START:-21}"
LEVEL_END="${LEVEL_END:-200}"
WORKERS="${WORKERS:-15}"
LEVEL_SEED_BASE="${LEVEL_SEED_BASE:-1000}"
LAYOUT_CANDIDATES="${LAYOUT_CANDIDATES:-512}"
SOLUTION_TICKS="${SOLUTION_TICKS:-900}"
SOURCE_RATE="${SOURCE_RATE:-32}"
MAX_SWAP_QUANTITY_PER_EDGE="${MAX_SWAP_QUANTITY_PER_EDGE:-8}"
WIN_DURATION_TICKS="${WIN_DURATION_TICKS:-3}"
REQUIRED_ALIVE_TICKS_AT_END="${REQUIRED_ALIVE_TICKS_AT_END:-0}"
SHAPE_FIRST_SUSTAINED_TICKS="${SHAPE_FIRST_SUSTAINED_TICKS:-0}"
EVENT_CAPACITY="${EVENT_CAPACITY:-1048576}"
CONFIGURATION="${CONFIGURATION:-Release}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-60}"
PROGRESS_STRIDE="${PROGRESS_STRIDE:-128}"
SHIP_DIR="${SHIP_DIR:-levels/puzzle}"
SKIP_RESTORE_BUILD="${SKIP_RESTORE_BUILD:-0}"

if (( LEVEL_END < LEVEL_START )); then
  echo "[shape-first] LEVEL_END must be greater than or equal to LEVEL_START." >&2
  exit 2
fi

if (( WORKERS < 1 )); then
  echo "[shape-first] WORKERS must be positive." >&2
  exit 2
fi

TOTAL_LEVELS=$((LEVEL_END - LEVEL_START + 1))
if (( WORKERS > TOTAL_LEVELS )); then
  ACTIVE_WORKERS="$TOTAL_LEVELS"
else
  ACTIVE_WORKERS="$WORKERS"
fi

mkdir -p "$OUTPUT_ROOT/logs" "$OUTPUT_ROOT/status" "$OUTPUT_ROOT/workers" "$SHIP_DIR"

if ! command -v dotnet >/dev/null 2>&1; then
  echo "[shape-first] dotnet is required." >&2
  exit 127
fi

cat >"$OUTPUT_ROOT/run.env" <<EOF
JOB=$JOB
OUTPUT_ROOT=$OUTPUT_ROOT
LEVEL_START=$LEVEL_START
LEVEL_END=$LEVEL_END
WORKERS=$WORKERS
ACTIVE_WORKERS=$ACTIVE_WORKERS
LEVEL_SEED_BASE=$LEVEL_SEED_BASE
LAYOUT_CANDIDATES=$LAYOUT_CANDIDATES
SOLUTION_TICKS=$SOLUTION_TICKS
SOURCE_RATE=$SOURCE_RATE
MAX_SWAP_QUANTITY_PER_EDGE=$MAX_SWAP_QUANTITY_PER_EDGE
WIN_DURATION_TICKS=$WIN_DURATION_TICKS
REQUIRED_ALIVE_TICKS_AT_END=$REQUIRED_ALIVE_TICKS_AT_END
SHAPE_FIRST_SUSTAINED_TICKS=$SHAPE_FIRST_SUSTAINED_TICKS
EVENT_CAPACITY=$EVENT_CAPACITY
CONFIGURATION=$CONFIGURATION
HEARTBEAT_SECONDS=$HEARTBEAT_SECONDS
PROGRESS_STRIDE=$PROGRESS_STRIDE
SHIP_DIR=$SHIP_DIR
SKIP_RESTORE_BUILD=$SKIP_RESTORE_BUILD
EOF

echo "[shape-first] job=$JOB"
echo "[shape-first] output_root=$OUTPUT_ROOT"
echo "[shape-first] workers=$ACTIVE_WORKERS requested_workers=$WORKERS levels=$LEVEL_START..$LEVEL_END"
echo "[shape-first] layout_candidates=$LAYOUT_CANDIDATES solution_ticks=$SOLUTION_TICKS"
echo "[shape-first] source_rate=$SOURCE_RATE max_swap_quantity_per_edge=$MAX_SWAP_QUANTITY_PER_EDGE"
echo "[shape-first] win_duration_ticks=$WIN_DURATION_TICKS required_alive_at_end=$REQUIRED_ALIVE_TICKS_AT_END shape_first_sustained_ticks=$SHAPE_FIRST_SUSTAINED_TICKS"
echo "[shape-first] event_capacity=$EVENT_CAPACITY progress_stride=$PROGRESS_STRIDE"
echo "[shape-first] ship_dir=$SHIP_DIR"
echo "[shape-first] skip_restore_build=$SKIP_RESTORE_BUILD"

if [[ "$SKIP_RESTORE_BUILD" != "1" ]]; then
  echo "[shape-first] restoring and building $CONFIGURATION"
  dotnet restore sim/CellularSim.sln
  dotnet build --no-restore -c "$CONFIGURATION" sim/CellularSim.Examples/CellularSim.Examples.csproj
else
  echo "[shape-first] skipping restore/build; using existing $CONFIGURATION binaries"
fi

running_jobs() {
  jobs -rp | wc -l
}

read_status_value() {
  local status_file="$1"
  if [[ ! -f "$status_file" ]]; then
    echo "pending"
    return
  fi

  awk -F= '$1 == "status" { print $2; found=1; exit } END { if (!found) print "unknown" }' "$status_file"
}

count_summary_status() {
  local status_name="$1"
  shopt -s nullglob
  local summaries=("$OUTPUT_ROOT"/workers/worker-*/summary.csv)
  shopt -u nullglob
  if (( ${#summaries[@]} == 0 )); then
    echo 0
    return
  fi

  awk -F, -v status_name="$status_name" '
    NR > 1 && $2 == status_name { count += 1 }
    END { print count + 0 }
  ' "${summaries[@]}"
}

LAST_PROGRESS_AT=0

print_progress() {
  local passed
  local failed
  passed="$(count_summary_status passed)"
  failed="$(count_summary_status failed)"
  local finished=$((passed + failed))
  local pending=$((TOTAL_LEVELS - finished))
  if (( pending < 0 )); then
    pending=0
  fi

  local running=0
  local unknown=0
  for worker in $(seq 1 "$ACTIVE_WORKERS"); do
    local worker_id
    printf -v worker_id "worker-%02d" "$worker"
    local status_value
    status_value="$(read_status_value "$OUTPUT_ROOT/status/$worker_id.status")"
    case "$status_value" in
      running)
        running=$((running + 1))
        ;;
      complete|failed|pending)
        ;;
      *)
        unknown=$((unknown + 1))
        ;;
    esac
  done

  local percent
  percent="$(awk "BEGIN { printf \"%.1f\", ($finished * 100.0) / $TOTAL_LEVELS }")"
  echo "[shape-first] progress $(date -Is) finished=$finished/$TOTAL_LEVELS (${percent}%) passed=$passed failed=$failed pending=$pending running_workers=$running active_jobs=$(running_jobs) unknown_workers=$unknown"
  echo "[shape-first] logs=$OUTPUT_ROOT/logs summary=$OUTPUT_ROOT/summary.csv"
}

maybe_print_progress() {
  local now
  now="$(date +%s)"
  if (( now - LAST_PROGRESS_AT >= HEARTBEAT_SECONDS )); then
    print_progress
    LAST_PROGRESS_AT="$now"
  fi
}

run_worker() {
  local worker_index="$1"
  local range_start="$2"
  local range_end="$3"
  local worker_id
  printf -v worker_id "worker-%02d" "$worker_index"
  local out_dir="$OUTPUT_ROOT/workers/$worker_id"
  local log_file="$OUTPUT_ROOT/logs/$worker_id.log"
  local status_file="$OUTPUT_ROOT/status/$worker_id.status"

  mkdir -p "$out_dir"
  {
    echo "status=running"
    echo "worker=$worker_id"
    echo "from_level=$range_start"
    echo "to_level=$range_end"
    echo "output=$out_dir"
    echo "log=$log_file"
    echo "started_at=$(date -Is)"
  } >"$status_file"

  local rc=0
  {
    echo "[$worker_id] start $(date -Is)"
    echo "[$worker_id] levels=$range_start..$range_end out_dir=$out_dir"
    dotnet run --no-restore --no-build -c "$CONFIGURATION" --project sim/CellularSim.Examples -- \
      --generate-puzzle-level \
      --generation-strategy shape-first-exact \
      --from-level "$range_start" \
      --to-level "$range_end" \
      --level-seed-base "$LEVEL_SEED_BASE" \
      --layout-candidates "$LAYOUT_CANDIDATES" \
      --solution-ticks "$SOLUTION_TICKS" \
      --source-rate "$SOURCE_RATE" \
      --max-swap-quantity-per-edge "$MAX_SWAP_QUANTITY_PER_EDGE" \
      --win-duration-ticks "$WIN_DURATION_TICKS" \
      --required-alive-ticks-at-end "$REQUIRED_ALIVE_TICKS_AT_END" \
      --shape-first-sustained-ticks "$SHAPE_FIRST_SUSTAINED_TICKS" \
      --event-capacity "$EVENT_CAPACITY" \
      --progress-stride "$PROGRESS_STRIDE" \
      --ship-dir "$SHIP_DIR" \
      --save-dir "$out_dir" || rc=$?
    echo "[$worker_id] finish rc=$rc $(date -Is)"
  } >"$log_file" 2>&1

  {
    if (( rc == 0 )); then
      echo "status=complete"
    else
      echo "status=failed"
    fi
    echo "worker=$worker_id"
    echo "from_level=$range_start"
    echo "to_level=$range_end"
    echo "output=$out_dir"
    echo "log=$log_file"
    echo "finished_at=$(date -Is)"
  } >"$status_file"

  return "$rc"
}

pids=()
cursor="$LEVEL_START"
base_count=$((TOTAL_LEVELS / ACTIVE_WORKERS))
remainder=$((TOTAL_LEVELS % ACTIVE_WORKERS))

for worker in $(seq 1 "$ACTIVE_WORKERS"); do
  count="$base_count"
  if (( worker <= remainder )); then
    count=$((count + 1))
  fi

  range_start="$cursor"
  range_end=$((cursor + count - 1))
  cursor=$((range_end + 1))

  run_worker "$worker" "$range_start" "$range_end" &
  pids+=("$!")
  maybe_print_progress
done

print_progress
while [[ "$(running_jobs)" -gt 0 ]]; do
  sleep "$HEARTBEAT_SECONDS"
  print_progress
done

status=0
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then
    status=1
  fi
done

bash scripts/collect_shape_first_exact_batch.sh "$OUTPUT_ROOT"
print_progress

echo "[shape-first] done status=$status"
echo "[shape-first] summary=$OUTPUT_ROOT/summary.csv"
echo "[shape-first] worker_outputs=$OUTPUT_ROOT/workers"
echo "[shape-first] shipped_levels=$SHIP_DIR"
exit "$status"
