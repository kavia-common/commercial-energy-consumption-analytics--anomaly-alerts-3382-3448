#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/commercial-energy-consumption-analytics--anomaly-alerts-3382-3448/FrontendWebApplication"
cd "$WORKSPACE"
# Validate workspace
if [ ! -d "$WORKSPACE" ] || [ ! -w "$WORKSPACE" ]; then echo "workspace missing or not writable: $WORKSPACE" >&2; exit 11; fi
# If package.json exists, inspect safely and back up before edits
if [ -f package.json ]; then
  if ! node -e "JSON.parse(require('fs').readFileSync('package.json','utf8'))" >/dev/null 2>&1; then echo "package.json is malformed; please fix before scaffolding" >&2; exit 2; fi
  tsFlag="false"
  if [ "${TYPE_SCRIPT:-false}" = "true" ]; then tsFlag="true"; fi
  IS_CRA=0
  node -e "const j=require('./package.json');process.exit((j.dependencies&&j.dependencies['react-scripts'])||(j.devDependencies&&j.devDependencies['react-scripts'])?0:1)" >/dev/null 2>&1 && IS_CRA=1 || true
  IS_VITE=0
  node -e "const j=require('./package.json');process.exit((j.devDependencies&&j.devDependencies.vite)||(j.dependencies&&j.dependencies.vite)?0:1)" >/dev/null 2>&1 && IS_VITE=1 || true
  # If CRA detected, ensure conservative scripts exist (do not change dependencies)
  if [ "$IS_CRA" -eq 1 ]; then
    node -e "const fs=require('fs');let j=JSON.parse(fs.readFileSync('package.json'));j.scripts=j.scripts||{};if(!j.scripts.start)j.scripts.start='react-scripts start';if(!j.scripts.build)j.scripts.build='react-scripts build';if(!j.scripts.test)j.scripts.test=j.scripts.test||'react-scripts test';fs.writeFileSync('package.json',JSON.stringify(j,null,2));"
  else
    # Not CRA: if Vite detected, add safe scripts after backup
    if [ "$IS_VITE" -eq 1 ]; then
      cp package.json package.json.bak-$(date +%s)
      node -e "const fs=require('fs');let j=JSON.parse(fs.readFileSync('package.json'));j.scripts=j.scripts||{};if(!j.scripts.start)j.scripts.start='vite';if(!j.scripts.build)j.scripts.build='vite build';if(!j.scripts.test)j.scripts.test=j.scripts.test||'vitest';fs.writeFileSync('package.json',JSON.stringify(j,null,2));"
    fi
  fi
  mkdir -p src
else
  # No package.json: scaffold new app using preferred tool (default Vite)
  SCAFFOLD_TOOL=${SCAFFOLD_TOOL:-vite}
  SCAFFOLD_ALLOW_NETWORK=${SCAFFOLD_ALLOW_NETWORK:-false}
  if [ "$SCAFFOLD_TOOL" = "cra" ]; then
    if command -v create-react-app >/dev/null 2>&1; then
      if [ "${TYPE_SCRIPT:-false}" = "true" ]; then
        create-react-app . --template typescript --use-npm || { echo "create-react-app failed" >&2; exit 3; }
      else
        create-react-app . --use-npm || { echo "create-react-app failed" >&2; exit 3; }
      fi
    else
      if [ "$SCAFFOLD_ALLOW_NETWORK" = "true" ]; then
        if [ "${TYPE_SCRIPT:-false}" = "true" ]; then
          npx --yes create-react-app@latest . --template typescript || { echo "npx create-react-app failed" >&2; exit 3; }
        else
          npx --yes create-react-app@latest . || { echo "npx create-react-app failed" >&2; exit 3; }
        fi
      else
        echo "create-react-app not found locally. Set SCAFFOLD_ALLOW_NETWORK=true to allow npx network scaffolding." >&2; exit 4
      fi
    fi
  else
    TEMPLATE="react"
    if [ "${TYPE_SCRIPT:-false}" = "true" ]; then TEMPLATE="react-ts"; fi
    if command -v create-vite >/dev/null 2>&1; then
      create-vite . --template "$TEMPLATE" || { echo "create-vite failed" >&2; exit 5; }
    else
      if [ "$SCAFFOLD_ALLOW_NETWORK" = "true" ]; then
        npm init vite@latest . -- --template "$TEMPLATE" || { echo "npm init vite failed" >&2; exit 6; }
      else
        # If yarn is present, prefer yarn create
        if command -v yarn >/dev/null 2>&1 && [ "$SCAFFOLD_ALLOW_NETWORK" = "true" ]; then
          yarn create vite . --template "$TEMPLATE" || { echo "yarn create vite failed" >&2; exit 6; }
        else
          echo "create-vite not found locally. Set SCAFFOLD_ALLOW_NETWORK=true to allow network scaffolding." >&2; exit 7
        fi
      fi
    fi
  fi
fi
# Minimal lint/format configs (idempotent)
[ -f .eslintrc.json ] || cat > .eslintrc.json <<'JSON'
{ "env": { "browser": true, "es2021": true }, "extends": [ "eslint:recommended", "plugin:react/recommended" ], "parserOptions": { "ecmaVersion": 12, "sourceType": "module" } }
JSON
[ -f .prettierrc ] || cat > .prettierrc <<'JSON'
{ "singleQuote": true, "trailingComma": "es5" }
JSON
# Mock data fixture
mkdir -p src/mock && [ -f src/mock/sample.json ] || cat > src/mock/sample.json <<'JSON'
{ "message": "mock data" }
JSON
# Final validation
if [ ! -f package.json ] || [ ! -d src ]; then echo "scaffold validation failed: package.json or src missing" >&2; exit 8; fi
# Print brief success note
echo "scaffold step completed: package.json present and src/ exists"
