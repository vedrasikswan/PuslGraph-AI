#!/usr/bin/env bash
# PulseGraph AI - one-command start (macOS / Linux)
#
#   ./start.sh           first run: sets up, loads demo data, starts both services
#   ./start.sh --skip-setup
#   ./start.sh --verify  run the full test + build validation instead of serving

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND="$ROOT/backend"
FRONTEND="$ROOT/frontend"
VENV_PY="$BACKEND/.venv/bin/python"

SKIP_SETUP=0
VERIFY=0
for arg in "$@"; do
  case "$arg" in
    --skip-setup) SKIP_SETUP=1 ;;
    --verify) VERIFY=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

step() { printf '\n\033[36m==> %s\033[0m\n' "$1"; }

command -v node >/dev/null 2>&1 || {
  echo "Node.js 18+ not found. Install it from https://nodejs.org" >&2; exit 1;
}

PYTHON=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c "import sys" >/dev/null 2>&1; then
    PYTHON="$candidate"; break
  fi
done
[ -n "$PYTHON" ] || { echo "Python 3.11+ not found." >&2; exit 1; }

if [ "$SKIP_SETUP" -eq 0 ]; then
  step "Setting up the backend"
  [ -x "$VENV_PY" ] || "$PYTHON" -m venv "$BACKEND/.venv"
  [ -x "$VENV_PY" ] || { echo "Could not create the virtual environment." >&2; exit 1; }

  # A failed pip upgrade is survivable; a failed dependency install is not.
  # Without an explicit check the run continues and the pipeline later dies
  # with a confusing ModuleNotFoundError.
  "$VENV_PY" -m pip install --upgrade pip --quiet || true
  if ! "$VENV_PY" -m pip install -r "$BACKEND/requirements.txt"; then
    echo "" >&2
    echo "Backend dependency install FAILED (see the pip output above)." >&2
    "$VENV_PY" --version >&2
    echo "If the error mentions building numpy or scipy from source, your Python is newer than those packages ship wheels for. Install Python 3.12 and delete backend/.venv before retrying." >&2
    exit 1
  fi
  echo "Backend dependencies ready."

  step "Setting up the frontend"
  cd "$FRONTEND"
  if [ ! -d node_modules ]; then
    npm install --no-fund --no-audit || { echo "npm install failed." >&2; exit 1; }
  fi
  [ -f .env.local ] || cp .env.local.example .env.local
  echo "Frontend dependencies ready."
fi

# Guard the --skip-setup path too: a half-installed environment should say so
# rather than starting services that cannot work.
[ -x "$VENV_PY" ] || { echo "No virtual environment. Run without --skip-setup first." >&2; exit 1; }
"$VENV_PY" -c "import sqlalchemy, fastapi, networkx" 2>/dev/null || {
  echo "Backend dependencies are missing or incomplete." >&2
  echo "Install them with: backend/.venv/bin/python -m pip install -r backend/requirements.txt" >&2
  exit 1
}

if [ "$VERIFY" -eq 1 ]; then
  step "Backend tests"
  (cd "$BACKEND" && "$VENV_PY" -m pytest -q)

  step "Frontend typecheck, lint, tests and build"
  cd "$FRONTEND"
  npm run typecheck
  npm run lint
  npm run test
  npm run build

  printf '\n\033[32mAll checks passed.\033[0m\n'
  exit 0
fi

step "Loading the demo dataset"
cd "$BACKEND"
if ! "$VENV_PY" - <<'PY'
from app.db import init_db, session_scope
from app.analytics.pipeline import Pipeline

init_db()
with session_scope() as db:
    run = Pipeline(db).run(["demo"], trigger="startup")
    checks = [v for v in run.validation.values() if isinstance(v, dict)]
    passed = sum(1 for v in checks if v["passed"])
    print(f"{run.posts_ingested} posts from {run.authors_ingested} accounts")
    print(f"seed validation: {passed}/{len(checks)} checks passed")
PY
then
  # Starting the services on top of a failed load would show an empty dashboard
  # with no explanation, so stop here instead.
  echo "Could not build the demo dataset. The services were not started." >&2
  exit 1
fi

step "Starting services"
"$VENV_PY" -m uvicorn app.main:app --port 8000 &
BACKEND_PID=$!

cd "$FRONTEND"
npm run dev &
FRONTEND_PID=$!

cleanup() {
  kill "$BACKEND_PID" "$FRONTEND_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

printf '\n\033[32m  Dashboard : http://localhost:3000/dashboard\033[0m\n'
printf '\033[32m  API docs  : http://127.0.0.1:8000/docs\033[0m\n\n'
echo "Press Ctrl+C to stop both services."

wait "$BACKEND_PID"
