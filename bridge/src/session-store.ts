import Database from 'better-sqlite3';
import { Session } from './types';

export class SessionStore {
  private db: Database.Database;

  constructor(dbPath: string) {
    this.db = new Database(dbPath);
    this.initializeDatabase();
  }

  private initializeDatabase(): void {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS sessions (
        id TEXT PRIMARY KEY,
        model TEXT NOT NULL,
        workspace TEXT,
        context TEXT,
        created_at INTEGER NOT NULL,
        last_active INTEGER NOT NULL
      )
    `);
  }

  save(session: Session): void {
    const stmt = this.db.prepare(`
      INSERT OR REPLACE INTO sessions
      (id, model, workspace, context, created_at, last_active)
      VALUES (?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      session.id,
      session.model,
      session.workspace || null,
      JSON.stringify(session.context),
      session.createdAt,
      session.lastActive
    );
  }

  load(sessionId: string): Session | null {
    const stmt = this.db.prepare('SELECT * FROM sessions WHERE id = ?');
    const row = stmt.get(sessionId) as any;

    if (!row) return null;

    return {
      id: row.id,
      model: row.model,
      workspace: row.workspace,
      context: JSON.parse(row.context),
      createdAt: row.created_at,
      lastActive: row.last_active
    };
  }

  list(): Session[] {
    const stmt = this.db.prepare('SELECT * FROM sessions ORDER BY last_active DESC');
    const rows = stmt.all() as any[];

    return rows.map(row => ({
      id: row.id,
      model: row.model,
      workspace: row.workspace,
      context: JSON.parse(row.context),
      createdAt: row.created_at,
      lastActive: row.last_active
    }));
  }

  delete(sessionId: string): void {
    const stmt = this.db.prepare('DELETE FROM sessions WHERE id = ?');
    stmt.run(sessionId);
  }

  updateLastActive(sessionId: string): void {
    const stmt = this.db.prepare('UPDATE sessions SET last_active = ? WHERE id = ?');
    stmt.run(Date.now(), sessionId);
  }

  close(): void {
    this.db.close();
  }
}
