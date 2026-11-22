import fs from 'node:fs';
import path from 'node:path';
import type {
  AuditLogEntry,
  PairingSession,
  SharedSyncFolder,
  TransferHistoryRecord,
} from '../types/vega.ts';

export interface ServerDatabaseState {
  transferHistory: TransferHistoryRecord[];
  sharedFolders: SharedSyncFolder[];
  auditLogs: AuditLogEntry[];
  pairingSessions: Record<string, PairingSession>;
  stats: {
    totalBytesTransferred: number;
    totalVerifiedTransfers: number;
    totalFailedTransfers: number;
  };
}

const DATA_DIR = path.resolve(process.cwd(), '.vega-data');
const DB_FILE = path.join(DATA_DIR, 'db.json');
export const VAULT_DIR = path.join(DATA_DIR, 'vault');
export const CHUNKS_DIR = path.join(DATA_DIR, 'chunks');

function ensureDirectories(): void {
  for (const dir of [DATA_DIR, VAULT_DIR, CHUNKS_DIR]) {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  }
}

const DEFAULT_STATE: ServerDatabaseState = {
  transferHistory: [],
  sharedFolders: [
    {
      id: 'folder-team-exchange',
      name: 'Vega Shared Exchange',
      localPathLabel: '~/Vega/SharedExchange',
      conflictPolicy: 'newest-wins',
      autoSync: true,
      encryptionRequired: true,
      fileCount: 0,
      totalSizeBytes: 0,
      lastSyncedAt: new Date().toISOString(),
      syncStatus: 'idle',
      permissions: [],
      files: [],
    },
  ],
  auditLogs: [],
  pairingSessions: {},
  stats: {
    totalBytesTransferred: 0,
    totalVerifiedTransfers: 0,
    totalFailedTransfers: 0,
  },
};

class LocalTransactionalStore {
  private state: ServerDatabaseState;

  constructor() {
    ensureDirectories();
    this.state = this.loadFromDisk();
  }

  private loadFromDisk(): ServerDatabaseState {
    try {
      if (!fs.existsSync(DB_FILE)) {
        this.persistAtomic(DEFAULT_STATE);
        return structuredClone(DEFAULT_STATE);
      }
      const raw = fs.readFileSync(DB_FILE, 'utf-8');
      const parsed = JSON.parse(raw) as Partial<ServerDatabaseState>;
      return {
        transferHistory: Array.isArray(parsed.transferHistory) ? parsed.transferHistory : [],
        sharedFolders:
          Array.isArray(parsed.sharedFolders) && parsed.sharedFolders.length > 0
            ? parsed.sharedFolders
            : structuredClone(DEFAULT_STATE.sharedFolders),
        auditLogs: Array.isArray(parsed.auditLogs) ? parsed.auditLogs : [],
        pairingSessions: parsed.pairingSessions ?? {},
        stats: parsed.stats ?? structuredClone(DEFAULT_STATE.stats),
      };
    } catch (error) {
      console.error('Failed to read local store, initializing clean state:', error);
      return structuredClone(DEFAULT_STATE);
    }
  }

  private persistAtomic(nextState: ServerDatabaseState): void {
    ensureDirectories();
    const tempFile = `${DB_FILE}.${process.pid}.${Date.now()}.tmp`;
    fs.writeFileSync(tempFile, JSON.stringify(nextState, null, 2), 'utf-8');
    fs.renameSync(tempFile, DB_FILE);
  }

  public getState(): ServerDatabaseState {
    return this.state;
  }

  public mutate<T>(fn: (draft: ServerDatabaseState) => T): T {
    const result = fn(this.state);
    this.persistAtomic(this.state);
    return result;
  }

  public appendAuditLog(entry: Omit<AuditLogEntry, 'id' | 'timestamp'>): AuditLogEntry {
    const record: AuditLogEntry = {
      ...entry,
      id: `aud_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
      timestamp: new Date().toISOString(),
    };
    this.mutate((draft) => {
      draft.auditLogs.unshift(record);
      if (draft.auditLogs.length > 1000) {
        draft.auditLogs = draft.auditLogs.slice(0, 1000);
      }
    });
    return record;
  }
}

export const store = new LocalTransactionalStore();
