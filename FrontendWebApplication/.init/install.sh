#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/commercial-energy-consumption-analytics--anomaly-alerts-3382-3448/FrontendWebApplication"
cd "$WORKSPACE"
# Validate package.json if present
if [ -f package.json ]; then
  if ! node -e "JSON.parse(require('fs').readFileSync('package.json','utf8'))" >/dev/null 2>&1; then echo "package.json malformed" >&2; exit 2; fi
  cp package.json package.json.bak-$(date +%s)
fi
# Patch package.json deterministically (adds react/react-dom, vite, vitest, optional TS/@types)
node -e "const fs=require('fs'),p='package.json';let j=fs.existsSync(p)?JSON.parse(fs.readFileSync(p)):{name:'app',version:'0.0.0'};j.dependencies=j.dependencies||{};j.devDependencies=j.devDependencies||{};if(!j.dependencies.react)j.dependencies.react='^18.2.0';if(!j.dependencies['react-dom'])j.dependencies['react-dom']='^18.2.0';if(!j.devDependencies.vite)j.devDependencies.vite='^5.1.0';if(!j.devDependencies.vitest)j.devDependencies.vitest='^1.1.0';if(process.env.TYPE_SCRIPT==='true'){if(!j.devDependencies.typescript)j.devDependencies.typescript='^5.3.0';if(!j.devDependencies['@types/react'])j.devDependencies['@types/react']='^18.2.0';if(!j.devDependencies['@types/react-dom'])j.devDependencies['@types/react-dom']='^18.2.0'};fs.writeFileSync(p,JSON.stringify(j,null,2));" || { echo "failed to patch package.json" >&2; exit 3; }
# Determine installer and install deterministically
if [ -f yarn.lock ]; then
  if command -v yarn >/dev/null 2>&1; then
    # detect yarn major version; default to classic behavior for 1.x, treat 2+ as berry
    YV=$(yarn -v 2>/dev/null || true)
    Y_MAJOR=$(echo "$YV" | cut -d. -f1 || true)
    if echo "$Y_MAJOR" | grep -qE '^[0-9]+$' && [ "${Y_MAJOR}" -le 1 ]; then
      yarn install --silent --no-progress --non-interactive || { echo "yarn install failed" >&2; exit 4; }
    else
      # yarn berry (2+)
      if yarn -v >/dev/null 2>&1; then
        # try immutable install; will fail if lockfile inconsistent
        yarn install --immutable --silent || { echo "yarn berry immutable install failed; try running 'yarn install' manually" >&2; exit 5; }
      else
        npm install --no-audit --no-fund --silent || { echo "npm install fallback failed" >&2; exit 6; }
      fi
    fi
  else
    echo "yarn.lock present but yarn CLI not found; run 'sudo apt-get install -y yarn' or remove yarn.lock" >&2; exit 7
  fi
elif [ -f package-lock.json ]; then
  # prefer npm ci for deterministic installs; if it fails (package.json changed relative to lock), refresh via npm install
  if ! npm ci --no-audit --no-fund --silent; then
    echo "npm ci failed; attempting npm install to refresh lockfile" >&2
    npm install --no-audit --no-fund --silent || { echo "npm install failed" >&2; exit 8; }
  fi
else
  npm install --no-audit --no-fund --silent || { echo "npm install failed" >&2; exit 9; }
fi
# Validate expected local binaries (prefer local node_modules/.bin over globals)
if [ -f package.json ]; then
  node -e "const j=require('./package.json');if((j.devDependencies&&j.devDependencies.vite)||(j.dependencies&&j.dependencies.vite))process.exit(0);process.exit(1)" >/dev/null 2>&1 && [ ! -f node_modules/.bin/vite ] && { echo "vite expected but node_modules/.bin/vite missing; re-run install or inspect logs" >&2; exit 10; } || true
  node -e "const j=require('./package.json');if((j.devDependencies&&j.devDependencies.vitest)||(j.dependencies&&j.dependencies.vitest))process.exit(0);process.exit(1)" >/dev/null 2>&1 && [ ! -f node_modules/.bin/vitest ] && { echo "vitest expected but node_modules/.bin/vitest missing; re-run install or inspect logs" >&2; exit 11; } || true
fi
# Ensure npm global bin is prepended to PATH in /etc/profile.d if non-empty (idempotent)
NG_BIN=$(npm bin -g 2>/dev/null || true)
if [ -n "$NG_BIN" ]; then
  OUTF=/etc/profile.d/frontend_env.sh
  sudo sh -c "cat > $OUTF <<'EOF'
# Frontend environment variables
export NODE_ENV=development
export PORT=
# prepend npm global bin if not already in PATH
if [ -n \"$NG_BIN\" ] && [[ \":$PATH:\" != *\":$NG_BIN:\"* ]]; then
  export PATH=$NG_BIN:$PATH
fi
EOF"
  sudo chmod 644 "$OUTF"
fi
# Success
echo "dependencies installed and verified"
