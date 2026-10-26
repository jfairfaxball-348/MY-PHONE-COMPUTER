#!/data/data/com.termux/files/usr/bin/bash
# Newton v0.3 read-only status probe. One token of stdout for the Android app.
set -u
if command -v pgrep >/dev/null 2>&1; then
    if pgrep -f 'newton-vad-turn[.]sh' >/dev/null 2>&1; then
        echo PROCESSING
        exit 0
    fi
    if pgrep -f 'newton-wake-v02c[.]sh|newton-wake-v02[.]sh|newton-wake[.]sh' >/dev/null 2>&1; then
        echo LISTENING
        exit 0
    fi
fi
if command -v curl >/dev/null 2>&1 &&
   curl --silent --fail --max-time 1 http://127.0.0.1:8080/health >/dev/null 2>&1; then
    echo SERVER_ONLY
else
    echo STOPPED
fi
