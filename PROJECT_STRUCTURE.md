# Project Structure

This document describes the complete structure of the Cursor Emacs Integration package.

## Directory Layout

```
package/
├── elisp/                      # Emacs Lisp modules
│   ├── cursor-mode.el          # Main interface (319 lines)
│   ├── cursor-chat.el          # Chat UI (343 lines)
│   ├── cursor-sync.el          # File synchronization (309 lines)
│   ├── cursor-bridge.el        # Communication layer (230 lines)
│   └── cursor-pkg.el           # Package metadata (14 lines)
│
├── bridge/                     # Node.js/TypeScript bridge service
│   ├── src/
│   │   ├── index.ts            # Main server (348 lines)
│   │   ├── agent-client.ts     # Agent SDK wrapper (167 lines)
│   │   ├── sync-manager.ts     # File watching (138 lines)
│   │   ├── session-store.ts    # SQLite persistence (85 lines)
│   │   └── types.ts            # TypeScript types (72 lines)
│   ├── package.json            # Node dependencies
│   ├── tsconfig.json           # TypeScript config
│   ├── .env.example            # Environment template
│   └── start.sh                # Startup script
│
├── examples/                   # Configuration examples
│   ├── doom-config.el          # Doom Emacs setup
│   └── vanilla-emacs-config.el # Vanilla Emacs setup
│
├── README.md                   # Main documentation
├── QUICKSTART.md              # Quick start guide
├── CHANGELOG.md               # Version history
├── LICENSE                    # MIT license
├── PROJECT_STRUCTURE.md       # This file
└── .gitignore                 # Git ignore rules
```

## Code Statistics

### Emacs Lisp Modules (1,215 lines total)

| File | Lines | Description |
|------|-------|-------------|
| cursor-chat.el | 343 | Chat interface with markdown rendering |
| cursor-mode.el | 319 | Main commands and session management |
| cursor-sync.el | 309 | Bidirectional file synchronization |
| cursor-bridge.el | 230 | HTTP/WebSocket communication |
| cursor-pkg.el | 14 | Package metadata |

### TypeScript Bridge Service (810 lines total)

| File | Lines | Description |
|------|-------|-------------|
| index.ts | 348 | Express server and WebSocket setup |
| agent-client.ts | 167 | Agent SDK client wrapper |
| sync-manager.ts | 138 | File watching with chokidar |
| session-store.ts | 85 | SQLite session persistence |
| types.ts | 72 | TypeScript type definitions |

### Total Project Size

- **Elisp Code**: 1,215 lines
- **TypeScript Code**: 810 lines
- **Documentation**: 400+ lines (README, QUICKSTART, CHANGELOG)
- **Examples**: 500+ lines (configuration examples)
- **Total**: ~2,900 lines

## Component Responsibilities

### Elisp Layer

#### cursor-mode.el
- Global and buffer-local minor mode
- Session creation and management
- Command implementations (ask, fix, explain, refactor, etc.)
- Context gathering
- Keybindings and integration
- API key management via auth-source

#### cursor-chat.el
- Dedicated chat major mode
- Message history management
- Markdown rendering with code blocks
- Syntax highlighting in code blocks
- Apply/copy buttons for code suggestions
- WebSocket message handling
- Chat export functionality
- Multi-session support

#### cursor-sync.el
- Bidirectional file synchronization
- Change tracking with version counters
- Debounced sync (500ms default)
- Conflict detection and resolution
- Multiple resolution strategies (ask, emacs, agent, diff)
- File size and pattern filtering
- WebSocket integration for real-time updates

#### cursor-bridge.el
- HTTP client using url.el
- WebSocket client using websocket.el
- Request/response handling
- JSON encoding/decoding
- Retry logic with exponential backoff
- Health check utilities
- Callback registration system

### Bridge Service Layer

#### index.ts
- Express.js HTTP server
- WebSocket server setup
- REST API endpoints (/api/sessions/*, /api/agent/*, /api/sync/*)
- Request routing and middleware
- CORS configuration
- Graceful shutdown handling
- Configuration management

#### agent-client.ts
- Agent SDK wrapper (simulated in v0.1.0)
- Session lifecycle management
- Message sending and streaming
- Response handling
- Simulated agent responses for testing

#### sync-manager.ts
- File watching with chokidar
- Change origin tracking (emacs vs agent)
- File version management
- WebSocket broadcasting
- Ignore pattern matching
- Workspace monitoring

#### session-store.ts
- SQLite database interface
- Session CRUD operations
- Persistence across restarts
- Last active timestamp tracking
- Context serialization

#### types.ts
- TypeScript interfaces
- Type definitions for all data structures
- Configuration types
- Message types for WebSocket/HTTP

## API Surface

### Emacs Commands (20 total)

**Agent Operations:**
- cursor-ask-agent
- cursor-fix-at-point
- cursor-explain-region
- cursor-refactor-region
- cursor-optimize-function
- cursor-generate-tests
- cursor-generate-docstring

**Session Management:**
- cursor-start-session
- cursor-resume-session
- cursor-end-session
- cursor-list-sessions

**Chat Interface:**
- cursor-open-chat
- cursor-chat-send-message
- cursor-chat-clear
- cursor-chat-export

**File Synchronization:**
- cursor-sync-push
- cursor-sync-pull
- cursor-sync-status
- cursor-sync-resolve-keep-emacs
- cursor-sync-resolve-keep-agent

### REST API Endpoints (11 total)

**Session Management:**
- POST /api/sessions/create
- POST /api/sessions/:id/resume
- GET /api/sessions
- DELETE /api/sessions/:id

**Agent Operations:**
- POST /api/agent/ask
- POST /api/agent/apply-edit
- GET /api/agent/status

**File Synchronization:**
- POST /api/sync/enable
- POST /api/sync/disable

**Configuration:**
- GET /api/config
- PUT /api/config

### WebSocket Messages (8 types)

**Client → Server:**
- buffer-changed
- subscribe-file
- unsubscribe-file
- ping

**Server → Client:**
- agent-message
- agent-edit
- file-changed
- sync-conflict
- connected
- pong

## Configuration Variables

### Cursor Mode (7 variables)
- cursor-api-endpoint
- cursor-websocket-endpoint
- cursor-default-model
- cursor-auto-start-session
- cursor-api-key
- cursor-bridge-timeout
- cursor-bridge-max-retries

### Cursor Sync (5 variables)
- cursor-sync-debounce-delay
- cursor-sync-max-size
- cursor-sync-ignore-patterns
- cursor-sync-on-conflict
- cursor-sync-auto-enable

### Cursor Chat (4 variables)
- cursor-chat-window-side
- cursor-chat-window-width
- cursor-chat-save-history
- cursor-chat-history-file

## Dependencies

### Emacs Packages
- websocket.el (1.13+) - WebSocket client
- markdown-mode (2.5+) - Markdown rendering
- request.el (0.3.2+) - HTTP client (optional)

### Node.js Packages
- express (^4.18.2) - HTTP server
- ws (^8.14.2) - WebSocket server
- chokidar (^3.5.3) - File watching
- better-sqlite3 (^9.2.2) - SQLite database
- cors (^2.8.5) - CORS middleware
- diff (^5.1.0) - Diff generation
- dotenv (^16.3.1) - Environment variables

### Development Dependencies
- TypeScript (^5.3.2)
- ts-node (^10.9.1)
- jest (^29.7.0)
- @types/* packages

## Key Features Implemented

### Phase 1: Foundation ✓
- [x] Bridge service with HTTP API
- [x] HTTP/WebSocket communication
- [x] Session management
- [x] Basic agent commands
- [x] Health checks
- [x] Session persistence

### Phase 2: Chat Enhancement ✓
- [x] Dedicated chat buffer
- [x] Markdown rendering
- [x] Code block highlighting
- [x] Apply/copy buttons
- [x] Session switching
- [x] Chat history
- [x] Export functionality

### Phase 3: File Synchronization (Partial) ✓
- [x] Bidirectional sync
- [x] WebSocket real-time updates
- [x] Conflict detection
- [x] Conflict resolution UI
- [x] File watching
- [x] Change origin tracking
- [ ] Operational transform (basic version implemented)

## Testing Status

### Implemented
- Basic HTTP endpoint testing
- WebSocket connection testing
- Session CRUD operations
- Sync change tracking

### Planned
- Unit tests for all Elisp functions
- Integration tests for bridge service
- End-to-end workflow tests
- Performance benchmarks
- Error recovery tests

## MELPA Compatibility

The package structure follows MELPA guidelines:

- ✓ Single-file or multi-file package structure
- ✓ Package headers with metadata
- ✓ Proper dependencies declared
- ✓ Commentary section
- ✓ Autoload cookies
- ✓ Group and custom variables
- ✓ No external file dependencies
- ✓ GPL-compatible license (MIT)

## Next Development Phases

### Phase 3 (Remaining)
- Real Agent SDK integration
- MCP support for local models
- Advanced context gathering
- Project-wide operations

### Phase 4
- Popup UI with posframe
- Modeline integration
- Performance optimization
- Telemetry

### Phase 5
- MELPA submission
- Comprehensive test suite
- Video tutorials
- Migration tools

## Architecture Decisions

### Why a Bridge Service?
- Handles complex Agent SDK authentication
- Maintains persistent WebSocket connections
- Manages session state across Emacs restarts
- Abstracts API versioning
- Provides native file watching performance

### Why SQLite for Sessions?
- Persistent across restarts
- No external database required
- Simple setup
- Sufficient performance for session data

### Why Separate Elisp Modules?
- Clear separation of concerns
- Easier testing and maintenance
- Optional feature loading
- Better code organization

### Sync Strategy: Debounce + Version Tracking
- Reduces network overhead
- Prevents race conditions
- Allows conflict detection
- Balances responsiveness and efficiency

## File Size Limits

- Maximum sync file size: 10MB (configurable)
- Maximum chat message: 10MB (JSON limit)
- Database file: No limit (grows with sessions)
- Log files: Rotated by system (not implemented in v0.1.0)

## Performance Characteristics

- Sync debounce: 500ms (configurable)
- HTTP timeout: 30s
- WebSocket reconnect: Exponential backoff (1s, 2s, 4s)
- File watch stability: 100ms
- Session query: <10ms (SQLite)

## Security Considerations

- API keys stored in auth-source (encrypted)
- No credentials in logs
- CORS enabled (localhost only by default)
- No automatic code execution
- User confirmation for applies
- WebSocket origin validation (TODO)

## Known Limitations (v0.1.0)

1. Agent SDK is simulated (not real Cursor API)
2. No MCP support for local models
3. Basic operational transform (not full OT)
4. No automatic reconnection for HTTP
5. Limited error recovery
6. No telemetry or analytics
7. No popup UI (uses side windows)
8. No modeline indicator yet

## Upgrade Path

The architecture supports future enhancements:
- Agent SDK: Drop-in replacement in agent-client.ts
- MCP: Add mcp-client.ts, minimal changes needed
- OT: Enhanced change tracking in cursor-sync.el
- UI: New cursor-popup.el module
- Modeline: Hook into doom-modeline or standard mode-line-format

## Documentation Coverage

- [x] README with installation
- [x] Quick start guide
- [x] Architecture design
- [x] Example configurations
- [x] API reference (in design doc)
- [x] Changelog
- [x] License
- [x] This structure document
- [ ] Video tutorial (planned)
- [ ] Troubleshooting FAQ (basic in README)

## Build and Distribution

### Local Development
```bash
# Bridge
cd bridge && npm install && npm run dev

# Emacs
M-x load-file cursor-mode.el
```

### Production Build
```bash
# Bridge
cd bridge && npm run build

# Emacs
M-x byte-recompile-directory
```

### Distribution
- MELPA: Planned for v1.0
- Manual: Clone + load-path
- Doom: Local package recipe
- Straight.el: GitHub URL

This structure is designed for maintainability, extensibility, and eventual distribution through MELPA.
