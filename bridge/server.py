#!/usr/bin/env python3
"""Cursor Emacs Bridge Service - Python implementation."""

import os
import sys
import time
from pathlib import Path
from typing import Optional, Dict, Any

from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_socketio import SocketIO, emit
from dotenv import load_dotenv

from types import Config, SessionOptions
from agent_client import AgentClient
from sync_manager import SyncManager
from session_store import SessionStore


class CursorBridge:
    """Main bridge service coordinating HTTP, WebSocket, and agent interactions."""

    def __init__(self):
        """Initialize the bridge service."""
        load_dotenv()
        self.config = self._load_config()

        self.app = Flask(__name__)
        CORS(self.app)
        self.app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'dev-secret-key')

        self.socketio = SocketIO(self.app, cors_allowed_origins="*")

        self.agent_client = AgentClient(self.config.api_key, self.config.endpoint)
        self.sync_manager = SyncManager(self.socketio)
        self.session_store = SessionStore(self.config.db_path)

        self._setup_routes()
        self._setup_websocket()

    def _load_config(self) -> Config:
        """Load configuration from environment variables."""
        db_path = os.getenv('DB_PATH')
        if not db_path:
            home = Path.home()
            cursor_dir = home / '.cursor-bridge'
            cursor_dir.mkdir(exist_ok=True)
            db_path = str(cursor_dir / 'sessions.db')

        return Config(
            api_key=os.getenv('CURSOR_API_KEY'),
            endpoint=os.getenv('CURSOR_ENDPOINT', 'https://cursor.com/api'),
            prefer_local_models=os.getenv('PREFER_LOCAL_MODELS', 'false').lower() == 'true',
            http_port=int(os.getenv('HTTP_PORT', '8765')),
            ws_port=int(os.getenv('WS_PORT', '8766')),
            db_path=db_path
        )

    def _setup_routes(self) -> None:
        """Set up HTTP routes."""

        @self.app.route('/health', methods=['GET'])
        def health():
            return jsonify({'status': 'ok', 'timestamp': int(time.time() * 1000)})

        @self.app.route('/api/sessions/create', methods=['POST'])
        async def create_session():
            try:
                data = request.json
                options = SessionOptions(
                    model=data.get('model'),
                    workspace=data.get('workspace'),
                    files=data.get('files')
                )

                session = await self.agent_client.create_session(options)
                self.session_store.save(session)

                if session.workspace:
                    self.sync_manager.watch_path(session.workspace)

                return jsonify({
                    'sessionId': session.id,
                    'model': session.model,
                    'created': time.strftime('%Y-%m-%dT%H:%M:%S.000Z',
                                           time.gmtime(session.created_at / 1000))
                })
            except Exception as e:
                print(f"Error creating session: {e}")
                return jsonify({'error': 'Failed to create session'}), 500

        @self.app.route('/api/sessions/<session_id>/resume', methods=['POST'])
        async def resume_session(session_id: str):
            try:
                session_data = self.session_store.load(session_id)
                if not session_data:
                    return jsonify({'error': 'Session not found'}), 404

                session = await self.agent_client.resume_session(session_id, session_data)
                self.session_store.update_last_active(session_id)

                session_obj = self.agent_client.get_session(session_id)
                message_count = len(session_obj.get('messages', [])) if session_obj else 0

                return jsonify({
                    'sessionId': session.id,
                    'model': session.model,
                    'lastActive': time.strftime('%Y-%m-%dT%H:%M:%S.000Z',
                                               time.gmtime(session.last_active / 1000)),
                    'messageCount': message_count
                })
            except Exception as e:
                print(f"Error resuming session: {e}")
                return jsonify({'error': 'Failed to resume session'}), 500

        @self.app.route('/api/sessions', methods=['GET'])
        def list_sessions():
            try:
                sessions = self.session_store.list()
                return jsonify({
                    'sessions': [
                        {
                            'sessionId': s.id,
                            'model': s.model,
                            'workspace': s.workspace,
                            'created': time.strftime('%Y-%m-%dT%H:%M:%S.000Z',
                                                   time.gmtime(s.created_at / 1000)),
                            'lastActive': time.strftime('%Y-%m-%dT%H:%M:%S.000Z',
                                                       time.gmtime(s.last_active / 1000))
                        }
                        for s in sessions
                    ]
                })
            except Exception as e:
                print(f"Error listing sessions: {e}")
                return jsonify({'error': 'Failed to list sessions'}), 500

        @self.app.route('/api/sessions/<session_id>', methods=['DELETE'])
        def delete_session(session_id: str):
            try:
                self.agent_client.delete_session(session_id)
                self.session_store.delete(session_id)
                return jsonify({'success': True})
            except Exception as e:
                print(f"Error deleting session: {e}")
                return jsonify({'error': 'Failed to delete session'}), 500

        @self.app.route('/api/agent/ask', methods=['POST'])
        async def ask_agent():
            try:
                data = request.json
                session_id = data.get('sessionId')
                message = data.get('message')
                context = data.get('context')

                if not session_id or not message:
                    return jsonify({'error': 'sessionId and message are required'}), 400

                response = await self.agent_client.send_message(session_id, message, context)
                self.session_store.update_last_active(session_id)

                self.sync_manager.broadcast({
                    'type': 'agent-message',
                    'sessionId': session_id,
                    'messageId': response.message_id,
                    'content': response.content
                })

                return jsonify({
                    'messageId': response.message_id,
                    'content': response.content,
                    'edits': response.edits
                })
            except Exception as e:
                print(f"Error sending message: {e}")
                return jsonify({'error': 'Failed to send message'}), 500

        @self.app.route('/api/agent/apply-edit', methods=['POST'])
        def apply_edit():
            try:
                data = request.json
                file_path = data.get('file')
                content = data.get('content')

                if not file_path or content is None:
                    return jsonify({'error': 'file and content are required'}), 400

                self.sync_manager.apply_agent_edit(file_path, content)
                return jsonify({'success': True})
            except Exception as e:
                print(f"Error applying edit: {e}")
                return jsonify({'error': 'Failed to apply edit'}), 500

        @self.app.route('/api/agent/status', methods=['GET'])
        def agent_status():
            try:
                sessions = self.agent_client.list_sessions()
                return jsonify({
                    'activeSessions': len(sessions),
                    'sessions': [
                        {
                            'id': s.id,
                            'model': s.model,
                            'lastActive': time.strftime('%Y-%m-%dT%H:%M:%S.000Z',
                                                       time.gmtime(s.last_active / 1000))
                        }
                        for s in sessions
                    ]
                })
            except Exception as e:
                print(f"Error getting status: {e}")
                return jsonify({'error': 'Failed to get status'}), 500

        @self.app.route('/api/sync/enable', methods=['POST'])
        def enable_sync():
            try:
                data = request.json
                path = data.get('path')
                if not path:
                    return jsonify({'error': 'path is required'}), 400

                self.sync_manager.watch_path(path)
                return jsonify({'success': True, 'path': path})
            except Exception as e:
                print(f"Error enabling sync: {e}")
                return jsonify({'error': 'Failed to enable sync'}), 500

        @self.app.route('/api/sync/disable', methods=['POST'])
        def disable_sync():
            try:
                data = request.json
                path = data.get('path')
                if not path:
                    return jsonify({'error': 'path is required'}), 400

                self.sync_manager.unwatch_path(path)
                return jsonify({'success': True, 'path': path})
            except Exception as e:
                print(f"Error disabling sync: {e}")
                return jsonify({'error': 'Failed to disable sync'}), 500

        @self.app.route('/api/config', methods=['GET'])
        def get_config():
            return jsonify({
                'endpoint': self.config.endpoint,
                'preferLocalModels': self.config.prefer_local_models,
                'httpPort': self.config.http_port,
                'wsPort': self.config.ws_port
            })

        @self.app.route('/api/config', methods=['PUT'])
        def update_config():
            try:
                data = request.json
                if 'preferLocalModels' in data:
                    self.config.prefer_local_models = data['preferLocalModels']

                return jsonify({
                    'success': True,
                    'config': {
                        'endpoint': self.config.endpoint,
                        'preferLocalModels': self.config.prefer_local_models,
                        'httpPort': self.config.http_port,
                        'wsPort': self.config.ws_port
                    }
                })
            except Exception as e:
                print(f"Error updating config: {e}")
                return jsonify({'error': 'Failed to update config'}), 500

    def _setup_websocket(self) -> None:
        """Set up WebSocket event handlers."""

        @self.socketio.on('connect')
        def handle_connect():
            print('WebSocket client connected')
            emit('message', {
                'type': 'connected',
                'timestamp': int(time.time() * 1000)
            })

        @self.socketio.on('disconnect')
        def handle_disconnect():
            print('WebSocket client disconnected')

        @self.socketio.on('message')
        def handle_message(data: Dict[str, Any]):
            try:
                msg_type = data.get('type')

                if msg_type == 'buffer-changed':
                    if 'file' in data:
                        self.sync_manager.mark_change_origin(data['file'], 'emacs')
                        self.sync_manager.increment_version(data['file'])
                        print(f"Buffer changed: {data['file']} v{data.get('version')}")

                elif msg_type == 'subscribe-file':
                    print(f"Client subscribed to {data.get('file')}")

                elif msg_type == 'unsubscribe-file':
                    print(f"Client unsubscribed from {data.get('file')}")

                elif msg_type == 'ping':
                    emit('message', {
                        'type': 'pong',
                        'timestamp': int(time.time() * 1000)
                    })

                else:
                    print(f"Unknown message type: {msg_type}")

            except Exception as e:
                print(f"Error handling WebSocket message: {e}")
                emit('message', {
                    'type': 'error',
                    'error': 'Invalid message format'
                })

    def start(self) -> None:
        """Start the bridge service."""
        port = self.config.http_port

        print(f"""
╔══════════════════════════════════════════════════════════╗
║         Cursor Emacs Bridge Service Started              ║
╠══════════════════════════════════════════════════════════╣
║  HTTP Server:      http://localhost:{port:<4}            ║
║  WebSocket Server: ws://localhost:{port:<4}              ║
║  Database:         {self.config.db_path:<30} ║
╚══════════════════════════════════════════════════════════╝
        """)

        try:
            self.socketio.run(
                self.app,
                host='0.0.0.0',
                port=port,
                debug=False,
                allow_unsafe_werkzeug=True
            )
        except KeyboardInterrupt:
            print('\nShutting down gracefully...')
            self.shutdown()

    def shutdown(self) -> None:
        """Shut down the bridge service."""
        print('Closing connections...')
        self.sync_manager.close()
        self.session_store.close()
        print('Server closed')


def main():
    """Main entry point."""
    bridge = CursorBridge()
    bridge.start()


if __name__ == '__main__':
    main()
