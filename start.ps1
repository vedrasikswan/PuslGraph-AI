# PulseGraph AI - one-command start (Windows / PowerShell)
#
#   .\start.ps1            first run: sets up, loads demo data, starts both services
#   .\start.ps1 -SkipSetup skip dependency install
#   .\start.ps1 -Verify    run the full test + build validation instead of serving
#
# Leaves the backend on :8000 and the frontend on :3000.

param(
    [switch]$SkipSetup,
    [switch]$Verify
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$backend = Join-Path $root 'backend'
$frontend = Join-Path $root 'frontend'
$venvPython = Join-Path $backend '.venv\Scripts\python.exe'

function Write-Step($message) {
    Write-Host ""
    Write-Host "==> $message" -ForegroundColor Cyan
}

function Resolve-Python {
    foreach ($candidate in @('python', 'python3', 'py')) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($cmd) {
            # The Microsoft Store stub reports a version but cannot run code.
            $previous = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            & $cmd.Source -c "import sys" *> $null
            $usable = ($LASTEXITCODE -eq 0)
            $ErrorActionPreference = $previous
            if ($usable) { return $cmd.Source }
        }
    }
    throw "Python 3.11+ not found. Install it from https://python.org and re-run."
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js 18+ not found. Install it from https://nodejs.org and re-run."
}

# --- backend setup ---------------------------------------------------------
if (-not $SkipSetup) {
    Write-Step "Setting up the backend"
    if (-not (Test-Path $venvPython)) {
        $python = Resolve-Python
        Write-Host "Creating virtual environment with $python"
        & $python -m venv (Join-Path $backend '.venv')
        if (-not (Test-Path $venvPython)) {
            throw "Could not create the virtual environment at $backend\.venv."
        }
    }

    # Upgrading pip is a convenience, not a requirement - a failure here is not
    # fatal, but a failed dependency install absolutely is. Native commands do
    # not trip $ErrorActionPreference, so exit codes are checked explicitly:
    # without this a failed install slips through and the pipeline later dies
    # with a confusing ModuleNotFoundError.
    & $venvPython -m pip install --upgrade pip --quiet
    & $venvPython -m pip install -r (Join-Path $backend 'requirements.txt')
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Backend dependency install FAILED (see the pip output above)." -ForegroundColor Red
        & $venvPython --version
        throw "pip could not install backend/requirements.txt. If the error mentions building numpy or scipy from source, your Python version is likely newer than those packages ship wheels for - install Python 3.12 from python.org and delete backend\.venv before retrying."
    }
    Write-Host "Backend dependencies ready." -ForegroundColor Green

    Write-Step "Setting up the frontend"
    Push-Location $frontend
    try {
        if (-not (Test-Path 'node_modules')) {
            npm install --no-fund --no-audit
            if ($LASTEXITCODE -ne 0) { throw "npm install failed (see the output above)." }
        }
        if (-not (Test-Path '.env.local')) { Copy-Item '.env.local.example' '.env.local' }
    } finally {
        Pop-Location
    }
    Write-Host "Frontend dependencies ready." -ForegroundColor Green
}

# Guard the -SkipSetup path too: a half-installed environment should say so
# rather than starting services that cannot work.
if (-not (Test-Path $venvPython)) {
    throw "No virtual environment found. Run without -SkipSetup first."
}
# PowerShell 5.1 turns a native command's stderr into NativeCommandError records
# when $ErrorActionPreference is Stop, which buries the real message in noise.
# Relax it around the probe and swallow every stream so the failure reads clean.
$previousPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& $venvPython -c "import sqlalchemy, fastapi, networkx" *> $null
$dependenciesOk = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = $previousPreference

if (-not $dependenciesOk) {
    Write-Host ""
    Write-Host "Backend dependencies are missing or incomplete." -ForegroundColor Red
    Write-Host "Install them with:" -ForegroundColor Yellow
    Write-Host "  .\backend\.venv\Scripts\python.exe -m pip install -r .\backend\requirements.txt"
    Write-Host "or re-run this script without -SkipSetup."
    exit 1
}

# --- verification mode -----------------------------------------------------
if ($Verify) {
    Write-Step "Backend tests"
    Push-Location $backend
    & $venvPython -m pytest -q
    if ($LASTEXITCODE -ne 0) { Pop-Location; throw "Backend tests failed." }
    Pop-Location

    Write-Step "Frontend typecheck, lint, tests and build"
    Push-Location $frontend
    npm run typecheck; if ($LASTEXITCODE -ne 0) { Pop-Location; throw "Typecheck failed." }
    npm run lint;      if ($LASTEXITCODE -ne 0) { Pop-Location; throw "Lint failed." }
    npm run test;      if ($LASTEXITCODE -ne 0) { Pop-Location; throw "Frontend tests failed." }
    npm run build;     if ($LASTEXITCODE -ne 0) { Pop-Location; throw "Build failed." }
    Pop-Location

    Write-Host ""
    Write-Host "All checks passed." -ForegroundColor Green
    exit 0
}

# --- seed the database -----------------------------------------------------
Write-Step "Loading the demo dataset"
Push-Location $backend
try {
    & $venvPython -c @"
from app.db import init_db, session_scope
from app.analytics.pipeline import Pipeline
init_db()
with session_scope() as db:
    run = Pipeline(db).run(['demo'], trigger='startup')
    checks = [v for v in run.validation.values() if isinstance(v, dict)]
    passed = sum(1 for v in checks if v['passed'])
    print(f'{run.posts_ingested} posts from {run.authors_ingested} accounts')
    print(f'seed validation: {passed}/{len(checks)} checks passed')
"@
    # Starting the services on top of a failed load would show an empty
    # dashboard with no explanation, so stop here instead.
    if ($LASTEXITCODE -ne 0) {
        throw "Could not build the demo dataset (see the error above). The services were not started."
    }
} finally {
    Pop-Location
}

# --- serve -----------------------------------------------------------------
Write-Step "Starting services"
$backendJob = Start-Process -PassThru -WindowStyle Minimized `
    -FilePath $venvPython `
    -ArgumentList '-m', 'uvicorn', 'app.main:app', '--port', '8000' `
    -WorkingDirectory $backend

$frontendJob = Start-Process -PassThru -WindowStyle Minimized `
    -FilePath 'cmd.exe' -ArgumentList '/c', 'npm', 'run', 'dev' `
    -WorkingDirectory $frontend

Write-Host ""
Write-Host "  Dashboard : http://localhost:3000/dashboard" -ForegroundColor Green
Write-Host "  API docs  : http://127.0.0.1:8000/docs"      -ForegroundColor Green
Write-Host ""
Write-Host "Press Ctrl+C to stop both services."

try {
    Wait-Process -Id $backendJob.Id
} finally {
    foreach ($proc in @($backendJob, $frontendJob)) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
}
