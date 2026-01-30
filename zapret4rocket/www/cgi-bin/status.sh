#!/bin/sh
# CGI: output JSON status (zapret running, FWTYPE, FLOWOFFLOAD, strategies)
# No read(), no interactive deps. POSIX sh for OpenWrt/Entware.

printf 'Content-Type: application/json\r\n\r\n'

CONFIG="/opt/zapret/config"

# running
if pidof nfqws >/dev/null 2>&1; then
  running="true"
else
  running="false"
fi

# FWTYPE, FLOWOFFLOAD
fwtype=$(grep '^FWTYPE=' "$CONFIG" 2>/dev/null | head -n1 | cut -d= -f2)
flowoffload=$(grep '^FLOWOFFLOAD=' "$CONFIG" 2>/dev/null | head -n1 | cut -d= -f2)

# Active strategy number in folder (1..max)
get_num() {
  folder="$1"
  max="$2"
  i=1
  while [ "$i" -le "$max" ]; do
    if [ -s "${folder}/${i}.txt" ]; then
      echo "$i"
      return 0
    fi
    i=$((i+1))
  done
  echo "0"
}

s_udp=$(get_num "/opt/zapret/extra_strats/UDP/YT" 8)
s_tcp=$(get_num "/opt/zapret/extra_strats/TCP/YT" 17)
s_gv=$(get_num "/opt/zapret/extra_strats/TCP/GV" 17)
s_rkn=$(get_num "/opt/zapret/extra_strats/TCP/RKN" 17)

# JSON (values assumed safe for simple printf)
printf '{"running":%s,"fwtype":"%s","flowoffload":"%s","strategies":{"yt_udp":%s,"yt_tcp":%s,"yt_gv":%s,"rkn":%s}}\n' \
  "$running" "$fwtype" "$flowoffload" "$s_udp" "$s_tcp" "$s_gv" "$s_rkn"
