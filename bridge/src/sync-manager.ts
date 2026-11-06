import * as chokidar from 'chokidar';
import { WebSocketServer, WebSocket } from 'ws';
import * as fs from 'fs/promises';
import * as path from 'path';

export class SyncManager {
  private watchers: Map<string, chokidar.FSWatcher>;
  private wss: WebSocketServer;
  private changeOrigins: Map<string, 'emacs' | 'agent'>;
  private fileVersions: Map<string, number>;

  constructor(wss: WebSocketServer) {
    this.watchers = new Map();
    this.wss = wss;
    this.changeOrigins = new Map();
    this.fileVersions = new Map();
  }

  watchPath(workspace: string, patterns: string[] = ['**/*']): void {
    if (this.watchers.has(workspace)) {
      console.log(`Already watching ${workspace}`);
      return;
    }

    const watcher = chokidar.watch(patterns, {
      cwd: workspace,
      persistent: true,
      ignoreInitial: true,
      ignored: [
        '**/node_modules/**',
        '**/.git/**',
        '**/.*',
        '**/*.tmp',
        '**/*.log',
        '**/dist/**',
        '**/build/**'
      ],
      awaitWriteFinish: {
        stabilityThreshold: 100,
        pollInterval: 50
      }
    });

    watcher.on('change', (filePath) => {
      this.handleFileChange(workspace, filePath);
    });

    watcher.on('error', (error) => {
      console.error(`Watcher error for ${workspace}:`, error);
    });

    this.watchers.set(workspace, watcher);
    console.log(`Started watching ${workspace}`);
  }

  unwatchPath(workspace: string): void {
    const watcher = this.watchers.get(workspace);
    if (watcher) {
      watcher.close();
      this.watchers.delete(workspace);
      console.log(`Stopped watching ${workspace}`);
    }
  }

  private handleFileChange(workspace: string, relativePath: string): void {
    const fullPath = path.join(workspace, relativePath);
    const origin = this.changeOrigins.get(fullPath);

    if (origin === 'emacs') {
      this.changeOrigins.delete(fullPath);
      return;
    }

    this.notifyChange(workspace, fullPath);
  }

  private notifyChange(workspace: string, file: string): void {
    const version = this.incrementVersion(file);

    this.broadcast({
      type: 'file-changed',
      workspace,
      file,
      version,
      timestamp: Date.now()
    });
  }

  markChangeOrigin(file: string, origin: 'emacs' | 'agent'): void {
    this.changeOrigins.set(file, origin);
    setTimeout(() => {
      if (this.changeOrigins.get(file) === origin) {
        this.changeOrigins.delete(file);
      }
    }, 2000);
  }

  incrementVersion(file: string): number {
    const current = this.fileVersions.get(file) || 0;
    const next = current + 1;
    this.fileVersions.set(file, next);
    return next;
  }

  getVersion(file: string): number {
    return this.fileVersions.get(file) || 0;
  }

  async applyAgentEdit(file: string, content: string): Promise<void> {
    this.markChangeOrigin(file, 'agent');
    await fs.writeFile(file, content, 'utf-8');
    console.log(`Applied agent edit to ${file}`);
  }

  broadcast(message: any): void {
    const messageStr = JSON.stringify(message);
    let sentCount = 0;

    this.wss.clients.forEach((client: WebSocket) => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(messageStr);
        sentCount++;
      }
    });

    if (sentCount > 0) {
      console.log(`Broadcast ${message.type} to ${sentCount} client(s)`);
    }
  }

  close(): void {
    for (const [workspace, watcher] of this.watchers) {
      watcher.close();
      console.log(`Closed watcher for ${workspace}`);
    }
    this.watchers.clear();
  }
}
