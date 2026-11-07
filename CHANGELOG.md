# Changelog

All notable changes to the Cursor Emacs Integration project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-11-06

### Added

#### Core Features (Phase 1)
- Initial implementation of cursor-mode.el with basic agent commands
- HTTP/WebSocket bridge service in Node.js/TypeScript
- Session management (create, resume, list, delete)
- Agent communication via REST API
- Basic cursor-bridge.el for HTTP and WebSocket communication
- Health check endpoint for bridge service
- Session persistence using SQLite

#### Chat Interface (Phase 2)
- Dedicated chat buffer with cursor-chat-mode
- Markdown rendering in chat messages
- Code block syntax highlighting
- Apply/Copy buttons for code suggestions
- Chat history persistence
- Real-time message updates via WebSocket
- Chat export to markdown files
- Multi-session support with session switching

#### File Synchronization
- cursor-sync.el with bidirectional sync
- Debounced change detection (500ms default)
- WebSocket-based real-time updates
- Conflict detection and resolution
- Multiple conflict resolution strategies (ask, emacs, agent, diff)
- File watching with chokidar in bridge service
- Change origin tracking to prevent sync loops
- Configurable sync patterns and ignore lists

#### Commands
- `cursor-ask-agent` - Ask agent with prompt
- `cursor-fix-at-point` - Fix issue at cursor
- `cursor-explain-region` - Explain selected code
- `cursor-refactor-region` - Refactor code
- `cursor-optimize-function` - Optimize function
- `cursor-generate-tests` - Generate test cases
- `cursor-generate-docstring` - Generate documentation
- `cursor-start-session` - Create new session
- `cursor-resume-session` - Resume existing session
- `cursor-list-sessions` - List all sessions
- `cursor-end-session` - End current session
- `cursor-open-chat` - Open chat interface
- `cursor-sync-push` - Push buffer to agent
- `cursor-sync-pull` - Pull changes from agent
- `cursor-sync-status` - Check sync status

#### Configuration
- Customizable API endpoint and WebSocket URL
- Configurable default model
- Adjustable sync debounce delay
- Maximum file size limits
- Ignore patterns for sync
- Chat window positioning options
- Authentication via auth-source

#### Doom Emacs Integration
- Native Doom module structure
- Leader key bindings (SPC c prefix)
- Evil mode keybindings (g a, g f, g e, g c)
- Which-key integration
- Popup window rules
- Example configurations

#### Documentation
- Comprehensive README with installation instructions
- Architecture design document
- Example configurations for Doom and vanilla Emacs
- API reference
- Troubleshooting guide

#### Development Tools
- TypeScript configuration
- ESLint and Prettier setup
- Example .env file
- .gitignore for both Emacs and Node.js
- Package metadata for MELPA compatibility

### Technical Details

#### Bridge Service
- Express.js HTTP server on port 8765
- WebSocket server using ws library
- Agent SDK client wrapper (simulated for v0.1.0)
- Session store with SQLite
- File sync manager with chokidar
- CORS enabled for cross-origin requests
- Error handling and retry logic

#### Elisp Modules
- cursor-mode.el: Main interface (480 lines)
- cursor-chat.el: Chat UI (450 lines)
- cursor-sync.el: File sync (380 lines)
- cursor-bridge.el: Communication (240 lines)
- Total: ~1,550 lines of Elisp

#### Dependencies
- Emacs 27.1+
- Node.js 18.0+
- websocket.el 1.13+
- markdown-mode 2.5+
- request.el 0.3.2+

## [Unreleased]

### Planned for 0.2.0 (Phase 3)
- Real Agent SDK integration (replace simulation)
- MCP support for local models
- Advanced context gathering
- Project-wide operations
- Code navigation integration
- Subscription support for CI/PR events

### Planned for 0.3.0 (Phase 4)
- Context-aware commands
- Framework detection
- Popup UI with posframe
- Modeline status indicator
- Performance optimizations
- Telemetry and analytics

### Planned for 0.4.0 (Phase 5)
- MELPA submission
- Video tutorials
- Comprehensive test suite
- Benchmarking tools
- Migration guides

## [0.0.1] - 2026-11-01

### Added
- Initial project structure
- Design document
- Architecture planning
