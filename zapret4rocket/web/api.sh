#!/bin/sh
# API для веб-панели zeefeer: статус и действия (restart/stop/start).
# Вызывается с QUERY_STRING или PATH_INFO: status | restart | stop | start
# Печатает JSON в stdout.

ZAPRET_DIR="${ZAPRET_DIR:-/opt/zapret}"
CONFIG="$ZAPRET_DIR/config"
CACHE_PROVIDER="$ZAPRET_DIR/extra_strats/cache/provider.txt"

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

get_strategies_info() {
  s_udp=$(get_active_strat_num "$ZAPRET_DIR/extra_strats/UDP/YT" 8)
  s_tcp=$(get_active_strat_num "$ZAPRET_DIR/extra_strats/TCP/YT" 17)
  s_gv=$(get_active_strat_num "$ZAPRET_DIR/extra_strats/TCP/GV" 17)
  s_rkn=$(get_active_strat_num "$ZAPRET_DIR/extra_strats/TCP/RKN" 17)
  echo "YT_UDP:$s_udp YT_TCP:$s_tcp YT_GV:$s_gv RKN:$s_rkn"
}

get_provider() {
  if [ -s "$CACHE_PROVIDER" ]; then
    head -n1 "$CACHE_PROVIDER" | tr -d '\n'
  else
    echo "Не определён"
  fi
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g'
}

json_status() {
  if pidof nfqws >/dev/null 2>&1; then
    zapret="run"
  else
    zapret="stop"
  fi
  strategies=$(get_strategies_info)
  provider=$(get_provider)
  printf '{"zapret":"%s","strategies":"%s","provider":"%s"}\n' "$zapret" "$(json_escape "$strategies")" "$(json_escape "$provider")"
}

json_ok() {
  printf '{"ok":true,"message":"%s"}\n' "$1"
}

json_err() {
  printf '{"ok":false,"message":"%s"}\n' "$1"
}

action_restart() {
  if [ -x "$ZAPRET_DIR/init.d/sysv/zapret" ]; then
    "$ZAPRET_DIR/init.d/sysv/zapret" restart >/dev/null 2>&1 && json_ok "Zapret перезапущен" || json_err "Ошибка перезапуска"
  else
    json_err "Скрипт zapret не найден"
  fi
}

action_stop() {
  if [ -x "$ZAPRET_DIR/init.d/sysv/zapret" ]; then
    "$ZAPRET_DIR/init.d/sysv/zapret" stop >/dev/null 2>&1 && json_ok "Zapret остановлен" || json_err "Ошибка остановки"
  else
    json_err "Скрипт zapret не найден"
  fi
}

action_start() {
  if [ -x "$ZAPRET_DIR/init.d/sysv/zapret" ]; then
    "$ZAPRET_DIR/init.d/sysv/zapret" restart >/dev/null 2>&1 && json_ok "Zapret запущен" || json_err "Ошибка запуска"
  else
    json_err "Скрипт zapret не найден"
  fi
}

# Определяем действие: из QUERY_STRING или PATH_INFO или аргумента
action=""
if [ -n "$QUERY_STRING" ]; then
  action="$QUERY_STRING"
elif [ -n "$PATH_INFO" ]; then
  action="${PATH_INFO#/}"
elif [ -n "$1" ]; then
  action="$1"
fi

# Убираем слеш и api/ в начале
action=$(echo "$action" | sed 's|^/||;s|^api/||;s|/.*||')

case "$action" in
  status)
    json_status
    ;;
  restart)
    action_restart
    ;;
  stop)
    action_stop
    ;;
  start)
    action_start
    ;;
  *)
    json_err "Неизвестное действие: $action"
    ;;
esac
