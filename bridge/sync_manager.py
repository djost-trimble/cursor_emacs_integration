"""File synchronization manager using watchdog."""

import os
import time
from typing import Dict, Set, Literal, Any
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler, FileModifiedEvent


class SyncManager:
    """Manages file watching and synchronization."""

    def __init__(self, socketio):
        """Initialize sync manager with SocketIO instance."""
        self.socketio = socketio
        self.watchers: Dict[str, Observer] = {}
        self.change_origins: Dict[str, Literal['emacs', 'agent']] = {}
        self.file_versions: Dict[str, int] = {}

    def watch_path(self, workspace: str, patterns: list = None) -> None:
        """Start watching a workspace path."""
        if workspace in self.watchers:
            print(f"Already watching {workspace}")
            return

        if patterns is None:
            patterns = ['**/*']

        event_handler = FileChangeHandler(self, workspace)
        observer = Observer()
        observer.schedule(event_handler, workspace, recursive=True)
        observer.start()

        self.watchers[workspace] = observer
        print(f"Started watching {workspace}")

    def unwatch_path(self, workspace: str) -> None:
        """Stop watching a workspace path."""
        observer = self.watchers.get(workspace)
        if observer:
            observer.stop()
            observer.join()
            del self.watchers[workspace]
            print(f"Stopped watching {workspace}")

    def handle_file_change(self, workspace: str, relative_path: str) -> None:
        """Handle a file change event."""
        full_path = os.path.join(workspace, relative_path)
        origin = self.change_origins.get(full_path)

        if origin == 'emacs':
            if full_path in self.change_origins:
                del self.change_origins[full_path]
            return

        self.notify_change(workspace, full_path)

    def notify_change(self, workspace: str, file_path: str) -> None:
        """Notify clients of a file change."""
        version = self.increment_version(file_path)

        self.broadcast({
            'type': 'file-changed',
            'workspace': workspace,
            'file': file_path,
            'version': version,
            'timestamp': int(time.time() * 1000)
        })

    def mark_change_origin(self, file_path: str, origin: Literal['emacs', 'agent']) -> None:
        """Mark the origin of a file change to prevent sync loops."""
        self.change_origins[file_path] = origin

        def clear_origin():
            if self.change_origins.get(file_path) == origin:
                del self.change_origins[file_path]

        # Clear origin after 2 seconds
        import threading
        timer = threading.Timer(2.0, clear_origin)
        timer.start()

    def increment_version(self, file_path: str) -> int:
        """Increment and return the version number for a file."""
        current = self.file_versions.get(file_path, 0)
        next_version = current + 1
        self.file_versions[file_path] = next_version
        return next_version

    def get_version(self, file_path: str) -> int:
        """Get the current version number for a file."""
        return self.file_versions.get(file_path, 0)

    def apply_agent_edit(self, file_path: str, content: str) -> None:
        """Apply an edit from the agent to a file."""
        self.mark_change_origin(file_path, 'agent')
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Applied agent edit to {file_path}")

    def broadcast(self, message: Dict[str, Any]) -> None:
        """Broadcast a message to all connected WebSocket clients."""
        self.socketio.emit('message', message)
        print(f"Broadcast {message.get('type')} to clients")

    def close(self) -> None:
        """Stop all watchers and clean up."""
        for workspace, observer in list(self.watchers.items()):
            observer.stop()
            observer.join()
            print(f"Closed watcher for {workspace}")
        self.watchers.clear()


class FileChangeHandler(FileSystemEventHandler):
    """Handler for file system events."""

    def __init__(self, sync_manager: SyncManager, workspace: str):
        """Initialize handler with sync manager and workspace."""
        super().__init__()
        self.sync_manager = sync_manager
        self.workspace = workspace
        self.ignored_patterns = {
            'node_modules', '.git', 'dist', 'build', '__pycache__',
            '.pyc', '.tmp', '.log'
        }

    def should_ignore(self, path: str) -> bool:
        """Check if a path should be ignored."""
        path_parts = Path(path).parts
        for part in path_parts:
            if any(pattern in part for pattern in self.ignored_patterns):
                return True
        if path.startswith('.'):
            return True
        return False

    def on_modified(self, event):
        """Handle file modification events."""
        if event.is_directory:
            return

        if self.should_ignore(event.src_path):
            return

        relative_path = os.path.relpath(event.src_path, self.workspace)
        self.sync_manager.handle_file_change(self.workspace, relative_path)
