"""Type definitions for Cursor Emacs Bridge."""

from typing import TypedDict, Optional, List, Any, Literal
from dataclasses import dataclass


@dataclass
class SessionOptions:
    """Options for creating a session."""
    model: Optional[str] = None
    workspace: Optional[str] = None
    files: Optional[List[str]] = None


@dataclass
class Session:
    """Agent session data."""
    id: str
    model: str
    workspace: Optional[str]
    context: Any
    created_at: int
    last_active: int


@dataclass
class Change:
    """A single change to a file."""
    type: Literal['insert', 'delete', 'replace']
    position: int
    line: Optional[int] = None
    old_text: Optional[str] = None
    new_text: Optional[str] = None
    length: Optional[int] = None
    text: Optional[str] = None


@dataclass
class FileEdit:
    """Edits to a file."""
    file: str
    changes: List[Change]


@dataclass
class AgentMessage:
    """Message from the agent."""
    message_id: str
    content: str
    edits: Optional[List[FileEdit]] = None
    attachments: Optional[List[Any]] = None


@dataclass
class AgentResponse:
    """Response from the agent."""
    message_id: str
    content: str
    edits: Optional[List[FileEdit]] = None


@dataclass
class BufferChange:
    """Change notification from Emacs buffer."""
    type: Literal['buffer-changed']
    file: str
    version: int
    changes: List[Change]
    content: Optional[str] = None


class WebSocketMessage(TypedDict, total=False):
    """WebSocket message structure."""
    type: str


@dataclass
class SyncConflict:
    """Synchronization conflict data."""
    file: str
    emacs_version: int
    agent_version: int
    emacs_content: str
    agent_content: str


@dataclass
class Config:
    """Bridge service configuration."""
    api_key: Optional[str]
    endpoint: str
    prefer_local_models: bool
    http_port: int
    ws_port: int
    db_path: str
