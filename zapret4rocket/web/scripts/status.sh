#!/bin/sh
# Outputs JSON status for web panel. No dependency on z4r lib.

CONFIG="${CONFIG:-/opt/zapret/config}"
CACHE="${CACHE:-/opt/zapret/extra_strats/cache}"
BASE_STRATS="${BASE_STRATS:-/opt/zapret/extra_strats}"

get_active_strat_num() {
    folder="$1"
    max="$2"
    i=1
    while [ "$i" -le "$max" ]; do
        if [ -s "${folder}/${i}.txt" ]; then
            echo "$i"
            return
        fi
        i=$(( i + 1 ))
    done
    echo "0"
}

# Zapret running?
zapret_running="false"
if pidof nfqws >/dev/null 2>&1; then
    zapret_running="true"
fi

# Strategies (same logic as strategies.sh get_current_strategies_info)
s_udp=$(get_active_strat_num "${BASE_STRATS}/UDP/YT" 8)
s_tcp=$(get_active_strat_num "${BASE_STRATS}/TCP/YT" 17)
s_gv=$(get_active_strat_num "${BASE_STRATS}/TCP/GV" 17)
s_rkn=$(get_active_strat_num "${BASE_STRATS}/TCP/RKN" 17)
strategies="YT_UDP:${s_udp} YT_TCP:${s_tcp} YT_GV:${s_gv} RKN:${s_rkn}"

# Provider
provider="Не определён"
if [ -s "${CACHE}/provider.txt" ]; then
    provider=$(head -n 1 "${CACHE}/provider.txt" | tr -cd '[:print:\n]' | head -c 200)
fi

# Config snippets
flowoffload=""
fwtype=""
nfqws_ports_udp=""
if [ -f "$CONFIG" ]; then
    flowoffload=$(grep '^FLOWOFFLOAD=' "$CONFIG" 2>/dev/null | head -n 1 | cut -d= -f2-)
    fwtype=$(grep '^FWTYPE=' "$CONFIG" 2>/dev/null | head -n 1 | cut -d= -f2-)
    nfqws_ports_udp=$(grep '^NFQWS_PORTS_UDP=' "$CONFIG" 2>/dev/null | head -n 1 | cut -d= -f2-)
fi

# TCP443 "bezrazbornyj" mode: line number 1-17 where --hostlist-domains= (empty)
tcp443_mode="0"
if [ -f "$CONFIG" ]; then
    num=$(sed -n '112,128p' "$CONFIG" | grep -n '^--filter-tcp=443 --hostlist-domains= --' 2>/dev/null | head -n 1 | cut -d: -f1)
    [ -n "$num" ] && tcp443_mode="$num"
fi

# JSON (escape quotes in string values)
escape_json() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g'
}

printf '{"zapret_running":%s,"strategies":"%s","provider":"%s","flowoffload":"%s","fwtype":"%s","nfqws_ports_udp":"%s","tcp443_mode":"%s"}\n' \
    "$zapret_running" \
    "$(escape_json "$strategies")" \
    "$(escape_json "$provider")" \
    "$(escape_json "$flowoffload")" \
    "$(escape_json "$fwtype")" \
    "$(escape_json "$nfqws_ports_udp")" \
    "$tcp443_mode"
