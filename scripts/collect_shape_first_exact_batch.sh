#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

BATCH_ROOT="${1:-sim/batches/shape-first-021-200}"
SUMMARY_PATH="${SUMMARY_PATH:-$BATCH_ROOT/summary.csv}"

mkdir -p "$(dirname "$SUMMARY_PATH")"

shopt -s nullglob
summaries=("$BATCH_ROOT"/workers/worker-*/summary.csv)
shopt -u nullglob

tmp_summary="$SUMMARY_PATH.tmp"
header=""
found=0

for summary in "${summaries[@]}"; do
  if [[ ! -s "$summary" ]]; then
    continue
  fi

  if [[ -z "$header" ]]; then
    header="$(head -n 1 "$summary")"
    printf '%s\n' "$header" >"$tmp_summary"
  fi

  tail -n +2 "$summary" >>"$tmp_summary"
  found=1
done

if (( found == 0 )); then
  printf '%s\n' "level,status,static_proof,sim_win,stable_at_end,sustained_ticks,total_swaps,total_reactions,flow,repair_edits,producer_edits,failure_category,generated_dir,shipped" >"$tmp_summary"
fi

mv "$tmp_summary" "$SUMMARY_PATH"

awk -F, '
  NR > 1 {
    total += 1
    if ($2 == "passed") {
      passed += 1
    } else {
      failed += 1
    }
  }
  END {
    printf("[shape-first] summary=%s total=%d passed=%d failed=%d\n", summary, total, passed, failed)
  }
' summary="$SUMMARY_PATH" "$SUMMARY_PATH"
