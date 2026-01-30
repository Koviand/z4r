#!/bin/sh
# CGI: output JSON or HTML status (zapret running, FWTYPE, FLOWOFFLOAD, strategies)
# QUERY_STRING format=html -> text/html; else application/json

CONFIG="/opt/zapret/config"
want_html=0
case "$QUERY_STRING" in
  *format=html*) want_html=1 ;;
esac

# running
if pidof nfqws >/dev/null 2>&1; then
  running="true"
  running_txt="Запущен"
else
  running="false"
  running_txt="Остановлен"
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

if [ "$want_html" = "1" ]; then
  printf 'Content-Type: text/html; charset=utf-8\r\n\r\n'
  printf '<!DOCTYPE html><html lang="ru"><head><meta charset="utf-8"><title>z4r статус</title></head><body style="background:#1a1a1a;color:#e0e0e0;font-family:system-ui;padding:1rem">'
  printf '<h1>z4r — статус</h1><p>Zapret: <strong>%s</strong></p>' "$running_txt"
  printf '<p>YT_UDP: %s | YT_TCP: %s | YT_GV: %s | RKN: %s</p>' "$s_udp" "$s_tcp" "$s_gv" "$s_rkn"
  printf '<p>FWTYPE: %s | FLOWOFFLOAD: %s</p>' "$fwtype" "$flowoffload"
  printf '<p><a href="/" style="color:#6af">На главную</a></p></body></html>\n'
else
  printf 'Content-Type: application/json\r\n\r\n'
  printf '{"running":%s,"fwtype":"%s","flowoffload":"%s","strategies":{"yt_udp":%s,"yt_tcp":%s,"yt_gv":%s,"rkn":%s}}\n' \
    "$running" "$fwtype" "$flowoffload" "$s_udp" "$s_tcp" "$s_gv" "$s_rkn"
fi
