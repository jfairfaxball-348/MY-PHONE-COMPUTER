#!/data/data/com.termux/files/usr/bin/bash
# Newton v0.3 wrapper; original widget scripts are unmodified.
set -euo pipefail
D="$HOME/newton/app"
[[ -f "$D/start.sh" ]] || { echo 'Missing original start.sh' >&2; exit 1; }
LOCK="$D/.native-launch.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
    echo 'A native launch is already in progress.'
    exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT
# Avoid launching a second listener/server or adding to a partially started instance.
if command -v pgrep >/dev/null 2>&1 &&
   pgrep -f 'newton-wake-v02c[.]sh|newton-wake-v02[.]sh|newton-wake[.]sh|newton-vad-turn[.]sh' >/dev/null 2>&1; then
    echo 'Newton listener already active.'
    exit 0
fi
if command -v curl >/dev/null 2>&1 &&
   curl --silent --fail --max-time 1 http://127.0.0.1:8080/health >/dev/null 2>&1; then
    echo 'Newton server already active. Stop before restarting.'
    exit 0
fi
mkdir -p "$D/logs"
bash "$D/start.sh" >> "$D/logs/native-launch.log" 2>&1
