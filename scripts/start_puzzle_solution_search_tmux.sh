#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

JOB="${1:-solution-search-001-022}"
SESSION="${SESSION:-cellular-solution-search}"
OUTPUT_ROOT="${OUTPUT_ROOT:-sim/batches/$JOB}"
LOG_FILE="${LOG_FILE:-$OUTPUT_ROOT/$JOB.log}"

mkdir -p "$OUTPUT_ROOT"

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux is required to start detached batch jobs." >&2
  exit 127
fi

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "tmux session already exists: $SESSION" >&2
  echo "Attach: tmux attach -t $SESSION" >&2
  echo "Tail: tail -f $LOG_FILE" >&2
  exit 2
fi

FORWARDED_ENV_KEYS=(
  OUTPUT_ROOT
  LEVEL_START
  LEVEL_END
  LEVELS_DIR
  WORKERS
  SOLUTION_TICKS
  CANDIDATE_LIMIT
  BEAM_SIZE
  SOURCE_RATE
  EVENT_CAPACITY
  CONFIGURATION
  HEARTBEAT_SECONDS
  PROGRESS_STRIDE
  SKIP_RESTORE_BUILD
)

ENV_PREFIX=""
for key in "${FORWARDED_ENV_KEYS[@]}"; do
  if [[ -v "$key" ]]; then
    printf -v quoted_env "%q" "$key=${!key}"
    ENV_PREFIX+=" $quoted_env"
  fi
done

printf -v quoted_pwd "%q" "$PWD"
printf -v quoted_job "%q" "$JOB"
printf -v quoted_log "%q" "$LOG_FILE"
COMMAND="set -o pipefail; cd $quoted_pwd && env$ENV_PREFIX bash scripts/run_puzzle_solution_search_batch.sh $quoted_job 2>&1 | tee $quoted_log"
printf -v quoted_command "%q" "$COMMAND"
tmux new-session -d -s "$SESSION" "bash -lc $quoted_command"

echo "Started detached tmux session: $SESSION"
echo "Job: $JOB"
echo "Output: $OUTPUT_ROOT"
echo "Log: $LOG_FILE"
echo "Workers: ${WORKERS:-15}"
echo "Tail: tail -f $LOG_FILE"
echo "Attach: tmux attach -t $SESSION"
