#!/bin/sh
# Action wrappers for web panel API. Output JSON: {"ok":true} or {"ok":false,"error":"..."}

ZAPRET_INIT="${ZAPRET_INIT:-/opt/zapret/init.d/sysv/zapret}"

action_restart() {
    if [ ! -x "$ZAPRET_INIT" ]; then
        echo '{"ok":false,"error":"zapret init script not found"}'
        return 1
    fi
    if "$ZAPRET_INIT" restart 2>/tmp/z4r_web_action.err; then
        echo '{"ok":true}'
        return 0
    fi
    err=$(cat /tmp/z4r_web_action.err 2>/dev/null | head -c 500 | sed 's/"/\\"/g')
    echo "{\"ok\":false,\"error\":\"${err}\"}"
    return 1
}

action_stop() {
    if [ ! -x "$ZAPRET_INIT" ]; then
        echo '{"ok":false,"error":"zapret init script not found"}'
        return 1
    fi
    if "$ZAPRET_INIT" stop 2>/tmp/z4r_web_action.err; then
        echo '{"ok":true}'
        return 0
    fi
    err=$(cat /tmp/z4r_web_action.err 2>/dev/null | head -c 500 | sed 's/"/\\"/g')
    echo "{\"ok\":false,\"error\":\"${err}\"}"
    return 1
}

# Non-interactive access check: run curl tests, output text result
action_check() {
    out="/tmp/z4r_web_check.$$"
    : > "$out"
    ok=0
    # YouTube
    if curl --tlsv1.3 --max-time 3 -s -o /dev/null -w "%{http_code}" "https://www.youtube.com/" 2>/dev/null | grep -q '^[23]'; then
        echo "youtube.com: OK" >> "$out"
    else
        echo "youtube.com: fail" >> "$out"
        ok=1
    fi
    # Meduza
    if curl --tlsv1.3 --max-time 3 -s -o /dev/null -w "%{http_code}" "https://meduza.io" 2>/dev/null | grep -q '^[23]'; then
        echo "meduza.io: OK" >> "$out"
    else
        echo "meduza.io: fail" >> "$out"
        ok=1
    fi
    # Instagram
    if curl --tlsv1.3 --max-time 3 -s -o /dev/null -w "%{http_code}" "https://www.instagram.com/" 2>/dev/null | grep -q '^[23]'; then
        echo "instagram.com: OK" >> "$out"
    else
        echo "instagram.com: fail" >> "$out"
        ok=1
    fi
    result=$(cat "$out")
    rm -f "$out"
    # Escape for JSON
    result_escaped=$(echo "$result" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g')
    if [ "$ok" -eq 0 ]; then
        echo "{\"ok\":true,\"log\":\"${result_escaped}\"}"
    else
        echo "{\"ok\":false,\"log\":\"${result_escaped}\"}"
    fi
}

case "${1}" in
    restart) action_restart ;;
    stop)    action_stop ;;
    check)   action_check ;;
    *)
        echo '{"ok":false,"error":"unknown action"}'
        exit 1
        ;;
esac
