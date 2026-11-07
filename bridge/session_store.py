"""Session storage using SQLite."""

import sqlite3
import json
from typing import Optional, List
from models import Session


class SessionStore:
    """Manages session persistence with SQLite."""

    def __init__(self, db_path: str):
        """Initialize session store with database path."""
        import os
        
        self.db_path = db_path
        
        # Ensure directory exists
        db_dir = os.path.dirname(db_path)
        if db_dir and not os.path.exists(db_dir):
            os.makedirs(db_dir, exist_ok=True)
        
        self.conn = sqlite3.connect(db_path, check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        self._initialize_database()

    def _initialize_database(self) -> None:
        """Create sessions table if it doesn't exist."""
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                model TEXT NOT NULL,
                workspace TEXT,
                context TEXT,
                created_at INTEGER NOT NULL,
                last_active INTEGER NOT NULL
            )
        """)
        self.conn.commit()

    def save(self, session: Session) -> None:
        """Save or update a session."""
        self.conn.execute("""
            INSERT OR REPLACE INTO sessions
            (id, model, workspace, context, created_at, last_active)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (
            session.id,
            session.model,
            session.workspace,
            json.dumps(session.context),
            session.created_at,
            session.last_active
        ))
        self.conn.commit()

    def load(self, session_id: str) -> Optional[Session]:
        """Load a session by ID."""
        cursor = self.conn.execute(
            "SELECT * FROM sessions WHERE id = ?",
            (session_id,)
        )
        row = cursor.fetchone()

        if not row:
            return None

        return Session(
            id=row['id'],
            model=row['model'],
            workspace=row['workspace'],
            context=json.loads(row['context']),
            created_at=row['created_at'],
            last_active=row['last_active']
        )

    def list(self) -> List[Session]:
        """List all sessions ordered by last active."""
        cursor = self.conn.execute(
            "SELECT * FROM sessions ORDER BY last_active DESC"
        )
        rows = cursor.fetchall()

        return [
            Session(
                id=row['id'],
                model=row['model'],
                workspace=row['workspace'],
                context=json.loads(row['context']),
                created_at=row['created_at'],
                last_active=row['last_active']
            )
            for row in rows
        ]

    def delete(self, session_id: str) -> None:
        """Delete a session by ID."""
        self.conn.execute("DELETE FROM sessions WHERE id = ?", (session_id,))
        self.conn.commit()

    def update_last_active(self, session_id: str) -> None:
        """Update the last active timestamp for a session."""
        import time
        self.conn.execute(
            "UPDATE sessions SET last_active = ? WHERE id = ?",
            (int(time.time() * 1000), session_id)
        )
        self.conn.commit()

    def close(self) -> None:
        """Close the database connection."""
        self.conn.close()
