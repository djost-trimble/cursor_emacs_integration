# Cursor Emacs Bridge Service

A Python-based bridge service that connects Emacs to the Cursor Agent SDK, providing real-time AI assistance within Emacs.

## Features

- **HTTP REST API** for session management and agent communication
- **WebSocket Server** for real-time file synchronization
- **SQLite Storage** for session persistence
- **File Watching** with automatic change detection
- **Agent SDK Integration** for Cursor AI capabilities

## Quick Start

### Installation

Install [uv](https://github.com/astral-sh/uv) if not already installed:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Setup

```bash
# Create virtual environment and install dependencies
uv venv
source .venv/bin/activate
uv pip install -e .
```

### Configuration

Copy the example environment file:

```bash
cp .env.example .env
```

Edit `.env` and set your Cursor API key:

```env
CURSOR_API_KEY=your_api_key_here
```

### Run

Start the bridge service:

```bash
./start.sh
```

Or manually:

```bash
python3 server.py
```

The service will start on:
- HTTP: `http://localhost:8765`
- WebSocket: `ws://localhost:8765`

## API Endpoints

### Sessions
- `POST /api/sessions/create` - Create new agent session
- `POST /api/sessions/:id/resume` - Resume existing session
- `GET /api/sessions` - List all sessions
- `DELETE /api/sessions/:id` - Delete session

### Agent
- `POST /api/agent/ask` - Send message to agent
- `POST /api/agent/apply-edit` - Apply agent's code edit
- `GET /api/agent/status` - Get agent status

### Sync
- `POST /api/sync/enable` - Enable file watching
- `POST /api/sync/disable` - Disable file watching

### Config
- `GET /api/config` - Get configuration
- `PUT /api/config` - Update configuration

## WebSocket Events

### Client → Server
- `buffer-changed` - Notify buffer was modified in Emacs
- `subscribe-file` - Subscribe to file changes
- `unsubscribe-file` - Unsubscribe from file changes
- `ping` - Keep-alive ping

### Server → Client
- `connected` - Connection established
- `file-changed` - File was modified on disk
- `agent-message` - Agent sent a message
- `pong` - Response to ping

## Development

Install with dev dependencies:

```bash
uv pip install -e ".[dev]"
```

Run tests:

```bash
pytest
```

Format code:

```bash
black .
ruff check .
```

## Requirements

- Python 3.8+
- uv (recommended) or pip

## License

MIT License - see parent repository for details
