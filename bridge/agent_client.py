"""Cursor Agent SDK client wrapper."""

import os
import random
import string
import time
from typing import Optional, Dict, Any, List, Callable
from types import Session, SessionOptions, AgentResponse


class AgentClient:
    """Manages agent sessions and message handling."""

    def __init__(self, api_key: Optional[str] = None, endpoint: Optional[str] = None):
        """Initialize agent client with API credentials."""
        self.sessions: Dict[str, Any] = {}
        self.api_key = api_key or os.getenv('CURSOR_API_KEY')
        self.endpoint = endpoint or os.getenv('CURSOR_ENDPOINT', 'https://cursor.com/api')

    async def create_session(self, options: SessionOptions) -> Session:
        """Create a new agent session."""
        session_id = self._generate_session_id()
        now = int(time.time() * 1000)

        session = Session(
            id=session_id,
            model=options.model or 'claude-4-sonnet',
            workspace=options.workspace,
            context={
                'workspace': options.workspace,
                'files': options.files or []
            },
            created_at=now,
            last_active=now
        )

        self.sessions[session_id] = {
            **session.__dict__,
            'messages': []
        }

        print(f"Created session {session_id} with model {session.model}")
        return session

    async def resume_session(self, session_id: str, session_data: Session) -> Session:
        """Resume an existing session."""
        if session_id not in self.sessions:
            self.sessions[session_id] = {
                **session_data.__dict__,
                'messages': []
            }

        session = self.sessions[session_id]
        session['last_active'] = int(time.time() * 1000)

        print(f"Resumed session {session_id}")
        return self.get_session_info(session_id)

    async def send_message(
        self,
        session_id: str,
        message: str,
        context: Optional[Any] = None
    ) -> AgentResponse:
        """Send a message to the agent and get a response."""
        session = self.sessions.get(session_id)
        if not session:
            raise ValueError(f"Session {session_id} not found")

        session['last_active'] = int(time.time() * 1000)

        user_message = {
            'role': 'user',
            'content': message,
            'timestamp': int(time.time() * 1000)
        }
        session['messages'].append(user_message)

        response = await self._simulate_agent_response(message, context)

        assistant_message = {
            'role': 'assistant',
            'content': response.content,
            'timestamp': int(time.time() * 1000),
            'message_id': response.message_id
        }
        session['messages'].append(assistant_message)

        return response

    async def stream_response(
        self,
        session_id: str,
        message: str,
        on_chunk: Callable[[Dict], None],
        context: Optional[Any] = None
    ) -> None:
        """Stream a response from the agent."""
        session = self.sessions.get(session_id)
        if not session:
            raise ValueError(f"Session {session_id} not found")

        session['last_active'] = int(time.time() * 1000)

        response = await self._simulate_agent_response(message, context)
        words = response.content.split(' ')

        for word in words:
            await self._sleep(0.05)
            on_chunk({'content': word + ' ', 'delta': word + ' '})

        on_chunk({'done': True, 'message_id': response.message_id})

    def get_session(self, session_id: str) -> Optional[Any]:
        """Get session data by ID."""
        return self.sessions.get(session_id)

    def get_session_info(self, session_id: str) -> Session:
        """Get session metadata."""
        session = self.sessions.get(session_id)
        if not session:
            raise ValueError(f"Session {session_id} not found")

        return Session(
            id=session['id'],
            model=session['model'],
            workspace=session.get('workspace'),
            context=session['context'],
            created_at=session['created_at'],
            last_active=session['last_active']
        )

    def list_sessions(self) -> List[Session]:
        """List all active sessions."""
        return [
            Session(
                id=session['id'],
                model=session['model'],
                workspace=session.get('workspace'),
                context=session['context'],
                created_at=session['created_at'],
                last_active=session['last_active']
            )
            for session in self.sessions.values()
        ]

    def delete_session(self, session_id: str) -> None:
        """Delete a session."""
        if session_id in self.sessions:
            del self.sessions[session_id]
            print(f"Deleted session {session_id}")

    def _generate_session_id(self) -> str:
        """Generate a unique session ID."""
        random_part = ''.join(random.choices(string.ascii_lowercase + string.digits, k=13))
        return f"sess_{random_part}"

    async def _simulate_agent_response(
        self,
        message: str,
        context: Optional[Any] = None
    ) -> AgentResponse:
        """Simulate an agent response (placeholder for real API integration)."""
        message_id = 'msg_' + ''.join(random.choices(string.ascii_lowercase + string.digits, k=13))

        lower_message = message.lower()

        if 'explain' in lower_message:
            content = (
                "I'll explain this code for you. The function performs the following operations:\n\n"
                "1. First, it initializes the necessary variables\n"
                "2. Then it processes the input data\n"
                "3. Finally, it returns the result\n\n"
                "This is a common pattern in software development."
            )
        elif any(word in lower_message for word in ['fix', 'error', 'bug']):
            content = (
                "I found the issue. Here's the corrected code:\n\n"
                "```python\n"
                "def fixed_function():\n"
                "    # Fixed implementation\n"
                "    result = process_data()\n"
                "    return result\n"
                "```\n\n"
                "The problem was in the error handling. I've updated it to properly handle edge cases."
            )
        elif 'refactor' in lower_message:
            content = (
                "I've refactored the code to improve readability and maintainability:\n\n"
                "```python\n"
                "async def refactored_function():\n"
                '    """Improved function with better structure."""\n'
                "    data = await fetch_data()\n"
                "    processed = transform(data)\n"
                "    return processed\n"
                "```\n\n"
                "The changes include:\n"
                "- Using async/await for better asynchronous handling\n"
                "- Adding docstrings\n"
                "- Breaking down complex operations"
            )
        elif 'test' in lower_message:
            content = (
                "Here are comprehensive tests for your code:\n\n"
                "```python\n"
                "import pytest\n\n"
                "def test_function():\n"
                '    """Test the main functionality."""\n'
                "    result = your_function(test_input)\n"
                "    assert result == expected_output\n\n"
                "def test_edge_cases():\n"
                '    """Test edge cases."""\n'
                "    assert your_function(None) is None\n"
                "    assert your_function([]) == []\n"
                "```"
            )
        else:
            content = (
                f'I understand your request: "{message}"\n\n'
                "I'm here to help with code analysis, refactoring, bug fixes, and explanations. "
                "For this request, I'll provide assistance based on the context you've shared.\n\n"
                "Let me know if you'd like me to focus on a specific aspect!"
            )

        return AgentResponse(
            message_id=message_id,
            content=content,
            edits=None
        )

    @staticmethod
    async def _sleep(seconds: float) -> None:
        """Async sleep helper."""
        import asyncio
        await asyncio.sleep(seconds)
