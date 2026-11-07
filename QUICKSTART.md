# Quick Start Guide

Get up and running with Cursor Emacs Integration in 5 minutes.

## Prerequisites

- Emacs 27.1+ 
- Python 3.8+
- [uv](https://github.com/astral-sh/uv) - Fast Python package installer
- Doom Emacs (optional but recommended)

## Installation Steps

### 1. Install uv

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### 2. Install Bridge Service

```bash
cd /path/to/package/bridge
uv venv
source .venv/bin/activate
uv pip install -e .
```

### 3. Configure API Key

```bash
cp .env.example .env
```

Edit `.env` and add your Cursor API key:
```
CURSOR_API_KEY=your_key_here
```

### 4. Install Emacs Package

#### Doom Emacs

Add to `~/.doom.d/packages.el`:
```elisp
(package! cursor-mode
  :recipe (:local-repo "/path/to/package/elisp"))
```

Add to `~/.doom.d/config.el`:
```elisp
(use-package! cursor-mode
  :config
  (global-cursor-mode 1))
```

Run:
```bash
doom sync
```

#### Vanilla Emacs

Add to `~/.emacs.d/init.el`:
```elisp
(add-to-list 'load-path "/path/to/package/elisp")
(require 'cursor-mode)
(global-cursor-mode 1)
```

### 5. Start Bridge Service

```bash
cd /path/to/package/bridge
./start.sh
```

Or manually:
```bash
source .venv/bin/activate
python3 server.py
```

### 6. Test in Emacs

Restart Emacs, then:

1. Open a code file
2. Press `SPC c k` (or `M-x cursor-ask-agent`)
3. Type: "Explain this file"
4. Watch the magic happen!

## Common Commands

| Key | Command | Description |
|-----|---------|-------------|
| `SPC c k` | cursor-ask-agent | Ask anything |
| `SPC c c` | cursor-open-chat | Open chat window |
| `SPC c f` | cursor-fix-at-point | Fix code at cursor |
| `SPC c e` | cursor-explain-region | Explain selection |

(Replace `SPC` with `C-c` for vanilla Emacs)

## Troubleshooting

**Bridge not connecting?**
```bash
curl http://localhost:8765/health
```
Should return `{"status":"ok",...}`

**WebSocket issues?**
```elisp
M-x cursor-bridge-check-health
```

**Session not starting?**
Check bridge logs in the terminal where you ran `npm start`

## Next Steps

- Read the [full README](README.md)
- Check [example configurations](examples/)
- See [architecture design](../docs/emacs-integration-design.md)

## Getting Help

- Check logs: Bridge terminal output
- Test connectivity: `curl http://localhost:8765/health`
- Verify WebSocket: `M-x cursor-bridge-check-health`
- Review configuration: `M-x describe-variable cursor-`

Enjoy AI-powered Emacs! 🚀
