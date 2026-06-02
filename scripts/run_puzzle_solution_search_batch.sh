#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

JOB="${1:-solution-search-001-022}"
OUTPUT_ROOT="${OUTPUT_ROOT:-sim/batches/$JOB}"
LEVEL_START="${LEVEL_START:-1}"
LEVEL_END="${LEVEL_END:-22}"
LEVELS_DIR="${LEVELS_DIR:-levels/puzzle}"
WORKERS="${WORKERS:-15}"
SOLUTION_TICKS="${SOLUTION_TICKS:-900}"
CANDIDATE_LIMIT="${CANDIDATE_LIMIT:-10000}"
BEAM_SIZE="${BEAM_SIZE:-512}"
SOURCE_RATE="${SOURCE_RATE:-}"
EVENT_CAPACITY="${EVENT_CAPACITY:-262144}"
CONFIGURATION="${CONFIGURATION:-Release}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-60}"
PROGRESS_STRIDE="${PROGRESS_STRIDE:-250}"
SKIP_RESTORE_BUILD="${SKIP_RESTORE_BUILD:-0}"

if (( LEVEL_END < LEVEL_START )); then
  echo "[batch] LEVEL_END must be greater than or equal to LEVEL_START." >&2
  exit 2
fi
TOTAL_LEVELS=$((LEVEL_END - LEVEL_START + 1))

mkdir -p "$OUTPUT_ROOT/logs" "$OUTPUT_ROOT/status" "$OUTPUT_ROOT/solution-runs"

if ! command -v dotnet >/dev/null 2>&1; then
  echo "[batch] dotnet is required." >&2
  exit 127
fi

cat > "$OUTPUT_ROOT/run.env" <<EOF
JOB=$JOB
OUTPUT_ROOT=$OUTPUT_ROOT
LEVEL_START=$LEVEL_START
LEVEL_END=$LEVEL_END
LEVELS_DIR=$LEVELS_DIR
WORKERS=$WORKERS
SOLUTION_TICKS=$SOLUTION_TICKS
CANDIDATE_LIMIT=$CANDIDATE_LIMIT
BEAM_SIZE=$BEAM_SIZE
SOURCE_RATE=$SOURCE_RATE
EVENT_CAPACITY=$EVENT_CAPACITY
CONFIGURATION=$CONFIGURATION
HEARTBEAT_SECONDS=$HEARTBEAT_SECONDS
PROGRESS_STRIDE=$PROGRESS_STRIDE
SKIP_RESTORE_BUILD=$SKIP_RESTORE_BUILD
EOF

echo "[batch] job=$JOB"
echo "[batch] output_root=$OUTPUT_ROOT"
echo "[batch] log_dir=$OUTPUT_ROOT/logs"
echo "[batch] status_dir=$OUTPUT_ROOT/status"
echo "[batch] levels=$LEVEL_START..$LEVEL_END workers=$WORKERS levels_dir=$LEVELS_DIR"
echo "[batch] solution_ticks=$SOLUTION_TICKS candidate_limit=$CANDIDATE_LIMIT beam_size=$BEAM_SIZE"
echo "[batch] event_capacity=$EVENT_CAPACITY progress_stride=$PROGRESS_STRIDE source_rate=${SOURCE_RATE:-fixture}"
echo "[batch] heartbeat_seconds=$HEARTBEAT_SECONDS"
echo "[batch] skip_restore_build=$SKIP_RESTORE_BUILD"

if [[ "$SKIP_RESTORE_BUILD" != "1" ]]; then
  echo "[batch] restoring and building $CONFIGURATION"
  dotnet restore sim/CellularSim.sln
  dotnet build --no-restore -c "$CONFIGURATION" sim/CellularSim.Examples/CellularSim.Examples.csproj
else
  echo "[batch] skipping restore/build; using existing $CONFIGURATION binaries"
fi

running_jobs() {
  jobs -rp | wc -l
}

LAST_PROGRESS_AT=0

read_status_value() {
  local status_file="$1"
  if [[ ! -f "$status_file" ]]; then
    echo "pending"
    return
  fi

  awk -F= '$1 == "status" { print $2; found=1; exit } END { if (!found) print "unknown" }' "$status_file"
}

print_progress() {
  local pass=0
  local fail=0
  local running=0
  local pending=0
  local unknown=0
  local completed_levels=""
  local failed_levels=""

  for level in $(seq "$LEVEL_START" "$LEVEL_END"); do
    local level_padded
    printf -v level_padded "%03d" "$level"
    local status_value
    status_value="$(read_status_value "$OUTPUT_ROOT/status/level-$level_padded.status")"
    case "$status_value" in
      pass)
        pass=$((pass + 1))
        completed_levels+="${completed_levels:+,}$level_padded"
        ;;
      fail)
        fail=$((fail + 1))
        failed_levels+="${failed_levels:+,}$level_padded"
        ;;
      running)
        running=$((running + 1))
        ;;
      pending)
        pending=$((pending + 1))
        ;;
      *)
        unknown=$((unknown + 1))
        ;;
    esac
  done

  local finished=$((pass + fail))
  local percent
  percent="$(awk "BEGIN { printf \"%.1f\", ($finished * 100.0) / $TOTAL_LEVELS }")"
  echo "[batch] progress $(date -Is) finished=$finished/$TOTAL_LEVELS (${percent}%) pass=$pass fail=$fail running=$running pending=$pending unknown=$unknown active_workers=$(running_jobs)"
  echo "[batch] log_dir=$OUTPUT_ROOT/logs summary=$OUTPUT_ROOT/summary.csv"
  if [[ -n "$completed_levels" ]]; then
    echo "[batch] completed_levels=$completed_levels"
  fi
  if [[ -n "$failed_levels" ]]; then
    echo "[batch] failed_levels=$failed_levels"
  fi
}

maybe_print_progress() {
  local now
  now="$(date +%s)"
  if (( now - LAST_PROGRESS_AT >= HEARTBEAT_SECONDS )); then
    print_progress
    LAST_PROGRESS_AT="$now"
  fi
}

wait_for_slot() {
  while [[ "$(running_jobs)" -ge "$WORKERS" ]]; do
    maybe_print_progress
    sleep 2
  done
}

run_level() {
  local level="$1"
  local level_padded
  printf -v level_padded "%03d" "$level"
  local out_dir="$OUTPUT_ROOT/solution-runs/level-$level_padded"
  local level_out_dir="$out_dir/level-$level_padded"
  local log_file="$OUTPUT_ROOT/logs/level-$level_padded.log"
  local status_file="$OUTPUT_ROOT/status/level-$level_padded.status"
  local source_rate_args=()

  if [[ -n "$SOURCE_RATE" ]]; then
    source_rate_args=(--source-rate "$SOURCE_RATE")
  fi

  mkdir -p "$out_dir"
  {
    echo "status=running"
    echo "level=$level"
    echo "output=$level_out_dir"
    echo "log=$log_file"
    echo "started_at=$(date -Is)"
  } >"$status_file"

  local rc=0
  {
    echo "[level-$level_padded] start $(date -Is)"
    echo "[level-$level_padded] out_dir=$out_dir"
    if dotnet run --no-restore --no-build -c "$CONFIGURATION" --project sim/CellularSim.Examples -- \
      --solve-puzzle-levels \
      --from-level "$level" \
      --to-level "$level" \
      --levels-dir "$LEVELS_DIR" \
      --solution-ticks "$SOLUTION_TICKS" \
      --candidate-limit "$CANDIDATE_LIMIT" \
      --beam-size "$BEAM_SIZE" \
      --event-capacity "$EVENT_CAPACITY" \
      --progress-stride "$PROGRESS_STRIDE" \
      "${source_rate_args[@]}" \
      --save-dir "$out_dir"; then
      echo "[level-$level_padded] complete $(date -Is)"
      rc=0
    else
      rc=$?
      echo "[level-$level_padded] failed rc=$rc $(date -Is)"
    fi
  } >"$log_file" 2>&1

  {
    if (( rc == 0 )); then
      echo "status=pass"
    else
      echo "status=fail"
    fi
    echo "level=$level"
    echo "output=$level_out_dir"
    echo "log=$log_file"
    echo "finished_at=$(date -Is)"
  } >"$status_file"

  return "$rc"
}

pids=()
for level in $(seq "$LEVEL_START" "$LEVEL_END"); do
  wait_for_slot
  run_level "$level" &
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

{
  echo "level,status,output,log"
  for level in $(seq "$LEVEL_START" "$LEVEL_END"); do
    printf -v level_padded "%03d" "$level"
    status_file="$OUTPUT_ROOT/status/level-$level_padded.status"
    if [[ -f "$status_file" ]]; then
      status_value="$(read_status_value "$status_file")"
      output="$(awk -F= '$1 == "output" { print $2 }' "$status_file")"
      log="$(awk -F= '$1 == "log" { print $2 }' "$status_file")"
      echo "$level,$status_value,$output,$log"
    else
      echo "$level,fail,,$OUTPUT_ROOT/logs/level-$level_padded.log"
    fi
  done
} > "$OUTPUT_ROOT/summary.csv"

print_progress
echo "[batch] done status=$status"
echo "[batch] summary=$OUTPUT_ROOT/summary.csv"
echo "[batch] solver_summaries=$OUTPUT_ROOT/solution-runs/*/summary.csv"
echo "[batch] logs=$OUTPUT_ROOT/logs"
exit "$status"
