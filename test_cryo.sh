#!/usr/bin/env bash
# Standalone test suite for cryo — no bats dependency, no job-control hangs.
set -euo pipefail

CRYO="$(dirname "$0")/cryo"
PASS=0; FAIL=0; ERRORS=()

cleanup() {
  pkill -f "cryo --dry-run --interval" 2>/dev/null || true
  pkill -f "eslint\.js\."               2>/dev/null || true
  pkill -f "shell-snapshots/snapshot-"  2>/dev/null || true
  rm -f /tmp/cryo.pid
}

run_test() {
  local name="$1"; shift
  rm -f /tmp/cryo.pid
  cleanup
  if "$@"; then
    echo "ok - $name"
    PASS=$(( PASS + 1 ))
  else
    echo "not ok - $name"
    ERRORS+=("$name")
    FAIL=$(( FAIL + 1 ))
  fi
}

# ── helpers ──────────────────────────────────────────────────────────────────

output_of() { "$CRYO" "$@" 2>&1; }

contains()    { [[ "$1" == *"$2"* ]]; }
not_contains(){ [[ "$1" != *"$2"* ]]; }
strip_ansi()  { printf '%s' "$1" | sed 's/\x1b\[[0-9;]*m//g'; }

setup_fake_eslint() {
  local f="$1"
  printf '#!/usr/bin/env bash\ntrap "exit 0" TERM INT\nsleep 999 & wait $!\n' > "$f"
  chmod +x "$f"
}

setup_fake_snapshot() {
  local f="$1"
  printf '#!/usr/bin/env bash\ntrap "exit 0" TERM INT\nsleep 999 & wait $!\n' > "$f"
  chmod +x "$f"
}

# ── tests ─────────────────────────────────────────────────────────────────────

t_once_exits() {
  local out; out=$(output_of --once --dry-run)
  contains "$out" "cryo"
}

t_dryrun_badge() {
  local out; out=$(output_of --dry-run --once)
  contains "$out" "DRY RUN"
}

t_ansi_codes() {
  local out; out=$("$CRYO" --threshold 0 --dry-run --once 2>&1)
  [[ "$out" == *$'\033['* ]]
}

t_help() {
  local out; out=$(output_of --help)
  contains "$out" "Usage: cryo"
}

t_unknown_flag() {
  local status=0
  "$CRYO" --bogus 2>&1 || status=$?
  [[ $status -ne 0 ]]
}

t_second_instance() {
  "$CRYO" --dry-run --interval 999 &
  local bg=$!
  sleep 0.5
  local out status=0
  out=$("$CRYO" --dry-run --once 2>&1) || status=$?
  kill "$bg" 2>/dev/null; wait "$bg" 2>/dev/null || true
  contains "$out" "already running" && [[ $status -ne 0 ]]
}

t_pidfile_cleaned() {
  "$CRYO" --dry-run --once >/dev/null 2>&1
  [[ ! -f /tmp/cryo.pid ]]
}

t_threshold_999_nothing() {
  local out; out=$(output_of --threshold 999 --dry-run --once)
  contains "$out" "nothing to renice"
}

t_threshold_0_renices() {
  local out; out=$(output_of --threshold 0 --dry-run --once)
  contains "$out" "processes would throttle"
}

t_top_1() {
  local out; out=$(output_of --top 1 --threshold 0 --dry-run --once)
  local clean; clean=$(strip_ansi "$out")
  local n; n=$(printf '%s' "$clean" | grep -cE '^  [●▲○]' || true)
  [[ $n -eq 1 ]]
}

t_denylist() {
  local out; out=$(output_of --threshold 0 --dry-run --once)
  not_contains "$out" "WindowServer" && not_contains "$out" "kernel_task"
}

t_mem_threshold_0() {
  local out; out=$(output_of --threshold 999 --mem-threshold 0 --dry-run --once)
  contains "$out" "MEM%"
}

t_mem_threshold_999_nothing() {
  local out; out=$(output_of --threshold 999 --mem-threshold 999 --dry-run --once)
  contains "$out" "nothing to renice"
}

t_mem_column() {
  local out; out=$(output_of --threshold 999 --mem-threshold 0 --top 1 --dry-run --once)
  contains "$out" "MEM%"
}

t_missing_interval_arg() {
  local status=0
  "$CRYO" --interval 2>&1 || status=$?
  [[ $status -ne 0 ]]
}

t_nonnumeric_threshold() {
  local status=0
  "$CRYO" --threshold abc --dry-run --once 2>&1 || status=$?
  [[ $status -ne 0 ]]
}

t_dryrun_footer() {
  local out; out=$(output_of --threshold 0 --dry-run --once)
  not_contains "$out" "pids throttled" && contains "$out" "would throttle"
}

t_top_2() {
  local out; out=$(output_of --threshold 0 --top 2 --dry-run --once)
  local clean; clean=$(strip_ansi "$out")
  local n; n=$(printf '%s' "$clean" | grep -cE '^  [●▲○]' || true)
  [[ $n -eq 2 ]]
}

t_eslint_dryrun_stale() {
  local fake; fake=$(mktemp /tmp/eslint.js.XXXX)
  setup_fake_eslint "$fake"
  "$fake" --fix &
  local epid=$!
  sleep 0.2
  local out; out=$(output_of --dry-run --once --eslint-max-age 0)
  kill "$epid" 2>/dev/null; wait "$epid" 2>/dev/null || true
  rm -f "$fake"
  contains "$out" "would kill eslint"
}

t_eslint_dryrun_fresh() {
  local fake; fake=$(mktemp /tmp/eslint.js.XXXX)
  setup_fake_eslint "$fake"
  "$fake" --fix &
  local epid=$!
  sleep 0.2
  local out; out=$(output_of --dry-run --once --eslint-max-age 9999)
  kill "$epid" 2>/dev/null; wait "$epid" 2>/dev/null || true
  rm -f "$fake"
  not_contains "$out" "would kill eslint pid $epid"
}

t_eslint_kills() {
  local fake; fake=$(mktemp /tmp/eslint.js.XXXX)
  setup_fake_eslint "$fake"
  "$fake" --fix &
  local epid=$!
  sleep 0.2
  output_of --once --threshold 999 --mem-threshold 999 --eslint-max-age 0 >/dev/null
  wait "$epid" 2>/dev/null || true
  rm -f "$fake"
  ! kill -0 "$epid" 2>/dev/null
}

t_eslint_kill_count() {
  local fake; fake=$(mktemp /tmp/eslint.js.XXXX)
  setup_fake_eslint "$fake"
  "$fake" --fix &
  local epid=$!
  sleep 0.2
  local out; out=$(output_of --once --threshold 999 --mem-threshold 999 --eslint-max-age 0)
  wait "$epid" 2>/dev/null || true
  rm -f "$fake"
  contains "$out" "killed" && contains "$out" "eslint worker"
}

t_snapshot_dryrun_stale() {
  local dir; dir=$(mktemp -d /tmp/cryo-test.XXXX)
  mkdir -p "$dir/shell-snapshots"
  local fake="$dir/shell-snapshots/snapshot-zsh-fake"
  setup_fake_snapshot "$fake"
  "$fake" &
  local spid=$!
  sleep 0.2
  local out; out=$(output_of --dry-run --once --claude-snapshot-max-age 0)
  kill "$spid" 2>/dev/null; wait "$spid" 2>/dev/null || true
  rm -rf "$dir"
  contains "$out" "would kill claude-snapshot"
}

t_snapshot_dryrun_fresh() {
  local dir; dir=$(mktemp -d /tmp/cryo-test.XXXX)
  mkdir -p "$dir/shell-snapshots"
  local fake="$dir/shell-snapshots/snapshot-zsh-fake"
  setup_fake_snapshot "$fake"
  "$fake" &
  local spid=$!
  sleep 0.2
  local out; out=$(output_of --dry-run --once --claude-snapshot-max-age 9999)
  kill "$spid" 2>/dev/null; wait "$spid" 2>/dev/null || true
  rm -rf "$dir"
  not_contains "$out" "would kill claude-snapshot pid $spid"
}

t_snapshot_kills() {
  local dir; dir=$(mktemp -d /tmp/cryo-test.XXXX)
  mkdir -p "$dir/shell-snapshots"
  local fake="$dir/shell-snapshots/snapshot-zsh-fake"
  setup_fake_snapshot "$fake"
  "$fake" &
  local spid=$!
  sleep 0.2
  output_of --once --threshold 999 --mem-threshold 999 --claude-snapshot-max-age 0 >/dev/null
  wait "$spid" 2>/dev/null || true
  rm -rf "$dir"
  ! kill -0 "$spid" 2>/dev/null
}

t_snapshot_kill_count() {
  local dir; dir=$(mktemp -d /tmp/cryo-test.XXXX)
  mkdir -p "$dir/shell-snapshots"
  local fake="$dir/shell-snapshots/snapshot-zsh-fake"
  setup_fake_snapshot "$fake"
  "$fake" &
  local spid=$!
  sleep 0.2
  local out; out=$(output_of --once --threshold 999 --mem-threshold 999 --claude-snapshot-max-age 0)
  wait "$spid" 2>/dev/null || true
  rm -rf "$dir"
  contains "$out" "killed" && contains "$out" "claude-snapshot worker"
}

t_snapshot_flag_accepted() {
  local status=0
  output_of --dry-run --once --claude-snapshot-max-age 300 >/dev/null || status=$?
  [[ $status -eq 0 ]]
}

# ── run all ───────────────────────────────────────────────────────────────────

TESTS=(
  t_once_exits
  t_dryrun_badge
  t_ansi_codes
  t_help
  t_unknown_flag
  t_second_instance
  t_pidfile_cleaned
  t_threshold_999_nothing
  t_threshold_0_renices
  t_top_1
  t_denylist
  t_mem_threshold_0
  t_mem_threshold_999_nothing
  t_mem_column
  t_missing_interval_arg
  t_nonnumeric_threshold
  t_dryrun_footer
  t_top_2
  t_eslint_dryrun_stale
  t_eslint_dryrun_fresh
  t_eslint_kills
  t_eslint_kill_count
  t_snapshot_dryrun_stale
  t_snapshot_dryrun_fresh
  t_snapshot_kills
  t_snapshot_kill_count
  t_snapshot_flag_accepted
)

echo "1..${#TESTS[@]}"
for t in "${TESTS[@]}"; do
  NAME="${t//_/ }"
  run_test "$NAME" "$t"
done

cleanup

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  echo "Failed:"
  for e in "${ERRORS[@]}"; do echo "  - $e"; done
  exit 1
fi
