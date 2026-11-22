import type {
  AppNotification,
  AppSettings,
  LocalFileItem,
  TransferHistoryRecord,
  TrustedDevice,
} from '../types/vega.ts';

const DB_NAME = 'vega_offline_db';
const DB_VERSION = 1;

interface StoredFileRecord {
  meta: LocalFileItem;
  blob: Blob;
}

interface StoredChunkRecord {
  key: string; // `${transferId}:${chunkIndex}`
  transferId: string;
  chunkIndex: number;
  bytes: Uint8Array;
}

let dbPromise: Promise<IDBDatabase> | null = null;

function openDb(): Promise<IDBDatabase> {
  if (dbPromise) return dbPromise;
  dbPromise = new Promise<IDBDatabase>((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains('files')) {
        db.createObjectStore('files', { keyPath: 'meta.id' });
      }
      if (!db.objectStoreNames.contains('trusted_devices')) {
        db.createObjectStore('trusted_devices', { keyPath: 'id' });
      }
      if (!db.objectStoreNames.contains('history')) {
        db.createObjectStore('history', { keyPath: 'id' });
      }
      if (!db.objectStoreNames.contains('chunks')) {
        const store = db.createObjectStore('chunks', { keyPath: 'key' });
        store.createIndex('transferId', 'transferId', { unique: false });
      }
      if (!db.objectStoreNames.contains('notifications')) {
        db.createObjectStore('notifications', { keyPath: 'id' });
      }
      if (!db.objectStoreNames.contains('kv')) {
        db.createObjectStore('kv', { keyPath: 'key' });
      }
    };
    req.onsuccess = () => {
      const db = req.result;
      db.onclose = () => {
        dbPromise = null;
      };
      db.onversionchange = () => {
        db.close();
        dbPromise = null;
      };
      resolve(db);
    };
    req.onerror = () => {
      dbPromise = null;
      reject(req.error);
    };
  });
  return dbPromise;
}

async function idbGetAll<T>(storeName: string): Promise<T[]> {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, 'readonly');
    const req = tx.objectStore(storeName).getAll();
    req.onsuccess = () => resolve(req.result as T[]);
    req.onerror = () => reject(req.error);
  });
}

async function idbPut<T>(storeName: string, value: T): Promise<void> {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, 'readwrite');
    tx.objectStore(storeName).put(value);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

async function idbDelete(storeName: string, key: string): Promise<void> {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, 'readwrite');
    tx.objectStore(storeName).delete(key);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

async function idbClear(storeName: string): Promise<void> {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, 'readwrite');
    tx.objectStore(storeName).clear();
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

export const offlineDb = {
  async saveFile(meta: LocalFileItem, blob: Blob): Promise<void> {
    await idbPut<StoredFileRecord>('files', { meta, blob });
  },

  async listFiles(): Promise<LocalFileItem[]> {
    const rows = await idbGetAll<StoredFileRecord>('files');
    return rows
      .map((r) => r.meta)
      .sort((a, b) => new Date(b.modifiedAt).getTime() - new Date(a.modifiedAt).getTime());
  },

  async getFileBlob(id: string): Promise<Blob | null> {
    const db = await openDb();
    return new Promise((resolve, reject) => {
      const tx = db.transaction('files', 'readonly');
      const req = tx.objectStore('files').get(id);
      req.onsuccess = () => {
        const rec = req.result as StoredFileRecord | undefined;
        resolve(rec ? rec.blob : null);
      };
      req.onerror = () => reject(req.error);
    });
  },

  async deleteFile(id: string): Promise<void> {
    await idbDelete('files', id);
  },

  async saveTrustedDevice(device: TrustedDevice): Promise<void> {
    await idbPut('trusted_devices', device);
  },

  async listTrustedDevices(): Promise<TrustedDevice[]> {
    const list = await idbGetAll<TrustedDevice>('trusted_devices');
    return list.sort(
      (a, b) => new Date(b.lastConnectedAt).getTime() - new Date(a.lastConnectedAt).getTime()
    );
  },

  async deleteTrustedDevice(id: string): Promise<void> {
    await idbDelete('trusted_devices', id);
  },

  async saveHistoryRecord(record: TransferHistoryRecord): Promise<void> {
    await idbPut('history', record);
    try {
      const existing = JSON.parse(localStorage.getItem('vega_transfer_history') || '[]') as TransferHistoryRecord[];
      const next = [record, ...existing.filter((r) => r.id !== record.id)];
      localStorage.setItem('vega_transfer_history', JSON.stringify(next));
    } catch {
      // ignore storage quota errors
    }
  },

  async listHistory(): Promise<TransferHistoryRecord[]> {
    const list = await idbGetAll<TransferHistoryRecord>('history');
    if (list.length === 0) {
      try {
        const ls = JSON.parse(localStorage.getItem('vega_transfer_history') || '[]') as TransferHistoryRecord[];
        if (Array.isArray(ls) && ls.length > 0) {
          return ls.sort((a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime());
        }
      } catch {
        // ignore parse errors
      }
    }
    return list.sort((a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime());
  },

  async deleteHistoryRecord(id: string): Promise<void> {
    await idbDelete('history', id);
    try {
      const existing = JSON.parse(localStorage.getItem('vega_transfer_history') || '[]') as TransferHistoryRecord[];
      localStorage.setItem(
        'vega_transfer_history',
        JSON.stringify(existing.filter((r) => r.id !== id))
      );
    } catch {
      // ignore
    }
  },

  async clearHistory(): Promise<void> {
    await idbClear('history');
    try {
      localStorage.removeItem('vega_transfer_history');
    } catch {
      // ignore
    }
  },

  async saveChunk(transferId: string, chunkIndex: number, bytes: Uint8Array): Promise<void> {
    await idbPut<StoredChunkRecord>('chunks', {
      key: `${transferId}:${chunkIndex}`,
      transferId,
      chunkIndex,
      bytes,
    });
  },

  async saveChunksBatch(
    transferId: string,
    entries: Array<{ chunkIndex: number; bytes: Uint8Array }>
  ): Promise<void> {
    if (entries.length === 0) return;
    const db = await openDb();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction('chunks', 'readwrite');
      const store = tx.objectStore('chunks');
      for (const entry of entries) {
        store.put({
          key: `${transferId}:${entry.chunkIndex}`,
          transferId,
          chunkIndex: entry.chunkIndex,
          bytes: entry.bytes,
        } satisfies StoredChunkRecord);
      }
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  },

  async getChunksForTransfer(transferId: string): Promise<StoredChunkRecord[]> {
    const db = await openDb();
    return new Promise((resolve, reject) => {
      const tx = db.transaction('chunks', 'readonly');
      const index = tx.objectStore('chunks').index('transferId');
      const req = index.getAll(transferId);
      req.onsuccess = () => {
        const rows = (req.result as StoredChunkRecord[]).sort(
          (a, b) => a.chunkIndex - b.chunkIndex
        );
        resolve(rows);
      };
      req.onerror = () => reject(req.error);
    });
  },

  async clearChunksForTransfer(transferId: string): Promise<void> {
    const db = await openDb();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction('chunks', 'readwrite');
      const store = tx.objectStore('chunks');
      const index = store.index('transferId');
      const keyReq = index.getAllKeys(transferId);
      keyReq.onsuccess = () => {
        const keys = keyReq.result;
        for (const key of keys) {
          store.delete(key);
        }
      };
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  },

  async clearAllChunks(): Promise<void> {
    await idbClear('chunks');
  },

  async getAllChunkBytesCount(): Promise<number> {
    const rows = await idbGetAll<StoredChunkRecord>('chunks');
    return rows.reduce((sum, r) => sum + r.bytes.byteLength, 0);
  },

  async saveNotification(notif: AppNotification): Promise<void> {
    await idbPut('notifications', notif);
  },

  async listNotifications(): Promise<AppNotification[]> {
    const list = await idbGetAll<AppNotification>('notifications');
    return list.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
  },

  async clearNotifications(): Promise<void> {
    await idbClear('notifications');
  },

  async getKv<T>(key: string): Promise<T | null> {
    const db = await openDb();
    return new Promise((resolve, reject) => {
      const tx = db.transaction('kv', 'readonly');
      const req = tx.objectStore('kv').get(key);
      req.onsuccess = () => {
        const row = req.result as { key: string; value: T } | undefined;
        resolve(row ? row.value : null);
      };
      req.onerror = () => reject(req.error);
    });
  },

  async setKv<T>(key: string, value: T): Promise<void> {
    await idbPut('kv', { key, value });
  },

  async loadSettings(defaultSettings: AppSettings): Promise<AppSettings> {
    const saved = await this.getKv<Partial<AppSettings>>('app_settings');
    const merged = { ...defaultSettings, ...(saved || {}) };
    if (merged.chunkSizeKb < defaultSettings.chunkSizeKb) {
      merged.chunkSizeKb = defaultSettings.chunkSizeKb;
    }
    return merged;
  },

  async saveSettings(settings: AppSettings): Promise<void> {
    await this.setKv('app_settings', settings);
  },
};
