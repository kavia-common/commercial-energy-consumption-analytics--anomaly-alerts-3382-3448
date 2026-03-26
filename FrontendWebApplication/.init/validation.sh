#!/usr/bin/env bash
set -euo pipefail
# Validation script for dev server readiness
WORKSPACE="/home/kavia/workspace/code-generation/commercial-energy-consumption-analytics--anomaly-alerts-3382-3448/FrontendWebApplication"
cd "$WORKSPACE"
PORT=${PORT:-3000}
VALIDATION_TIMEOUT=${VALIDATION_TIMEOUT:-90}
BUILD_ON_VALIDATE=${BUILD_ON_VALIDATE:-false}
# choose start command: prefer package.json start script, prefer yarn when yarn.lock present
if [ -f package.json ] && node -e "const j=require('./package.json');process.exit(j.scripts&&j.scripts.start?0:1)" >/dev/null 2>&1; then
  if [ -f yarn.lock ]; then START_CMD=(yarn start); else START_CMD=(npm run start); fi
else
  if [ -x node_modules/.bin/vite ]; then START_CMD=(node_modules/.bin/vite); else echo "No start script and vite binary not found; cannot start dev server" >&2; exit 3; fi
fi
# Optional build step
if [ "${BUILD_ON_VALIDATE}" = "true" ]; then
  if node -e "const j=require('./package.json');process.exit(j.scripts&&j.scripts.build?0:1)" >/dev/null 2>&1; then
    if [ -f yarn.lock ]; then yarn build --silent || { echo "yarn build failed" >&2; exit 4; }; else npm run build --silent || { echo "npm build failed" >&2; exit 4; }; fi
  fi
fi
LOGFILE=$(mktemp /tmp/validate_log.XXXX)
# Environment for headless dev servers
export NODE_ENV=development
export PORT="$PORT"
export CI=1
export BROWSER=none
# Start server in its own process group so we can kill the group
setsid "${START_CMD[@]}" >"$LOGFILE" 2>&1 &
SVC_PID=$!
# get process group id
SVC_PGID=$(ps -o pgid= -p $SVC_PID | tr -d ' ')
# Poll for readiness
READY=0
end=$((SECONDS+VALIDATION_TIMEOUT))
while [ $SECONDS -lt $end ]; do
  sleep 1
  if command -v curl >/dev/null 2>&1; then
    CODE=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 3 "http://127.0.0.1:$PORT/" || true)
    case "$CODE" in 2??|3??) READY=1; break;; esac
  else
    ps -p $SVC_PID >/dev/null 2>&1 && READY=1 && break
  fi
done
if [ "$READY" -ne 1 ]; then
  echo "dev server did not become ready within ${VALIDATION_TIMEOUT}s" >&2
  echo "--- server log ---" >&2
  sed -n '1,200p' "$LOGFILE" >&2 || true
  if [ -n "$SVC_PGID" ]; then kill -TERM -"$SVC_PGID" 2>/dev/null || true; sleep 1; kill -KILL -"$SVC_PGID" 2>/dev/null || true; fi
  rm -f "$LOGFILE"
  exit 5
fi
# Evidence of readiness
echo "validation: server ready on port $PORT (pid=$SVC_PID)"
echo "--- server log (head) ---"
sed -n '1,120p' "$LOGFILE" || true
# Graceful shutdown
if [ -n "$SVC_PGID" ]; then kill -TERM -"$SVC_PGID" 2>/dev/null || true; sleep 2; if ps -p $SVC_PID >/dev/null 2>&1; then kill -KILL -"$SVC_PGID" 2>/dev/null || true; fi; fi
rm -f "$LOGFILE"
