# Vega — Local AI Coding Assistant

Vega gives you the same interactive coding-agent experience as Claude Code CLI,
but everything runs on your machine — no Anthropic account, no API key, no data
sent anywhere. 100% offline, 100% local.

```bash
vega "create a React todo app and run it"
```

---

## Quick Start (TL;DR)

```bash
# 1 — Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"

# 2 — Set up bonsai inference server
git clone https://github.com/carlosvega20/bonsai_core_001 ~/code/bonsai_core_001
cd ~/code/bonsai_core_001
python3.12 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# 3 — Install vega CLI
git clone https://github.com/carlosvega20/claw-code_001 ~/code/claw-code_001
cd ~/code/claw-code_001 && bash install-vega.sh

# 4 — Add vega to PATH (paste into ~/.zshrc or ~/.bashrc)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
echo '[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"' >> ~/.zshrc
source ~/.zshrc

# 5 — Start the inference server (keep this terminal open, or run in background)
cd ~/code/bonsai_core_001 && bash start.sh

# 6 — Use vega
vega "explain this codebase"
```

---

## How it works

```
vega (shell wrapper)
  │  ANTHROPIC_BASE_URL=http://localhost:9001
  │  ANTHROPIC_API_KEY=bonsai-local
  ▼
claw-vega (Rust CLI — claw-code fork, same UX as claude CLI)
  │  interactive REPL · one-shot · tool calls · sessions
  ▼
bonsai_core_001 (FastAPI REST API, port 9001)
  │  Anthropic-compatible /v1/messages endpoint
  │  automatically routes cloud model names → local inference
  ▼
bonsai-2bit (MLX quantized model, Apple Silicon, fully offline)
```

---

## System Requirements

| Requirement | Version | Notes |
|---|---|---|
| macOS | 12+ | Apple Silicon (M1/M2/M3/M4) strongly recommended for MLX inference |
| Python | **3.11 or 3.12** | System Python (3.9/3.10) will fail. Install via `brew install python@3.12` |
| Rust | stable | Installed by `rustup` — see below |
| curl | any | Used by vega to health-check the server |
| Node.js / npm | optional | Only needed if you ask vega to work on JS/TS projects |

> **Apple Silicon required for offline inference.** The default bonsai-2bit model runs on MLX,
> which is Apple Silicon only. On Intel Macs you can still use vega by running
> an Ollama model (`BONSAI_MODEL=ollama:llama3.2`), but performance will be limited.

---

## Step-by-step Installation

### Step 1 — Install Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# follow the prompts, accept defaults
source "$HOME/.cargo/env"
```

Verify:
```bash
rustc --version   # rustc 1.XX.0 ...
cargo --version   # cargo 1.XX.0 ...
```

Add to your shell profile so `cargo` is available in all future terminals:
```bash
echo '[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"' >> ~/.zshrc
```

### Step 2 — Install Python 3.12 (if not already installed)

```bash
# Check what you have
python3 --version

# If < 3.11, install 3.12 with Homebrew:
brew install python@3.12
```

### Step 3 — Set up bonsai_core_001 (inference server)

```bash
mkdir -p ~/code
git clone https://github.com/carlosvega20/bonsai_core_001 ~/code/bonsai_core_001
cd ~/code/bonsai_core_001

# Create a virtual environment with Python 3.12
python3.12 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Smoke-test that it works (should print status: ok)
python3 -c "from bonsai.models.mlx_backend import MLXBackend; print('MLX ok')"
```

### Step 4 — Build and install vega

```bash
git clone https://github.com/carlosvega20/claw-code_001 ~/code/claw-code_001
cd ~/code/claw-code_001

bash install-vega.sh
# → builds the claw release binary (~30-60s first time)
# → installs vega wrapper to ~/.local/bin/vega
```

### Step 5 — Add to PATH

Add these two lines to your `~/.zshrc` (or `~/.bashrc`):

```bash
export PATH="$HOME/.local/bin:$PATH"
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
```

Reload:
```bash
source ~/.zshrc
```

Verify:
```bash
which vega      # /Users/yourname/.local/bin/vega
vega --version  # Claw Code / Version 0.1.0 ...
```

### Step 6 — Start the inference server

```bash
# In a dedicated terminal (keeps logs visible):
cd ~/code/bonsai_core_001 && bash start.sh

# Or in background:
cd ~/code/bonsai_core_001 && bash start.sh &>/tmp/bonsai.log &
```

Wait 2–3 seconds, then check:
```bash
curl http://localhost:9001/health
# {"status":"ok","mlx":true}
```

### Step 7 — First run

```bash
vega --version          # version check
vega "say hello"        # quick smoke test
```

Inside the REPL:
```
/doctor    ← runs built-in health check — do this first!
/help      ← all slash commands
```

---

## Usage

### Interactive REPL (like `claude` CLI)

```bash
vega
```

Type tasks in plain English. Vega reads your code, edits files, runs commands,
and asks for approval before anything risky.

### One-shot prompt

```bash
vega "create a FastAPI hello-world in this folder"
vega "add unit tests for the User model"
vega "refactor all print() to use logging"
```

### Skip per-tool approval (danger mode)

```bash
vega --dangerously-skip-permissions "scaffold a React project and run it"
```

### Pipe-friendly compact output

```bash
vega --output-format text --compact "summarize this repo" > summary.txt
```

### Resume a previous session

```bash
vega --resume latest
vega --resume path/to/session.jsonl
```

### Run a health check

```
vega
> /doctor
```

---

## Model selection

| Variable | Default | Description |
|---|---|---|
| `BONSAI_MODEL` | `bonsai-2bit` | Inference model (`bonsai-1bit`, `ollama:llama3.2`, etc.) |
| `BONSAI_URL` | `http://localhost:9001` | Address of bonsai_core_001 server |

```bash
BONSAI_MODEL=ollama:llama3.2 vega "task"           # use Ollama instead
BONSAI_URL=http://192.168.1.10:9001 vega "task"    # remote bonsai server
```

Check available models:
```bash
curl -s http://localhost:9001/v1/models | python3 -m json.tool
```

---

## Auto-start bonsai server

To have the server start automatically when you open a terminal, add to `~/.zshrc`:

```bash
# Auto-start bonsai_core_001 if not running
if ! curl -sf http://localhost:9001/health >/dev/null 2>&1; then
    (cd ~/code/bonsai_core_001 && bash start.sh &>/tmp/bonsai.log &)
fi
```

---

## All vega flags

```bash
vega --help
```

| Flag | Description |
|---|---|
| `--dangerously-skip-permissions` | Skip per-tool approval (use in trusted environments) |
| `--output-format text\|json` | Output format for non-interactive mode |
| `--compact` | Print only final assistant text (no tool call details) |
| `--resume SESSION` | Resume a previous session by file path or `latest` |
| `--allowedTools TOOL,...` | Restrict which tools vega can use |
| `--permission-mode MODE` | `read-only`, `workspace-write`, or `danger-full-access` |

---

## Vega vs Claude Code CLI

| | `claude` | `vega` |
|---|---|---|
| Inference | Anthropic cloud | Local bonsai model |
| API key required | Yes (`sk-ant-*`) | No |
| Internet required | Yes | No |
| Model | claude-opus / sonnet / haiku | bonsai-2bit (default) |
| Cost | Per-token billing | Free (your hardware) |
| Privacy | Data sent to Anthropic | Stays on your machine |
| REPL | ✓ | ✓ (identical) |
| Slash commands | ✓ | ✓ (identical) |
| Sessions / resume | ✓ | ✓ (identical) |
| Tool approval flow | ✓ | ✓ (identical) |
| `--output-format` | ✓ | ✓ (identical) |

---

## Troubleshooting

### `vega: bonsai_core_001 is not running`

```bash
cd ~/code/bonsai_core_001 && bash start.sh
```

### `vega: command not found`

```bash
# Check it was installed
ls ~/.local/bin/vega

# Add to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### `cargo: command not found` during install-vega.sh

```bash
source "$HOME/.cargo/env"
# Then re-run:
bash install-vega.sh
```

### MLX import error when starting bonsai server

```bash
# Make sure you're using Python 3.11+ and the venv is active
source ~/code/bonsai_core_001/.venv/bin/activate
python3 --version   # must be 3.11 or 3.12

# If wrong version, recreate venv with explicit Python:
cd ~/code/bonsai_core_001
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Server health check fails (`mlx: false`)

MLX requires Apple Silicon. On Intel Macs, use Ollama:

```bash
# Install Ollama: https://ollama.com
ollama pull llama3.2
BONSAI_MODEL=ollama:llama3.2 vega "task"
```

### Model is slow on the first request

The first request after server startup loads the model weights (~5–10 seconds).
Every request after that is fast. This is expected.

### Check server logs

```bash
tail -f /tmp/bonsai.log    # if started in background
# or read the terminal where you ran: bash start.sh
```

### Rebuild vega after updates

```bash
cd ~/code/claw-code_001 && git pull && bash install-vega.sh
```

---

## Updating

```bash
# Update bonsai server
cd ~/code/bonsai_core_001 && git pull
# restart: bash start.sh

# Update vega CLI
cd ~/code/claw-code_001 && git pull && bash install-vega.sh
```
