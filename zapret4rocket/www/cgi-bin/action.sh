#!/bin/sh
# CGI: perform whitelisted actions (start|stop|restart; optional fwtype, flowoffload)
# GET only: QUERY_STRING e.g. action=restart

printf 'Content-Type: application/json\r\n\r\n'

ZAPRET="/opt/zapret/init.d/sysv/zapret"
CONFIG="/opt/zapret/config"

# Parse QUERY_STRING
action=""
flowoffload_val=""
fwtype_val=""
IFS='&'
for pair in $QUERY_STRING; do
  key="${pair%%=*}"
  val="${pair#*=}"
  case "$key" in
    action) action="$val" ;;
    flowoffload) flowoffload_val="$val" ;;
    fwtype) fwtype_val="$val" ;;
  esac
done
unset IFS

# Prefer explicit action=start|stop|restart
case "$action" in
  start|stop|restart)
    "$ZAPRET" "$action" 2>/dev/null
    printf '{"ok":true}\n'
    exit 0
    ;;
esac

# Optional: flowoffload (requires restart)
if [ -n "$flowoffload_val" ]; then
  case "$flowoffload_val" in
    software|hardware|none|donttouch)
      sed -i "s/^FLOWOFFLOAD=.*/FLOWOFFLOAD=$flowoffload_val/" "$CONFIG" 2>/dev/null
      /opt/zapret/install_prereq.sh 2>/dev/null || true
      "$ZAPRET" restart 2>/dev/null
      printf '{"ok":true}\n'
      exit 0
      ;;
  esac
fi

# Optional: fwtype (requires restart)
if [ -n "$fwtype_val" ]; then
  case "$fwtype_val" in
    iptables|nftables)
      sed -i "s/^FWTYPE=.*/FWTYPE=$fwtype_val/" "$CONFIG" 2>/dev/null
      /opt/zapret/install_prereq.sh 2>/dev/null || true
      "$ZAPRET" restart 2>/dev/null
      printf '{"ok":true}\n'
      exit 0
      ;;
  esac
fi

printf '{"ok":false,"error":"Unknown or missing action"}\n'
