#!/usr/bin/env bash
set -euo pipefail
# testing-setup: detect runner, add test script if missing, add smoke test, run tests
WORKSPACE="/home/kavia/workspace/code-generation/commercial-energy-consumption-analytics--anomaly-alerts-3382-3448/FrontendWebApplication"
cd "$WORKSPACE"
# detect runner in package.json
RUNNER=""
if [ -f package.json ]; then
  if node -e "const j=require('./package.json');process.exit((j.devDependencies&&j.devDependencies.jest)||(j.dependencies&&j.dependencies.jest)?0:1)" >/dev/null 2>&1; then RUNNER=jest; fi
  if [ -z "$RUNNER" ]; then
    if node -e "const j=require('./package.json');process.exit((j.devDependencies&&j.devDependencies.vitest)||(j.dependencies&&j.dependencies.vitest)?0:1)" >/dev/null 2>&1; then RUNNER=vitest; fi
  fi
fi
# ensure package.json has a test script but do not overwrite an existing one
if [ -z "$RUNNER" ]; then
  node -e "const fs=require('fs');let j=fs.existsSync('package.json')?JSON.parse(fs.readFileSync('package.json')):{scripts:{}};j.scripts=j.scripts||{};if(!j.scripts.test)j.scripts.test='vitest run';fs.writeFileSync('package.json',JSON.stringify(j,null,2));"
  RUNNER=vitest
else
  # ensure scripts.test exists for the detected runner
  node -e "const fs=require('fs');let j=fs.existsSync('package.json')?JSON.parse(fs.readFileSync('package.json')):{scripts:{}};j.scripts=j.scripts||{};if(!j.scripts.test){j.scripts.test=process.argv[1]==='jest'? 'jest --runInBand' : 'vitest run';}fs.writeFileSync('package.json',JSON.stringify(j,null,2));" "$RUNNER"
fi
# create minimal test directory and file
mkdir -p test
if [ "${TYPE_SCRIPT:-false}" = "true" ]; then
  [ -f tsconfig.json ] || cat > tsconfig.json <<'TS'
{
  "compilerOptions": { "target":"ES2020","module":"ESNext","jsx":"react-jsx","moduleResolution":"node","strict":true,"esModuleInterop":true }
}
TS
  if [ ! -f test/sample.test.ts ]; then
    cat > test/sample.test.ts <<TS
import { describe, it, expect } from '${RUNNER}'
describe('smoke', () => { it('works', () => expect(1+1).toBe(2)) })
TS
  fi
else
  if [ ! -f test/sample.test.js ]; then
    cat > test/sample.test.js <<JS
import { describe, it, expect } from '${RUNNER}'
describe('smoke', () => { it('works', () => expect(1+1).toBe(2)) })
JS
  fi
fi
# choose package manager: prefer yarn if yarn.lock present
if [ -f yarn.lock ]; then
  command -v yarn >/dev/null 2>&1 || { echo "ERROR: yarn.lock exists but 'yarn' binary not found on PATH. Install yarn or remove yarn.lock." >&2; exit 4; }
  # run yarn test; prefer local binary but yarn will resolve from deps
  if ! CI=1 BROWSER=none yarn test --silent; then echo "ERROR: yarn test failed" >&2; exit 5; fi
else
  # verify local runner binary exists when using npm
  if [ "$RUNNER" = "vitest" ]; then
    if [ ! -x node_modules/.bin/vitest ] && ! command -v vitest >/dev/null 2>&1; then
      echo "ERROR: vitest not installed locally. Run install-dependencies (ensure vitest in devDependencies) or run 'npm install vitest -D'." >&2; exit 6
    fi
  fi
  if [ "$RUNNER" = "jest" ]; then
    if [ ! -x node_modules/.bin/jest ] && ! command -v jest >/dev/null 2>&1; then
      echo "ERROR: jest not installed locally. Run install-dependencies (ensure jest in devDependencies) or run 'npm install jest -D'." >&2; exit 7
    fi
  fi
  if ! CI=1 npm run test --silent; then echo "ERROR: npm test failed" >&2; exit 8; fi
fi
# success
echo "OK: tests ran successfully with runner='$RUNNER'"
