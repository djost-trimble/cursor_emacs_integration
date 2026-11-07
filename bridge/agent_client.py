"""Cursor Agent SDK client wrapper."""

import os
import random
import string
import time
from typing import Optional, Dict, Any, List, Callable
from models import Session, SessionOptions, AgentResponse
import requests


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

    def _get_auth_headers(self) -> Dict[str, str]:
        """Get authorization headers for cloud API requests."""
        if not self.api_key:
            raise ValueError("CURSOR_API_KEY is required for cloud operations")
        return {
            'Authorization': f'Bearer {self.api_key}',
            'Content-Type': 'application/json'
        }

    async def list_cloud_sessions(self, limit: int = 50, offset: int = 0) -> Dict[str, Any]:
        """List user's cloud sessions/projects.
        
        Args:
            limit: Maximum number of sessions to return
            offset: Pagination offset
            
        Returns:
            Dictionary containing sessions list and pagination info
        """
        try:
            headers = self._get_auth_headers()
            params = {'limit': limit, 'offset': offset}
            
            response = requests.get(
                f'{self.endpoint}/cloud/sessions',
                headers=headers,
                params=params,
                timeout=30
            )
            
            if response.status_code == 200:
                return response.json()
            elif response.status_code == 401:
                raise ValueError("Invalid API key")
            else:
                print(f"Cloud API error: {response.status_code} - {response.text}")
                return {
                    'sessions': [],
                    'total': 0,
                    'error': f'API returned status {response.status_code}'
                }
        except requests.exceptions.RequestException as e:
            print(f"Network error listing cloud sessions: {e}")
            return {
                'sessions': [],
                'total': 0,
                'error': str(e)
            }

    async def fetch_cloud_session_context(self, cloud_session_id: str) -> Dict[str, Any]:
        """Fetch context from a cloud session.
        
        Args:
            cloud_session_id: ID of the cloud session
            
        Returns:
            Dictionary containing session context data
        """
        try:
            headers = self._get_auth_headers()
            
            response = requests.get(
                f'{self.endpoint}/cloud/sessions/{cloud_session_id}/context',
                headers=headers,
                timeout=30
            )
            
            if response.status_code == 200:
                return response.json()
            elif response.status_code == 404:
                raise ValueError(f"Cloud session {cloud_session_id} not found")
            elif response.status_code == 401:
                raise ValueError("Invalid API key")
            else:
                print(f"Cloud API error: {response.status_code} - {response.text}")
                return {
                    'error': f'API returned status {response.status_code}'
                }
        except requests.exceptions.RequestException as e:
            print(f"Network error fetching cloud session context: {e}")
            return {
                'error': str(e)
            }

    async def fetch_cloud_session_history(self, cloud_session_id: str) -> Dict[str, Any]:
        """Get session history and files from a cloud session.
        
        Args:
            cloud_session_id: ID of the cloud session
            
        Returns:
            Dictionary containing message history and file list
        """
        try:
            headers = self._get_auth_headers()
            
            response = requests.get(
                f'{self.endpoint}/cloud/sessions/{cloud_session_id}/history',
                headers=headers,
                timeout=30
            )
            
            if response.status_code == 200:
                return response.json()
            elif response.status_code == 404:
                raise ValueError(f"Cloud session {cloud_session_id} not found")
            elif response.status_code == 401:
                raise ValueError("Invalid API key")
            else:
                print(f"Cloud API error: {response.status_code} - {response.text}")
                return {
                    'messages': [],
                    'files': [],
                    'error': f'API returned status {response.status_code}'
                }
        except requests.exceptions.RequestException as e:
            print(f"Network error fetching cloud session history: {e}")
            return {
                'messages': [],
                'files': [],
                'error': str(e)
            }

    async def import_cloud_session(self, cloud_session_id: str) -> Session:
        """Import a cloud session as a local session.
        
        Args:
            cloud_session_id: ID of the cloud session to import
            
        Returns:
            New local Session object
        """
        context = await self.fetch_cloud_session_context(cloud_session_id)
        history = await self.fetch_cloud_session_history(cloud_session_id)
        
        if 'error' in context or 'error' in history:
            raise ValueError(f"Failed to import cloud session: {context.get('error') or history.get('error')}")
        
        session_id = self._generate_session_id()
        now = int(time.time() * 1000)
        
        session = Session(
            id=session_id,
            model=context.get('model', 'claude-4-sonnet'),
            workspace=context.get('workspace'),
            context={
                'cloud_session_id': cloud_session_id,
                'workspace': context.get('workspace'),
                'files': history.get('files', []),
                'imported_from': 'cloud',
                'imported_at': now
            },
            created_at=context.get('created_at', now),
            last_active=now
        )
        
        self.sessions[session_id] = {
            **session.__dict__,
            'messages': history.get('messages', []),
            'cloud_session_id': cloud_session_id
        }
        
        print(f"Imported cloud session {cloud_session_id} as local session {session_id}")
        return session

    async def sync_to_cloud(self, session_id: str) -> Dict[str, Any]:
        """Upload local session to cloud (if API supports).
        
        Args:
            session_id: ID of the local session to upload
            
        Returns:
            Dictionary with cloud session ID and status
        """
        session = self.sessions.get(session_id)
        if not session:
            raise ValueError(f"Session {session_id} not found")
        
        try:
            headers = self._get_auth_headers()
            
            payload = {
                'model': session['model'],
                'workspace': session.get('workspace'),
                'context': session['context'],
                'messages': session.get('messages', []),
                'created_at': session['created_at']
            }
            
            response = requests.post(
                f'{self.endpoint}/cloud/sessions',
                headers=headers,
                json=payload,
                timeout=30
            )
            
            if response.status_code == 201:
                result = response.json()
                session['cloud_session_id'] = result.get('cloud_session_id')
                print(f"Synced session {session_id} to cloud: {result.get('cloud_session_id')}")
                return result
            elif response.status_code == 401:
                raise ValueError("Invalid API key")
            else:
                print(f"Cloud API error: {response.status_code} - {response.text}")
                return {
                    'error': f'API returned status {response.status_code}',
                    'success': False
                }
        except requests.exceptions.RequestException as e:
            print(f"Network error syncing to cloud: {e}")
            return {
                'error': str(e),
                'success': False
            }
