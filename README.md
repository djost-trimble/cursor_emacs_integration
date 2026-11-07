# Cursor Emacs Integration

A comprehensive Doom Emacs package that integrates Cursor's AI agent system directly into Emacs, providing powerful AI-assisted development capabilities.

## Features

- **AI-Powered Assistance**: Ask questions, get explanations, and request code improvements
- **Chat Interface**: Dedicated chat buffer with markdown rendering and syntax highlighting
- **Bidirectional Sync**: Real-time file synchronization between Emacs and agents
- **Session Management**: Create, resume, and manage multiple agent sessions
- **Cloud Context Integration**: Access and import sessions from Cursor web UI
- **Conflict Resolution**: Smart handling of concurrent edits
- **WebSocket Support**: Real-time updates and notifications
- **Doom Integration**: Native Doom Emacs module with evil-mode keybindings

## Architecture

```
┌─────────────────────────────────────┐
│         Doom Emacs Layer            │
│  ┌──────────┐  ┌────────────────┐  │
│  │ cursor-  │  │ cursor-chat.el │  │
│  │ mode.el  │  │ cursor-sync.el │  │
│  └────┬─────┘  └────────┬───────┘  │
│       │   cursor-bridge.el  │       │
└───────┼─────────────────────┼───────┘
        │         HTTP/WS     │
┌───────┴─────────────────────┴───────┐
│    Cursor Bridge Service (Python)   │
│  ┌──────────┐  ┌────────────────┐  │
│  │  HTTP    │  │   WebSocket    │  │
│  │  Server  │  │   Server       │  │
│  └────┬─────┘  └────────┬───────┘  │
│       └─────────┬────────┘          │
│          Agent SDK Client           │
└─────────────────┬───────────────────┘
                  │
        ┌─────────┴─────────┐
        │  Cursor Cloud     │
        │  Agent System     │
        └───────────────────┘
```

## Installation

### Prerequisites

- Emacs 27.1 or later
- Python 3.8 or later
- [uv](https://github.com/astral-sh/uv) - Fast Python package installer
- Doom Emacs (recommended) or vanilla Emacs

### Step 1: Install uv (if not already installed)

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Or visit [uv installation docs](https://github.com/astral-sh/uv#installation) for other methods.

### Step 2: Install the Bridge Service

```bash
cd /path/to/package/bridge
uv venv
source .venv/bin/activate
uv pip install -e .
```

Or simply use the startup script which handles everything:

```bash
cd /path/to/package/bridge
./start.sh
```

### Step 3: Configure Environment

Create a `.env` file in the bridge directory:

```bash
cp .env.example .env
```

Edit `.env` and add your Cursor API key:

```
CURSOR_API_KEY=your_api_key_here
CURSOR_ENDPOINT=https://cursor.com/api
HTTP_PORT=8765
WS_PORT=8766
```

### Step 4: Install Emacs Package

#### For Doom Emacs

1. Add to `~/.doom.d/packages.el`:

```elisp
(package! cursor-mode
  :recipe (:local-repo "/path/to/package/elisp"))
```

2. Add to `~/.doom.d/config.el`:

```elisp
(use-package! cursor-mode
  :config
  (global-cursor-mode 1)
  
  ;; Keybindings
  (map! :leader
        (:prefix ("a" . "cursor agent")
         :desc "Ask agent" "a" #'cursor-ask-agent
         :desc "Open chat" "c" #'cursor-open-chat
         :desc "Fix at point" "f" #'cursor-fix-at-point
         :desc "Explain region" "e" #'cursor-explain-region
         :desc "Refactor region" "R" #'cursor-refactor-region
         :desc "Start session" "s" #'cursor-start-session
         :desc "List sessions" "l" #'cursor-list-sessions)))
```

3. Run: `doom sync`

#### For Vanilla Emacs

Add to your `init.el`:

```elisp
(add-to-list 'load-path "/path/to/package/elisp")
(require 'cursor-mode)
(global-cursor-mode 1)
```

### Step 5: Start the Bridge Service

```bash
cd /path/to/package/bridge
./start.sh
```

Or manually:

```bash
source .venv/bin/activate
python3 server.py
```

## Usage

### Basic Commands

- `M-x cursor-ask-agent` (C-c a a): Ask the agent a question
- `M-x cursor-open-chat` (C-c a c): Open the chat interface
- `M-x cursor-fix-at-point` (C-c a f): Fix issue at cursor
- `M-x cursor-explain-region` (C-c a e): Explain selected code
- `M-x cursor-refactor-region` (C-c a R): Refactor selected code

### Session Management

- `M-x cursor-start-session` (C-c a s): Create new session
- `M-x cursor-resume-session` (C-c a r): Resume existing session
- `M-x cursor-list-sessions` (C-c a l): List all sessions
- `M-x cursor-end-session` (C-c a q): End current session

### Cloud Context Integration

- `M-x cursor-list-cloud-sessions` (C-c a C L): List cloud sessions from Cursor web UI
- `M-x cursor-import-cloud-session` (C-c a C I): Import a cloud session locally
- `M-x cursor-sync-to-cloud` (C-c a C S): Upload local session to cloud

### File Synchronization

- `M-x cursor-sync-push` (C-c a p): Push buffer to agent
- `M-x cursor-sync-pull` (C-c a P): Pull changes from agent
- `M-x cursor-sync-status` (C-c a S): Check sync status

### Evil Mode Keybindings

In normal mode:
- `g a`: Ask agent
- `g f`: Fix at point
- `g e`: Explain
- `g c`: Open chat

In visual mode:
- `g a`: Ask about selection
- `g e`: Explain selection
- `g r`: Refactor selection

## Configuration

### Customize Variables

```elisp
;; API configuration
(setq cursor-api-endpoint "http://localhost:8765"
      cursor-websocket-endpoint "ws://localhost:8765"
      cursor-default-model "claude-4-sonnet")

;; Sync configuration
(setq cursor-sync-debounce-delay 0.5
      cursor-sync-max-size (* 10 1024 1024)
      cursor-sync-on-conflict 'ask)

;; Chat configuration
(setq cursor-chat-window-side 'right
      cursor-chat-window-width 80
      cursor-chat-save-history t)
```

### Authentication

The Cursor API key is required for cloud context integration features. Store your API key securely:

#### Method 1: Environment Variable (.env file)

Add to `bridge/.env`:

```bash
CURSOR_API_KEY=your_api_key_here
```

#### Method 2: Auth-source (Emacs)

1. Create `~/.authinfo.gpg`:

```
machine cursor-api password your_api_key_here
```

2. Or use macOS keychain:

```bash
security add-generic-password -a $USER -s cursor-api -w "your_api_key_here"
```

#### Getting Your API Key

1. Log in to [Cursor web UI](https://cursor.com)
2. Navigate to Settings → API Keys
3. Generate a new API key
4. Copy and store it securely using one of the methods above

**Note**: The API key is required for cloud features (listing, importing sessions, syncing to cloud). Local sessions work without an API key.

## Examples

### Ask About Code

```elisp
;; Select a function and run:
M-x cursor-explain-region
```

The agent will explain the code in the chat window.

### Refactor Code

```elisp
;; Select code and run:
M-x cursor-refactor-region
```

The agent will suggest improvements with apply/copy buttons.

### Generate Tests

```elisp
;; Position cursor in a function and run:
M-x cursor-generate-tests
```

The agent will generate comprehensive test cases.

### Import Cloud Session

```elisp
;; List your cloud sessions:
M-x cursor-list-cloud-sessions

;; In the cloud sessions buffer:
;; Press RET or 'i' on a session to import it
;; Press 'c' to view context
;; Press 'h' to view history
;; Press 'r' to refresh the list

;; Or import directly by ID:
M-x cursor-import-cloud-session RET cloud-session-id
```

The cloud session will be imported as a local session with all context and history.

### Sync Local Session to Cloud

```elisp
;; Upload your current local session to the cloud:
M-x cursor-sync-to-cloud
```

This creates a backup of your local session in the Cursor cloud (if the API supports it).

## Troubleshooting

### Bridge Service Not Connecting

1. Check if the service is running:
   ```bash
   curl http://localhost:8765/health
   ```

2. Check logs in the bridge terminal

3. Verify WebSocket connection:
   ```elisp
   M-x cursor-bridge-check-health
   ```

### WebSocket Connection Issues

1. Ensure firewall allows connections to ports 8765
2. Check browser console for errors (if using web-based Emacs)
3. Restart the bridge service

### Sync Conflicts

If you encounter frequent conflicts:

```elisp
;; Set automatic conflict resolution
(setq cursor-sync-on-conflict 'emacs)  ; Always keep Emacs version

;; Or increase debounce delay
(setq cursor-sync-debounce-delay 1.0)
```

## Development

### Running Tests

Bridge service:
```bash
cd bridge
source .venv/bin/activate
uv pip install -e ".[dev]"
python3 -m pytest
```

Emacs (requires ERT):
```elisp
M-x ert RET cursor-
```

### Building

Byte-compile Elisp:
```elisp
M-x byte-recompile-directory RET /path/to/elisp RET
```

## API Reference

See the [design document](../docs/emacs-integration-design.md) for detailed API specifications.

### Cloud API Implementation

The cloud context integration implements a reasonable API design based on expected Cursor cloud functionality. The API endpoints may need updates when official Cursor cloud APIs are documented:

**Implemented Endpoints:**
- `GET /cloud/sessions` - List user's cloud sessions
- `GET /cloud/sessions/{id}/context` - Fetch session context
- `GET /cloud/sessions/{id}/history` - Get session history and files
- `POST /cloud/sessions` - Upload local session to cloud

**Bridge Service Endpoints:**
- `GET /api/cloud/sessions` - List cloud sessions (with limit/offset)
- `GET /api/cloud/sessions/{id}/context` - Get session context
- `POST /api/sessions/import/{cloud_id}` - Import cloud session locally
- `POST /api/sessions/{id}/sync-to-cloud` - Upload session to cloud

All cloud operations require `CURSOR_API_KEY` authentication. The implementation gracefully handles API errors and provides fallback responses.

## Contributing

Contributions are welcome! Please:

1. Follow existing code style
2. Add tests for new features
3. Update documentation
4. Submit pull requests to the main repository

## License

MIT License - see LICENSE file for details

## Credits

Built with:
- [Cursor Agent SDK](https://cursor.com/docs/bdk)
- [websocket.el](https://github.com/ahyatt/emacs-websocket)
- [markdown-mode](https://jblevins.org/projects/markdown-mode/)
- [Doom Emacs](https://github.com/doomemacs/doomemacs)

## Support

- Documentation: See `docs/` directory
- Issues: GitHub issues
- Chat: Cursor community Discord
