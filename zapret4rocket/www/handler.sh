#!/bin/sh
# Minimal HTTP handler for nc -e: one request per invocation.
# Run from /opt/zapret/www; stdin/stdout are the socket.

cd /opt/zapret/www 2>/dev/null || true

# Read request line (e.g. "GET / HTTP/1.0" or "GET /cgi-bin/status.sh HTTP/1.0")
read -r line 2>/dev/null || exit 0
path="${line#GET }"
path="${path%% HTTP*}"
# Strip leading slash and optional query
query=""
case "$path" in
  *\?*) query="${path#*\?}"; path="${path%%\?*}" ;;
esac
path="${path#/}"

# Consume remaining headers (avoid blocking)
while read -r rest 2>/dev/null; do
  [ -z "$rest" ] && break
done

# Serve response
if [ -z "$path" ] || [ "$path" = "index.html" ]; then
  printf 'HTTP/1.0 200 OK\r\nContent-Type: text/html; charset=utf-8\r\n\r\n'
  cat index.html 2>/dev/null
elif [ "$path" = "cgi-bin/status.sh" ]; then
  REQUEST_METHOD=GET QUERY_STRING="" ./cgi-bin/status.sh 2>/dev/null
elif [ "$path" = "cgi-bin/action.sh" ]; then
  export REQUEST_METHOD=GET
  export QUERY_STRING="$query"
  ./cgi-bin/action.sh 2>/dev/null
else
  printf 'HTTP/1.0 404 Not Found\r\nContent-Type: text/plain\r\n\r\nNot Found\r\n'
fi
