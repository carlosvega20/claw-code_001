# Vega — Local AI Coding Assistant

Vega is the `claw-code` CLI pre-configured to run against your local
[bonsai_core_001](https://github.com/carlosvega20/bonsai_core_001) inference
server. It gives you the same interactive coding-agent experience as Claude Code
CLI, but **everything runs on your machine** — no cloud API key, no data sent
to Anthropic, 100% offline.

```
vega "refactor this module to use async/await"
```

---

## How it works

```
vega (shell script)
  │  sets ANTHROPIC_BASE_URL=http://localhost:9001
  │        ANTHROPIC_API_KEY=bonsai-local
  ▼
claw-vega (Rust CLI binary — claw-code fork)
  │  same UX as Claude Code: REPL, one-shot, tool calls, sessions
  ▼
bonsai_core_001 (FastAPI, port 9001)
  │  Anthropic-compat shim — accepts claude-* model names, routes locally
  ▼
bonsai-2bit (MLX, Apple Silicon, fully offline)
```

Vega is identical to `claw` in every way — same flags, same REPL, same tool
approval flow — except it requires no Anthropic account and runs on local
hardware.

---

## Prerequisites

| Requirement | How to get it |
|---|---|
| macOS (Apple Silicon recommended) | — |
| Rust toolchain | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` |
| bonsai_core_001 server | see below |
| Bonsai model files | bundled with bonsai_core_001 |

### Install Rust (if not already installed)

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"
```

### Set up bonsai_core_001

```bash
# Clone (if you don't have it)
git clone https://github.com/carlosvega20/bonsai_core_001 ~/code/bonsai_core_001

# Create the virtual environment and install dependencies
cd ~/code/bonsai_core_001
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

---

## Installation

```bash
# Clone this repo (if you don't have it)
git clone https://github.com/carlosvega20/claw-code_001 ~/code/claw-code_001
cd ~/code/claw-code_001

# Build claw and install vega to ~/.local/bin
bash install-vega.sh
```

Add `~/.local/bin` to your PATH if it isn't already (add to `~/.zshrc` or `~/.bashrc`):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Reload your shell:

```bash
source ~/.zshrc   # or source ~/.bashrc
```

Verify:

```bash
vega --version
```

### Install options

```bash
bash install-vega.sh                        # release build → ~/.local/bin/vega
bash install-vega.sh --prefix /usr/local    # installs to /usr/local/bin/vega
bash install-vega.sh --debug                # debug build (faster compile)
bash install-vega.sh --no-build             # skip cargo, use existing binary
```

---

## Starting the bonsai server

Vega requires `bonsai_core_001` to be running before you use it. Start it in
a separate terminal (or as a background service):

```bash
cd ~/code/bonsai_core_001
bash start.sh
```

The server starts on `http://localhost:9001`. Vega checks that it's up before
every invocation and prints a clear error with instructions if it's not.

### Auto-start (optional)

To have the server start automatically when you log in, add this to your shell
profile (`~/.zshrc` or `~/.bashrc`):

```bash
# Auto-start bonsai_core_001 if not running
if ! curl -sf http://localhost:9001/health >/dev/null 2>&1; then
    (cd ~/code/bonsai_core_001 && bash start.sh &>/tmp/bonsai_core.log &)
fi
```

---

## Usage

### Interactive REPL

```bash
vega
```

You get a full interactive agent session — type tasks, approve tool calls, use
slash commands. Type `/help` inside the REPL for all commands.

### One-shot prompt

```bash
vega "explain the main function in main.py"
vega "write a unit test for the User model"
vega "add error handling to the API endpoints"
```

### Skip tool-call approval prompts

```bash
vega --dangerously-skip-permissions "refactor all print statements to use logging"
```

### Compact output (pipe-friendly)

```bash
vega --output-format text --compact "summarize this repo" > summary.txt
```

### Resume a previous session

```bash
vega --resume latest              # continue the most recent session
vega --resume SESSION.jsonl       # continue a specific session file
```

### Run a health check

```bash
vega
/doctor
```

---

## Model selection

Vega routes all requests to your local bonsai inference server. The model that
runs is controlled by the server, not the client.

| Environment variable | Default | Description |
|---|---|---|
| `BONSAI_URL` | `http://localhost:9001` | Address of the bonsai server |
| `BONSAI_MODEL` | `bonsai-2bit` | Inference model to use |

```bash
# Use a different local model
BONSAI_MODEL=bonsai-1bit vega "task"
BONSAI_MODEL=ollama:llama3.2 vega "task"

# Point vega at a bonsai server on another machine
BONSAI_URL=http://192.168.1.42:9001 vega "task"
```

Available models depend on what bonsai_core_001 has configured. Check:

```bash
curl http://localhost:9001/v1/models | python3 -m json.tool
```

---

## All supported flags

Vega passes all flags directly to claw. Full flag reference:

```bash
vega --help
```

Common flags:

| Flag | Description |
|---|---|
| `--model MODEL` | Override model name shown in UI (does not change inference backend) |
| `--output-format text\|json` | Output format for non-interactive mode |
| `--compact` | Strip tool call details, print only final text |
| `--dangerously-skip-permissions` | Skip per-tool approval prompts |
| `--permission-mode MODE` | `read-only`, `workspace-write`, or `danger-full-access` |
| `--allowedTools TOOL,...` | Restrict which tools can be used |
| `--resume SESSION` | Resume a previous session |

---

## Slash commands (inside the REPL)

| Command | Description |
|---|---|
| `/help` | List all slash commands |
| `/doctor` | Health check — auth, config, tools, sandbox |
| `/compact` | Compress the current session context |
| `/clear` | Clear the conversation and start fresh |
| `/status` | Show current session state |

---

## Differences from Claude Code CLI

| Feature | `claude` (Claude Code) | `vega` (this) |
|---|---|---|
| Inference | Anthropic cloud | Local bonsai model |
| API key | Required (`sk-ant-*`) | Not needed |
| Internet | Required | Not required |
| Model | claude-opus / sonnet / haiku | bonsai-2bit (default) |
| Tool calls | Cloud-executed | Local, same approval flow |
| Sessions | Stored locally | Stored locally (same format) |
| Cost | Per-token billing | Free (local compute) |
| Privacy | Data sent to Anthropic | Stays on your machine |

Everything else is identical: REPL, flags, slash commands, session files,
`/doctor`, tool approval, `--output-format`, `--resume`, and all other
CLI features.

---

## Troubleshooting

### `vega: bonsai_core_001 is not running`

```bash
cd ~/code/bonsai_core_001 && bash start.sh
```

### `vega: claw binary not found`

```bash
cd ~/code/claw-code_001 && bash install-vega.sh
```

### Model is slow or timing out

The first request after server startup is slower (model loading). Subsequent
requests are fast. If it's consistently slow, check the server logs:

```bash
tail -f /tmp/bonsai_core.log
```

### Check server health manually

```bash
curl http://localhost:9001/health
# {"status":"ok","mlx":true}
```

### Rebuilding after code changes

```bash
cd ~/code/claw-code_001 && bash install-vega.sh --no-build   # reinstall wrapper only
cd ~/code/claw-code_001 && bash install-vega.sh               # full rebuild + install
```

---

## Updating

```bash
cd ~/code/claw-code_001
git pull
bash install-vega.sh

cd ~/code/bonsai_core_001
git pull
# restart the server: bash start.sh
```
