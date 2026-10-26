#!/data/data/com.termux/files/usr/bin/bash
# v0.3.1 guarded launcher. The working widget starter remains unchanged.
set -euo pipefail
D="$HOME/newton/app"
[[ -f "$D/start.sh" ]] || { echo 'Missing original start.sh' >&2; exit 1; }
if [[ -f "$D/.native-stopping" ]]; then
    echo 'Stop is in progress; start again once Stopped.' >&2; exit 1
fi
LOCK="$D/.native-launch.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
    echo 'Newton start already in progress.'; exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null || true; rm -f "$D/.native-start-pending"' EXIT
touch "$D/.native-start-pending"
if command -v pgrep >/dev/null 2>&1 && pgrep -f 'newton-(wake(-v02c|-v02)?|vad-turn)[.]sh' >/dev/null 2>&1; then
    echo 'Newton listener already active.'; exit 0
fi
if command -v curl >/dev/null 2>&1 && curl -fsS --max-time 1 http://127.0.0.1:8080/health >/dev/null 2>&1; then
    echo 'Newton server already active. Stop before restarting.'; exit 0
fi
mkdir -p "$D/logs"
bash "$D/start.sh" >> "$D/logs/native-launch.log" 2>&1
