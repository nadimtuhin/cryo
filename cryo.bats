#!/usr/bin/env bats

CRYO="$(dirname "$BATS_TEST_FILENAME")/cryo"

setup() {
  rm -f /tmp/cryo.pid
}

teardown() {
  rm -f /tmp/cryo.pid
  # Aggressively clean up any leaked background processes
  pkill -f "cryo --dry-run --interval 999" 2>/dev/null || true
  pkill -f "eslint\.js\." 2>/dev/null || true
  pkill -f "shell-snapshots/snapshot-" 2>/dev/null || true
  # Give child sleeps a moment to die after their parents are killed
  sleep 0.1 || true
}

@test "--once exits after one pass" {
  run "$CRYO" --once --dry-run
  [ "$status" -eq 0 ]
}

@test "--dry-run shows [DRY RUN] badge" {
  run "$CRYO" --dry-run --once
  [[ "$output" == *"DRY RUN"* ]]
}

@test "output contains ANSI color codes" {
  run "$CRYO" --threshold 0 --dry-run --once
  [[ "$output" == *$'\033['* ]]
  [ "$status" -eq 0 ]
}

@test "--help prints usage" {
  run "$CRYO" --help
  [[ "$output" == *"Usage: cryo"* ]]
}

@test "unknown flag prints error and exits non-zero" {
  run "$CRYO" --bogus
  [ "$status" -ne 0 ]
}

@test "second instance blocked by pidfile guard" {
  "$CRYO" --dry-run --interval 999 &
  BG_PID=$!
  disown "$BG_PID" 2>/dev/null || true
  sleep 0.5
  run "$CRYO" --dry-run --once
  kill "$BG_PID" 2>/dev/null
  wait "$BG_PID" 2>/dev/null || true
  [[ "$output" == *"already running"* ]]
  [ "$status" -ne 0 ]
}

@test "pidfile cleaned up after --once" {
  run "$CRYO" --dry-run --once
  [ ! -f /tmp/cryo.pid ]
}

# --- statistical detection tests ---

@test "--threshold 999 shows nothing to renice" {
  run "$CRYO" --threshold 999 --dry-run --once
  [[ "$output" == *"nothing to renice"* ]]
}

@test "--threshold 0 renices at least one process" {
  run "$CRYO" --threshold 0 --dry-run --once
  [[ "$output" == *"processes would throttle"* ]]
}

@test "--top 1 limits output to one process" {
  run "$CRYO" --top 1 --threshold 0 --dry-run --once
  local row_count
  row_count=$(printf '%s' "$output" | sed 's/\x1b\[[0-9;]*m//g' | grep -cE '^  [●▲○]' || true)
  [ "$row_count" -eq 1 ]
}

@test "denylist processes never appear in output" {
  run "$CRYO" --threshold 0 --dry-run --once
  [[ "$output" != *"WindowServer"* ]]
  [[ "$output" != *"kernel_task"* ]]
}

# --- memory hog tests ---

@test "--mem-threshold 0 lists memory hogs" {
  run "$CRYO" --threshold 999 --mem-threshold 0 --dry-run --once
  [[ "$output" == *"MEM%"* ]]
  [[ "$output" == *"% mem"* ]] || [[ "$output" == *"MEM%"* ]]
}

@test "--mem-threshold 999 --threshold 999 shows nothing to renice" {
  run "$CRYO" --threshold 999 --mem-threshold 999 --dry-run --once
  [[ "$output" == *"nothing to renice"* ]]
}

@test "memory hog output shows MEM% column" {
  run "$CRYO" --threshold 999 --mem-threshold 0 --top 1 --dry-run --once
  [[ "$output" == *"MEM%"* ]]
}

# --- bug-fix tests ---

@test "missing arg to --interval exits non-zero with error" {
  run "$CRYO" --interval
  [ "$status" -ne 0 ]
  [[ "$output" == *"requires"* ]] || [[ "$output" == *"missing"* ]] || [[ "$output" == *"interval"* ]]
}

@test "non-numeric --threshold exits non-zero" {
  run "$CRYO" --threshold abc --dry-run --once
  [ "$status" -ne 0 ]
}

@test "dry-run footer says would throttle not throttled" {
  run "$CRYO" --threshold 0 --dry-run --once
  [[ "$output" != *"pids throttled"* ]]
  [[ "$output" == *"would throttle"* ]]
}

@test "--top 2 returns exactly 2 highest CPU hogs" {
  run "$CRYO" --threshold 0 --top 2 --dry-run --once
  local dry_count
  dry_count=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g' | grep -cE '^  [●▲○]' || true)
  [ "$dry_count" -eq 2 ]
}

# --- kill_orphan_eslints tests ---

setup_fake_eslint() {
  local script="$1"
  cat > "$script" << 'EOF'
#!/usr/bin/env bash
trap 'exit 0' TERM INT
sleep 999 &
wait $!
EOF
  chmod +x "$script"
}

@test "dry-run reports stale eslint worker (--eslint-max-age 0)" {
  local fake; fake=$(mktemp /tmp/eslint.js.XXXX)
  setup_fake_eslint "$fake"
  "$fake" --fix &
  local epid=$!
  sleep 0.2
  run "$CRYO" --dry-run --once --eslint-max-age 0
  kill "$epid" 2>/dev/null; wait "$epid" 2>/dev/null || true
  rm -f "$fake"
  [[ "$output" == *"would kill eslint"* ]]
}

@test "dry-run does NOT report fresh eslint under max-age" {
  local fake; fake=$(mktemp /tmp/eslint.js.XXXX)
  setup_fake_eslint "$fake"
  "$fake" --fix &
  local epid=$!
  sleep 0.2
  run "$CRYO" --dry-run --once --eslint-max-age 9999
  kill "$epid" 2>/dev/null; wait "$epid" 2>/dev/null || true
  rm -f "$fake"
  [[ "$output" != *"would kill eslint pid $epid"* ]]
}

@test "non-dry-run kills stale eslint (--eslint-max-age 0)" {
  local fake; fake=$(mktemp /tmp/eslint.js.XXXX)
  setup_fake_eslint "$fake"
  "$fake" --fix &
  local epid=$!
  sleep 0.2
  run "$CRYO" --once --threshold 999 --mem-threshold 999 --eslint-max-age 0
  wait "$epid" 2>/dev/null || true
  rm -f "$fake"
  ! kill -0 "$epid" 2>/dev/null
}

@test "killed eslint count reported in output" {
  local fake; fake=$(mktemp /tmp/eslint.js.XXXX)
  setup_fake_eslint "$fake"
  "$fake" --fix &
  local epid=$!
  sleep 0.2
  run "$CRYO" --once --threshold 999 --mem-threshold 999 --eslint-max-age 0
  wait "$epid" 2>/dev/null || true
  rm -f "$fake"
  [[ "$output" == *"killed"*"eslint worker"* ]]
}

# --- claude-snapshot tests ---

setup_fake_snapshot() {
  local script="$1"
  cat > "$script" << 'EOF'
#!/usr/bin/env bash
trap 'exit 0' TERM INT
sleep 999 &
wait $!
EOF
  chmod +x "$script"
}

@test "dry-run reports stale claude-snapshot (--claude-snapshot-max-age 0)" {
  local dir; dir=$(mktemp -d /tmp/cryo-test.XXXX)
  mkdir -p "$dir/shell-snapshots"
  local fake="$dir/shell-snapshots/snapshot-zsh-fake"
  setup_fake_snapshot "$fake"
  "$fake" &
  local spid=$!
  sleep 0.2
  run "$CRYO" --dry-run --once --claude-snapshot-max-age 0
  kill "$spid" 2>/dev/null; wait "$spid" 2>/dev/null || true
  rm -rf "$dir"
  [[ "$output" == *"would kill claude-snapshot"* ]]
}

@test "dry-run does NOT report fresh snapshot under max-age" {
  local dir; dir=$(mktemp -d /tmp/cryo-test.XXXX)
  mkdir -p "$dir/shell-snapshots"
  local fake="$dir/shell-snapshots/snapshot-zsh-fake"
  setup_fake_snapshot "$fake"
  "$fake" &
  local spid=$!
  sleep 0.2
  run "$CRYO" --dry-run --once --claude-snapshot-max-age 9999
  kill "$spid" 2>/dev/null; wait "$spid" 2>/dev/null || true
  rm -rf "$dir"
  [[ "$output" != *"would kill claude-snapshot pid $spid"* ]]
}

@test "non-dry-run kills stale claude-snapshot (--claude-snapshot-max-age 0)" {
  local dir; dir=$(mktemp -d /tmp/cryo-test.XXXX)
  mkdir -p "$dir/shell-snapshots"
  local fake="$dir/shell-snapshots/snapshot-zsh-fake"
  setup_fake_snapshot "$fake"
  "$fake" &
  local spid=$!
  sleep 0.2
  run "$CRYO" --once --threshold 999 --mem-threshold 999 --claude-snapshot-max-age 0
  wait "$spid" 2>/dev/null || true
  rm -rf "$dir"
  ! kill -0 "$spid" 2>/dev/null
}

@test "killed claude-snapshot count reported in output" {
  local dir; dir=$(mktemp -d /tmp/cryo-test.XXXX)
  mkdir -p "$dir/shell-snapshots"
  local fake="$dir/shell-snapshots/snapshot-zsh-fake"
  setup_fake_snapshot "$fake"
  "$fake" &
  local spid=$!
  sleep 0.2
  run "$CRYO" --once --threshold 999 --mem-threshold 999 --claude-snapshot-max-age 0
  wait "$spid" 2>/dev/null || true
  rm -rf "$dir"
  [[ "$output" == *"killed"*"claude-snapshot worker"* ]]
}

@test "--claude-snapshot-max-age flag accepted without error" {
  run "$CRYO" --dry-run --once --claude-snapshot-max-age 300
  [ "$status" -eq 0 ]
}
