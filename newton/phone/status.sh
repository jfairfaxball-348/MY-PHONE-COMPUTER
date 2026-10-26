#!/data/data/com.termux/files/usr/bin/bash
# Newton v0.3.1 read-only status probe.
set -u
D="$HOME/newton/app"
if [[ -f "$D/.native-stopping" ]]; then echo STOPPING; exit 0; fi
if command -v pgrep >/dev/null 2>&1; then
    if pgrep -f 'newton-vad-turn[.]sh' >/dev/null 2>&1; then echo PROCESSING; exit 0; fi
    if pgrep -f 'newton-wake(-v02c|-v02)?[.]sh' >/dev/null 2>&1; then echo LISTENING; exit 0; fi
fi
if command -v curl >/dev/null 2>&1 && curl -fsS --max-time 1 http://127.0.0.1:8080/health >/dev/null 2>&1; then
    echo SERVER_ONLY
elif [[ -f "$D/.native-start-pending" ]]; then
    echo STARTING
else
    echo STOPPED
fi
