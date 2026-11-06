import express, { Request, Response } from 'express';
import { WebSocketServer, WebSocket } from 'ws';
import * as http from 'http';
import cors from 'cors';
import * as dotenv from 'dotenv';
import { AgentClient } from './agent-client';
import { SyncManager } from './sync-manager';
import { SessionStore } from './session-store';
import { Config } from './types';
import * as path from 'path';
import * as os from 'os';

dotenv.config();

export class CursorBridge {
  private app: express.Application;
  private server: http.Server;
  private wss: WebSocketServer;
  private agentClient: AgentClient;
  private syncManager: SyncManager;
  private sessionStore: SessionStore;
  private config: Config;

  constructor() {
    this.config = this.loadConfig();
    this.app = express();
    this.server = http.createServer(this.app);
    this.wss = new WebSocketServer({ server: this.server });
    this.agentClient = new AgentClient(this.config.apiKey, this.config.endpoint);
    this.syncManager = new SyncManager(this.wss);
    this.sessionStore = new SessionStore(this.config.dbPath);

    this.setupMiddleware();
    this.setupRoutes();
    this.setupWebSocket();
  }

  private loadConfig(): Config {
    return {
      apiKey: process.env.CURSOR_API_KEY,
      endpoint: process.env.CURSOR_ENDPOINT || 'https://cursor.com/api',
      preferLocalModels: process.env.PREFER_LOCAL_MODELS === 'true',
      httpPort: parseInt(process.env.HTTP_PORT || '8765'),
      wsPort: parseInt(process.env.WS_PORT || '8766'),
      dbPath: process.env.DB_PATH || path.join(os.homedir(), '.cursor-bridge', 'sessions.db')
    };
  }

  private setupMiddleware(): void {
    this.app.use(cors());
    this.app.use(express.json({ limit: '10mb' }));
    this.app.use((req, res, next) => {
      console.log(`${req.method} ${req.path}`);
      next();
    });
  }

  private setupRoutes(): void {
    this.app.get('/health', (req, res) => {
      res.json({ status: 'ok', timestamp: Date.now() });
    });

    this.app.post('/api/sessions/create', async (req, res) => {
      try {
        const { model, workspace, files } = req.body;
        const session = await this.agentClient.createSession({ model, workspace, files });
        this.sessionStore.save(session);

        if (workspace) {
          this.syncManager.watchPath(workspace);
        }

        res.json({
          sessionId: session.id,
          model: session.model,
          created: new Date(session.createdAt).toISOString()
        });
      } catch (error) {
        console.error('Error creating session:', error);
        res.status(500).json({ error: 'Failed to create session' });
      }
    });

    this.app.post('/api/sessions/:id/resume', async (req, res) => {
      try {
        const { id } = req.params;
        let session = this.sessionStore.load(id);

        if (!session) {
          return res.status(404).json({ error: 'Session not found' });
        }

        session = await this.agentClient.resumeSession(id, session);
        this.sessionStore.updateLastActive(id);

        const sessionData = this.agentClient.getSession(id);

        res.json({
          sessionId: session.id,
          model: session.model,
          lastActive: new Date(session.lastActive).toISOString(),
          messageCount: sessionData?.messages?.length || 0
        });
      } catch (error) {
        console.error('Error resuming session:', error);
        res.status(500).json({ error: 'Failed to resume session' });
      }
    });

    this.app.get('/api/sessions', (req, res) => {
      try {
        const sessions = this.sessionStore.list();
        res.json({
          sessions: sessions.map(s => ({
            sessionId: s.id,
            model: s.model,
            workspace: s.workspace,
            created: new Date(s.createdAt).toISOString(),
            lastActive: new Date(s.lastActive).toISOString()
          }))
        });
      } catch (error) {
        console.error('Error listing sessions:', error);
        res.status(500).json({ error: 'Failed to list sessions' });
      }
    });

    this.app.delete('/api/sessions/:id', (req, res) => {
      try {
        const { id } = req.params;
        this.agentClient.deleteSession(id);
        this.sessionStore.delete(id);
        res.json({ success: true });
      } catch (error) {
        console.error('Error deleting session:', error);
        res.status(500).json({ error: 'Failed to delete session' });
      }
    });

    this.app.post('/api/agent/ask', async (req, res) => {
      try {
        const { sessionId, message, context } = req.body;

        if (!sessionId || !message) {
          return res.status(400).json({ error: 'sessionId and message are required' });
        }

        const response = await this.agentClient.sendMessage(sessionId, message, context);
        this.sessionStore.updateLastActive(sessionId);

        this.syncManager.broadcast({
          type: 'agent-message',
          sessionId,
          messageId: response.messageId,
          content: response.content
        });

        res.json(response);
      } catch (error) {
        console.error('Error sending message:', error);
        res.status(500).json({ error: 'Failed to send message' });
      }
    });

    this.app.post('/api/agent/apply-edit', async (req, res) => {
      try {
        const { file, content } = req.body;

        if (!file || content === undefined) {
          return res.status(400).json({ error: 'file and content are required' });
        }

        await this.syncManager.applyAgentEdit(file, content);
        res.json({ success: true });
      } catch (error) {
        console.error('Error applying edit:', error);
        res.status(500).json({ error: 'Failed to apply edit' });
      }
    });

    this.app.get('/api/agent/status', (req, res) => {
      try {
        const sessions = this.agentClient.listSessions();
        res.json({
          activeSessions: sessions.length,
          sessions: sessions.map(s => ({
            id: s.id,
            model: s.model,
            lastActive: new Date(s.lastActive).toISOString()
          }))
        });
      } catch (error) {
        console.error('Error getting status:', error);
        res.status(500).json({ error: 'Failed to get status' });
      }
    });

    this.app.post('/api/sync/enable', (req, res) => {
      try {
        const { path } = req.body;
        if (!path) {
          return res.status(400).json({ error: 'path is required' });
        }
        this.syncManager.watchPath(path);
        res.json({ success: true, path });
      } catch (error) {
        console.error('Error enabling sync:', error);
        res.status(500).json({ error: 'Failed to enable sync' });
      }
    });

    this.app.post('/api/sync/disable', (req, res) => {
      try {
        const { path } = req.body;
        if (!path) {
          return res.status(400).json({ error: 'path is required' });
        }
        this.syncManager.unwatchPath(path);
        res.json({ success: true, path });
      } catch (error) {
        console.error('Error disabling sync:', error);
        res.status(500).json({ error: 'Failed to disable sync' });
      }
    });

    this.app.get('/api/config', (req, res) => {
      res.json({
        endpoint: this.config.endpoint,
        preferLocalModels: this.config.preferLocalModels,
        httpPort: this.config.httpPort,
        wsPort: this.config.wsPort
      });
    });

    this.app.put('/api/config', (req, res) => {
      try {
        const { preferLocalModels } = req.body;
        if (preferLocalModels !== undefined) {
          this.config.preferLocalModels = preferLocalModels;
        }
        res.json({ success: true, config: this.config });
      } catch (error) {
        console.error('Error updating config:', error);
        res.status(500).json({ error: 'Failed to update config' });
      }
    });
  }

  private setupWebSocket(): void {
    this.wss.on('connection', (ws: WebSocket) => {
      console.log('WebSocket client connected');

      ws.send(JSON.stringify({
        type: 'connected',
        timestamp: Date.now()
      }));

      ws.on('message', async (data: Buffer) => {
        try {
          const message = JSON.parse(data.toString());
          await this.handleWebSocketMessage(ws, message);
        } catch (error) {
          console.error('Error handling WebSocket message:', error);
          ws.send(JSON.stringify({
            type: 'error',
            error: 'Invalid message format'
          }));
        }
      });

      ws.on('close', () => {
        console.log('WebSocket client disconnected');
      });

      ws.on('error', (error) => {
        console.error('WebSocket error:', error);
      });
    });

    console.log('WebSocket server initialized');
  }

  private async handleWebSocketMessage(ws: WebSocket, message: any): Promise<void> {
    switch (message.type) {
      case 'buffer-changed':
        if (message.file) {
          this.syncManager.markChangeOrigin(message.file, 'emacs');
          this.syncManager.incrementVersion(message.file);
          console.log(`Buffer changed: ${message.file} v${message.version}`);
        }
        break;

      case 'subscribe-file':
        console.log(`Client subscribed to ${message.file}`);
        break;

      case 'unsubscribe-file':
        console.log(`Client unsubscribed from ${message.file}`);
        break;

      case 'ping':
        ws.send(JSON.stringify({ type: 'pong', timestamp: Date.now() }));
        break;

      default:
        console.warn(`Unknown message type: ${message.type}`);
    }
  }

  start(): void {
    this.server.listen(this.config.httpPort, () => {
      console.log(`
╔══════════════════════════════════════════════════════════╗
║         Cursor Emacs Bridge Service Started              ║
╠══════════════════════════════════════════════════════════╣
║  HTTP Server:      http://localhost:${this.config.httpPort}            ║
║  WebSocket Server: ws://localhost:${this.config.httpPort}              ║
║  Database:         ${this.config.dbPath.padEnd(30)} ║
╚══════════════════════════════════════════════════════════╝
      `);
    });

    process.on('SIGINT', () => {
      console.log('\nShutting down gracefully...');
      this.shutdown();
    });

    process.on('SIGTERM', () => {
      console.log('\nShutting down gracefully...');
      this.shutdown();
    });
  }

  private shutdown(): void {
    console.log('Closing connections...');
    this.syncManager.close();
    this.sessionStore.close();
    this.server.close(() => {
      console.log('Server closed');
      process.exit(0);
    });
  }
}

if (require.main === module) {
  const bridge = new CursorBridge();
  bridge.start();
}
