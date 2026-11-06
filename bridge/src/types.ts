export interface SessionOptions {
  model?: string;
  workspace?: string;
  files?: string[];
}

export interface Session {
  id: string;
  model: string;
  workspace?: string;
  context: any;
  createdAt: number;
  lastActive: number;
}

export interface AgentMessage {
  messageId: string;
  content: string;
  edits?: FileEdit[];
  attachments?: any[];
}

export interface FileEdit {
  file: string;
  changes: Change[];
}

export interface Change {
  type: 'insert' | 'delete' | 'replace';
  position: number;
  line?: number;
  oldText?: string;
  newText?: string;
  length?: number;
  text?: string;
}

export interface BufferChange {
  type: 'buffer-changed';
  file: string;
  version: number;
  changes: Change[];
  content?: string;
}

export interface AgentResponse {
  messageId: string;
  content: string;
  edits?: FileEdit[];
}

export interface WebSocketMessage {
  type: string;
  [key: string]: any;
}

export interface SyncConflict {
  file: string;
  emacsVersion: number;
  agentVersion: number;
  emacsContent: string;
  agentContent: string;
}

export interface Config {
  apiKey?: string;
  endpoint?: string;
  preferLocalModels: boolean;
  httpPort: number;
  wsPort: number;
  dbPath: string;
}
