#!/data/data/com.termux/files/usr/bin/bash
# v0.3.1 native stop wrapper. Original widget stop.sh stays intact.
set -u
D="$HOME/newton/app"
mkdir -p "$D/logs"
touch "$D/.native-stopping"
trap 'rm -f "$D/.native-stopping" "$D/.native-start-pending"; rmdir "$D/.native-launch.lock" 2>/dev/null || true' EXIT
log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$D/logs/native-controller.log"; }
worker='newton-(wake(-v02c|-v02)?|vad-turn)[.]sh([[:space:]]|$)'
server='llama-server.*(newton/models/qwen3[.]gguf|[[:space:]](--port|--port=)[[:space:]]*8080)'
find_matches() { command -v pgrep >/dev/null 2>&1 && pgrep -f "$1" 2>/dev/null || true; }
# Collect descendants while still attached to the Newton listener.
tree_pids() {
    local parent="$1" child
    if command -v pgrep >/dev/null 2>&1; then
        while IFS= read -r child; do
            [[ "$child" =~ ^[0-9]+$ ]] || continue
            [[ "$child" == "$$" || "$child" == "$PPID" ]] && continue
            tree_pids "$child"
        done < <(pgrep -P "$parent" 2>/dev/null || true)
    fi
    echo "$parent"
}
terminate_matched() {
    local expression="$1" pid descendant
    local -a victims=()
    while IFS= read -r pid; do
        [[ "$pid" =~ ^[0-9]+$ ]] || continue
        [[ "$pid" == "$$" || "$pid" == "$PPID" ]] && continue
        while IFS= read -r descendant; do
            [[ "$descendant" =~ ^[0-9]+$ ]] || continue
            [[ "$descendant" == "$$" || "$descendant" == "$PPID" ]] && continue
            victims+=("$descendant")
        done < <(tree_pids "$pid")
    done < <(find_matches "$expression")
    if ((${#victims[@]})); then kill -TERM "${victims[@]}" 2>/dev/null || true; fi
}
log 'Stop requested from app'
terminate_matched "$worker"
# Stop asynchronous Termux:API capture, if any; cannot hang Stop indefinitely.
if command -v termux-microphone-record >/dev/null 2>&1; then
    if command -v timeout >/dev/null 2>&1; then
        timeout 4 termux-microphone-record -q >/dev/null 2>&1 || true
    else
        termux-microphone-record -q >/dev/null 2>&1 || true
    fi
fi
if [[ -f "$D/stop.sh" ]]; then
    if command -v timeout >/dev/null 2>&1; then
        timeout 8 bash "$D/stop.sh" >> "$D/logs/native-controller.log" 2>&1 || true
    else
        bash "$D/stop.sh" >> "$D/logs/native-controller.log" 2>&1 || true
    fi
fi
terminate_matched "$worker"
terminate_matched "$server"
sleep 2
# Escalate only for surviving identifiable Newton processes.
for expression in "$worker" "$server"; do
    while IFS= read -r pid; do
        [[ "$pid" =~ ^[0-9]+$ ]] || continue
        [[ "$pid" == "$$" || "$pid" == "$PPID" ]] && continue
        kill -KILL "$pid" 2>/dev/null || true
    done < <(find_matches "$expression")
done
sleep 1
if [[ -n "$(find_matches "$worker")" || -n "$(find_matches "$server")" ]]; then
    log 'Stop incomplete: Newton worker still running'
    echo 'Stop incomplete; copy Newton diagnostics' >&2
    exit 1
fi
log 'Stop completed'
echo 'Newton stopped'
