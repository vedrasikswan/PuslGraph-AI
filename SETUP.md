# Running PulseGraph AI on your laptop

You need two things installed. Everything else is automatic.

| | Minimum | Check with | Get it |
|---|---|---|---|
| **Python** | 3.11+ | `python --version` | [python.org/downloads](https://www.python.org/downloads/) — tick **"Add python.exe to PATH"** during install |
| **Node.js** | 18+ | `node --version` | [nodejs.org](https://nodejs.org/) — take the LTS build |

> **Windows note:** if `python --version` opens the Microsoft Store, you have the
> placeholder rather than real Python. Install from python.org, or turn off
> *Settings → Apps → Advanced app settings → App execution aliases → python.exe*.

You do **not** need: API keys, an OpenAI account, a database server, Docker, or
an internet connection after the first install.

---

## Start it

**Windows (PowerShell)** — from the project folder:

```powershell
.\start.ps1
```

**macOS / Linux:**

```bash
./start.sh
```

The first run takes 3–5 minutes: it creates a Python virtual environment,
installs both dependency sets, generates the demo dataset and runs the analysis
pipeline. After that, startup is a few seconds.

When it finishes you'll see:

```
  Dashboard : http://localhost:3000/dashboard
  API docs  : http://127.0.0.1:8000/docs
```

Open the dashboard. You should see a **DEMO MODE** badge in the header and an
Audience Pulse paragraph at the top. Press `Ctrl+C` in the terminal to stop.

### Later runs

```powershell
.\start.ps1 -SkipSetup
```

Skips the dependency install.

---

## If PowerShell blocks the script

Windows blocks unsigned scripts by default. Either run it once as:

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1
```

or allow local scripts permanently for your user:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

---

## Manual start (if you prefer, or the script fails)

Two terminals.

**Terminal 1 — backend:**

```powershell
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --port 8000
```

On macOS/Linux the activate line is `source .venv/bin/activate`.

**Terminal 2 — frontend:**

```powershell
cd frontend
npm install
copy .env.local.example .env.local
npm run dev
```

Then open `http://localhost:3000` and click **Load Demo Intelligence** on the
*Data sources* page (the dashboard will link you there if no data is loaded).

---

## Troubleshooting

**"Backend unreachable" in the dashboard**
The backend isn't running or isn't on port 8000. Check terminal 1, then confirm
`http://127.0.0.1:8000/api/health` returns JSON in a browser.

**"No dataset loaded" / empty dashboard**
Go to `/data` and click **Load Demo Intelligence**. Takes about 7 seconds.

**Port 3000 or 8000 already in use**
Something else is on that port. Either stop it, or run the backend on another
port with `uvicorn app.main:app --port 8010` and set `NEXT_PUBLIC_API_URL=http://127.0.0.1:8010`
in `frontend/.env.local`.

**`npm install` fails with a permissions error**
Close any editor holding files in `frontend/node_modules`, delete that folder,
and try again.

**Nothing renders and the browser console shows module errors**
Delete `frontend/.next` and run `npm run dev` again. This happens if a
production build ran while the dev server was live.

---

## Checking it's all healthy

```powershell
.\start.ps1 -Verify
```

Runs the backend tests (171), frontend tests (54), typecheck, lint and a
production build. Everything should pass.

---

## Where to look first

1. `/dashboard` — the **Audience Pulse** at the top is the whole product in one paragraph. Click **Why?** under it.
2. Click the top topic in Trend Radar → the **Narrative Journey** reconstructs how it spread.
3. `/network` — click any node, or a row in the influence table.
4. `/data` → **Live NLP probe** — paste `Great, another three-hour outage. Amazing service.` and press Analyse.

`docs/DEMO_SCRIPT.md` has a timed 5-minute walkthrough if you're presenting it.
