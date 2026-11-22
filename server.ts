import crypto from 'node:crypto';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import express from 'express';
import QRCode from 'qrcode';
import swaggerUi from 'swagger-ui-express';
import { WebSocketServer, WebSocket } from 'ws';
import { openApiSpecification } from './src/server/openapi.ts';
import { CHUNKS_DIR, store, VAULT_DIR } from './src/server/store.ts';
import {
  baseGuard,
  clientIp,
  issueSessionHandler,
  pairingLookupLimiter,
  requireSession,
  sessions,
  type AuthedRequest,
} from './src/server/security/guards.ts';
import { isSafeId, safeJoin, sanitizeFilename } from './src/server/security/ids.ts';
import { isLocalAddress, isSameOrigin } from './src/server/security/network.ts';
import { extractBearer } from './src/server/security/sessions.ts';
import { generateFileId, generatePairingToken, isPairingTokenShape } from './src/server/security/tokens.ts';
import type {
  AuditLogEntry,
  DevicePlatform,
  FolderPermissionRole,
  PairingSession,
  PeerDevice,
  SharedSyncFolder,
  SystemMetricsSnapshot,
  TransferHistoryRecord,
} from './src/types/vega.ts';

const PORT = Number(process.env.PORT || 3000);
const PROTOCOL_VERSION = '1.0.0';

interface ConnectedPeerRecord {
  ws: WebSocket;
  device: PeerDevice;
  sessionToken: string;
  ip: string;
}

const MAX_CHUNKS_PER_TRANSFER = 1_000_000;
const LAN_ONLY = process.env.VEGA_LAN_ONLY === '1';
const vaultTransferOwners = new Map<string, string>();

interface WsAuth {
  session: { peerId: string };
  token: string;
  ip: string;
}
const upgradeAuth = new WeakMap<http.IncomingMessage, WsAuth>();

const connectedPeers = new Map<string, ConnectedPeerRecord>();
let activeRelayBytesWindow = 0;
let lastThroughputSampleAt = Date.now();
let currentThroughputBps = 0;
let activeTransfersCount = 0;

setInterval(() => {
  const now = Date.now();
  const elapsedSec = Math.max((now - lastThroughputSampleAt) / 1000, 1);
  currentThroughputBps = Math.round(activeRelayBytesWindow / elapsedSec);
  activeRelayBytesWindow = 0;
  lastThroughputSampleAt = now;
}, 2000).unref();

function getLivePeersList(): PeerDevice[] {
  return Array.from(connectedPeers.values()).map((entry) => entry.device);
}

function broadcastToAllPeers(payload: unknown, excludePeerId?: string): void {
  const serialized = JSON.stringify(payload);
  for (const [peerId, record] of connectedPeers.entries()) {
    if (excludePeerId && peerId === excludePeerId) continue;
    if (record.ws.readyState === WebSocket.OPEN) {
      record.ws.send(serialized);
    }
  }
}

function sendToPeer(targetPeerId: string, payload: unknown): boolean {
  const target = connectedPeers.get(targetPeerId);
  if (!target || target.ws.readyState !== WebSocket.OPEN) {
    return false;
  }
  target.ws.send(JSON.stringify(payload));
  return true;
}

function pruneExpiredPairingSessions(): void {
  const now = Date.now();
  store.mutate((draft) => {
    for (const [token, session] of Object.entries(draft.pairingSessions)) {
      if (session.status === 'pending' && new Date(session.expiresAt).getTime() <= now) {
        session.status = 'expired';
      }
      if (now - new Date(session.createdAt).getTime() > 3600_000) {
        delete draft.pairingSessions[token];
      }
    }
  });
}

async function createServer(): Promise<void> {
  const app = express();
  app.use('/api', baseGuard);
  const smallJson = express.json({ limit: '1mb' });
  const chunkJson = express.json({ limit: '24mb' });
  app.use((req, res, next) => {
    if (req.path === '/api/vault/chunk') {
      // Authenticate BEFORE buffering a large body.
      return requireSession(req, res, () => chunkJson(req, res, next));
    }
    return smallJson(req, res, next);
  });

  // Swagger OpenAPI Documentation
  app.get('/api/openapi.json', (_req, res) => {
    res.json(openApiSpecification);
  });
  app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(openApiSpecification, {
    customSiteTitle: 'Vega (वेग) API Docs (Swagger)',
  }));

  // Health Check
  app.get('/api/health', (_req, res) => {
    res.json({
      status: 'ok',
      app: 'Vega',
      version: PROTOCOL_VERSION,
      timestamp: new Date().toISOString(),
    });
  });

  // Session bootstrap (public): issues a bearer token bound to the caller's peerId.
  app.post('/api/session', (req, res) => {
    const pid = (req.body as { peerId?: unknown } | undefined)?.peerId;
    const holder = typeof pid === 'string' ? connectedPeers.get(pid) : undefined;
    if (holder && holder.ip !== clientIp(req)) {
      return res.status(409).json({ error: 'This device id is already connected from another address.' });
    }
    return issueSessionHandler(req, res);
  });

  // Everything below requires a valid session.
  app.use('/api', requireSession);

  // Real-Time System & Performance Monitoring Metrics
  app.get('/api/monitoring/metrics', (_req, res) => {
    const peers = getLivePeersList();
    const avgLatency =
      peers.length > 0
        ? Math.round(peers.reduce((sum, p) => sum + p.latencyMs, 0) / peers.length)
        : 0;
    const mem = process.memoryUsage();
    const state = store.getState();

    const snapshot: SystemMetricsSnapshot = {
      timestamp: new Date().toISOString(),
      activePeersCount: peers.length,
      activeTransfersCount,
      totalBytesTransferred: state.stats.totalBytesTransferred,
      currentThroughputBps,
      averageLatencyMs: avgLatency,
      uptimeSeconds: Math.round(process.uptime()),
      memoryRssMb: Math.round((mem.rss / (1024 * 1024)) * 10) / 10,
      heapUsedMb: Math.round((mem.heapUsed / (1024 * 1024)) * 10) / 10,
      totalVerifiedTransfers: state.stats.totalVerifiedTransfers,
      totalFailedTransfers: state.stats.totalFailedTransfers,
      protocolVersion: PROTOCOL_VERSION,
    };

    res.json(snapshot);
  });

  // Live Connected Peers
  app.get('/api/peers', (_req, res) => {
    res.json({ peers: getLivePeersList() });
  });

  // Create Expiring Cryptographic QR Pairing Session
  app.post('/api/pairing/create', async (req, res) => {
    try {
      pruneExpiredPairingSessions();
      const { peerId, deviceName, platform, fingerprint, publicKeyJwk } = req.body as {
        peerId?: string;
        deviceName?: string;
        platform?: DevicePlatform;
        fingerprint?: string;
        publicKeyJwk?: JsonWebKey | null;
      };

      if (!peerId || !deviceName || !platform) {
        return res.status(400).json({ error: 'peerId, deviceName, and platform are required.' });
      }
      if (peerId !== (req as AuthedRequest).session.peerId) {
        return res.status(403).json({ error: 'peerId does not match this session.' });
      }

      const token = generatePairingToken();
      const now = Date.now();
      const expiresAt = new Date(now + 120_000).toISOString();

      const qrPayload = JSON.stringify({
        proto: 'VEGA-1.0',
        token,
        hostPeerId: peerId,
        hostDeviceName: deviceName,
        hostPlatform: platform,
        hostFingerprint: fingerprint || 'UNSET',
        expiresAt,
      });

      const qrDataUrl = await QRCode.toDataURL(qrPayload, {
        width: 320,
        margin: 2,
        color: {
          dark: '#0A1F44',
          light: '#FFFFFF',
        },
        errorCorrectionLevel: 'M',
      });

      const session: PairingSession = {
        token,
        hostPeerId: peerId,
        hostDeviceName: deviceName,
        hostPlatform: platform,
        hostFingerprint: fingerprint || 'UNSET',
        hostPublicKeyJwk: publicKeyJwk ?? null,
        qrDataUrl,
        createdAt: new Date(now).toISOString(),
        expiresAt,
        status: 'pending',
      };

      store.mutate((draft) => {
        draft.pairingSessions[token] = session;
      });

      store.appendAuditLog({
        eventType: 'pairing_requested',
        actorDevice: deviceName,
        summary: `Generated temporary QR pairing session ${token} (expires in 120s)`,
        severity: 'info',
        metadata: { token, platform },
      });

      res.status(201).json(session);
    } catch (error) {
      console.error('QR pairing creation error:', error);
      res.status(500).json({ error: 'Failed to generate pairing session.' });
    }
  });

  // Lookup Pairing Session by Token
  app.get('/api/pairing/:token', (req, res) => {
    if (!pairingLookupLimiter.allow(clientIp(req))) {
      return res.status(429).json({ error: 'Too many attempts. Wait a minute and try again.' });
    }
    pruneExpiredPairingSessions();
    const token = req.params.token.trim().toUpperCase();
    if (!isPairingTokenShape(token)) {
      return res.status(404).json({ error: 'Pairing token not found or invalid.' });
    }
    const session = store.getState().pairingSessions[token];
    if (!session) {
      return res.status(404).json({ error: 'Pairing token not found or invalid.' });
    }
    if (session.status === 'expired' || new Date(session.expiresAt).getTime() <= Date.now()) {
      return res.status(410).json({ error: 'Pairing token has expired. Generate a fresh QR code.' });
    }
    if (session.status === 'cancelled') {
      return res.status(410).json({ error: 'Pairing session was cancelled by host.' });
    }
    res.json(session);
  });

  // Cancel Pairing Session
  app.post('/api/pairing/:token/cancel', (req, res) => {
    const token = req.params.token.trim().toUpperCase();
    const callerPeerId = (req as unknown as AuthedRequest).session.peerId;
    const updated = store.mutate((draft) => {
      const s = draft.pairingSessions[token];
      if (!s || s.hostPeerId !== callerPeerId) return null;
      s.status = 'cancelled';
      return s;
    });
    if (!updated) {
      return res.status(404).json({ error: 'Pairing session not found.' });
    }
    res.json(updated);
  });

  // Transfer History API
  app.get('/api/history', (_req, res) => {
    res.json({ history: store.getState().transferHistory });
  });

  app.post('/api/history', (req, res) => {
    const record = req.body as TransferHistoryRecord;
    if (!record || !record.id || !record.fileName) {
      return res.status(400).json({ error: 'Invalid transfer history payload.' });
    }
    store.mutate((draft) => {
      const exists = draft.transferHistory.some((h) => h.id === record.id);
      if (!exists) {
        draft.transferHistory.unshift(record);
        if (record.status === 'completed') {
          draft.stats.totalBytesTransferred += record.fileSize;
          if (record.integrityVerified) {
            draft.stats.totalVerifiedTransfers += 1;
          }
        } else if (record.status === 'failed') {
          draft.stats.totalFailedTransfers += 1;
        }
      }
    });

    store.appendAuditLog({
      eventType:
        record.status === 'completed'
          ? record.integrityVerified
            ? 'integrity_verified'
            : 'transfer_completed'
          : 'transfer_failed',
      actorDevice: record.senderName,
      targetDevice: record.receiverName,
      summary: `${record.fileName} (${record.fileSize} bytes) — ${record.status}${
        record.integrityVerified ? ' (SHA-256 verified)' : ''
      }`,
      severity: record.status === 'completed' ? 'success' : 'error',
      metadata: {
        transferId: record.id,
        sha256: record.sha256,
        encrypted: record.encrypted,
      },
    });

    res.status(201).json(record);
  });

  app.delete('/api/history', (req, res) => {
    const { ids } = (req.body || {}) as { ids?: string[] };
    store.mutate((draft) => {
      if (Array.isArray(ids) && ids.length > 0) {
        const idSet = new Set(ids);
        draft.transferHistory = draft.transferHistory.filter((item) => !idSet.has(item.id));
      } else {
        draft.transferHistory = [];
      }
    });
    res.json({ ok: true, history: store.getState().transferHistory });
  });

  // Shared Sync Folders & Granular Permissions API
  app.get('/api/folders', (_req, res) => {
    res.json({ folders: store.getState().sharedFolders });
  });

  app.post('/api/folders', (req, res) => {
    const { name, localPathLabel, conflictPolicy, actorDevice } = req.body as {
      name?: string;
      localPathLabel?: string;
      conflictPolicy?: SharedSyncFolder['conflictPolicy'];
      actorDevice?: string;
    };

    if (!name || !name.trim()) {
      return res.status(400).json({ error: 'Folder name is required.' });
    }

    const folder: SharedSyncFolder = {
      id: `folder_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
      name: name.trim(),
      localPathLabel: localPathLabel?.trim() || `~/Vega/${sanitizeFilename(name.trim())}`,
      conflictPolicy: conflictPolicy || 'newest-wins',
      autoSync: true,
      encryptionRequired: true,
      fileCount: 0,
      totalSizeBytes: 0,
      lastSyncedAt: new Date().toISOString(),
      syncStatus: 'idle',
      permissions: [],
      files: [],
    };

    store.mutate((draft) => {
      draft.sharedFolders.unshift(folder);
    });

    store.appendAuditLog({
      eventType: 'folder_sync',
      actorDevice: actorDevice || 'Local Device',
      summary: `Created shared sync folder "${folder.name}" (${folder.conflictPolicy})`,
      severity: 'info',
    });

    broadcastToAllPeers({ type: 'folders:updated' });
    res.status(201).json(folder);
  });

  app.put('/api/folders/:folderId/permissions', (req, res) => {
    const { folderId } = req.params;
    const { peerId, deviceName, platform, role, actorDevice } = req.body as {
      peerId: string;
      deviceName: string;
      platform: DevicePlatform;
      role: FolderPermissionRole;
      actorDevice?: string;
    };

    if (!peerId || !role) {
      return res.status(400).json({ error: 'peerId and role are required.' });
    }

    const updatedFolder = store.mutate((draft) => {
      const folder = draft.sharedFolders.find((f) => f.id === folderId);
      if (!folder) return null;
      const existingIdx = folder.permissions.findIndex((p) => p.peerId === peerId);
      const permEntry = {
        peerId,
        deviceName: deviceName || peerId,
        platform: platform || 'web',
        role,
        updatedAt: new Date().toISOString(),
      };
      if (existingIdx >= 0) {
        folder.permissions[existingIdx] = permEntry;
      } else {
        folder.permissions.push(permEntry);
      }
      return folder;
    });

    if (!updatedFolder) {
      return res.status(404).json({ error: 'Shared folder not found.' });
    }

    store.appendAuditLog({
      eventType: 'permission_updated',
      actorDevice: actorDevice || 'Local Owner',
      targetDevice: deviceName || peerId,
      summary: `Set "${updatedFolder.name}" permission for ${deviceName || peerId} to ${role.toUpperCase()}`,
      severity: role === 'revoked' ? 'warning' : 'info',
    });

    broadcastToAllPeers({ type: 'folders:updated' });
    res.json(updatedFolder);
  });

  app.post('/api/folders/:folderId/sync-file', (req, res) => {
    const { folderId } = req.params;
    const { relativePath, size, sha256, modifiedAt, modifiedByDevice } = req.body as {
      relativePath: string;
      size: number;
      sha256: string;
      modifiedAt?: string;
      modifiedByDevice: string;
    };

    if (!relativePath || !sha256) {
      return res.status(400).json({ error: 'relativePath and sha256 are required.' });
    }

    let conflictDetected = false;
    const updatedFolder = store.mutate((draft) => {
      const folder = draft.sharedFolders.find((f) => f.id === folderId);
      if (!folder) return null;
      const nowIso = modifiedAt || new Date().toISOString();
      const existing = folder.files.find((f) => f.relativePath === relativePath);

      if (!existing) {
        folder.files.push({
          id: `sfile_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
          relativePath,
          size: Number(size) || 0,
          sha256,
          modifiedAt: nowIso,
          modifiedByDevice: modifiedByDevice || 'Unknown',
          conflictState: 'none',
        });
      } else if (existing.sha256 !== sha256) {
        if (folder.conflictPolicy === 'manual') {
          conflictDetected = true;
          existing.conflictState = 'conflict-detected';
          existing.conflictingSha256 = sha256;
          existing.conflictingDevice = modifiedByDevice;
          folder.syncStatus = 'conflict';
        } else if (folder.conflictPolicy === 'keep-both') {
          const ext = path.extname(relativePath);
          const base = relativePath.slice(0, relativePath.length - ext.length);
          const renamedPath = `${base} (conflict ${modifiedByDevice})${ext}`;
          folder.files.push({
            id: `sfile_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
            relativePath: renamedPath,
            size: Number(size) || 0,
            sha256,
            modifiedAt: nowIso,
            modifiedByDevice: modifiedByDevice || 'Unknown',
            conflictState: 'resolved',
          });
        } else {
          // newest-wins or source-priority
          const incomingNewer =
            folder.conflictPolicy === 'source-priority' ||
            new Date(nowIso).getTime() >= new Date(existing.modifiedAt).getTime();
          if (incomingNewer) {
            existing.sha256 = sha256;
            existing.size = Number(size) || 0;
            existing.modifiedAt = nowIso;
            existing.modifiedByDevice = modifiedByDevice || 'Unknown';
            existing.conflictState = 'resolved';
          }
        }
      }

      folder.fileCount = folder.files.length;
      folder.totalSizeBytes = folder.files.reduce((acc, f) => acc + f.size, 0);
      folder.lastSyncedAt = new Date().toISOString();
      if (!folder.files.some((f) => f.conflictState === 'conflict-detected')) {
        folder.syncStatus = 'idle';
      }
      return folder;
    });

    if (!updatedFolder) {
      return res.status(404).json({ error: 'Shared folder not found.' });
    }

    store.appendAuditLog({
      eventType: 'folder_sync',
      actorDevice: modifiedByDevice || 'Peer',
      summary: conflictDetected
        ? `Sync conflict flagged on "${relativePath}" in ${updatedFolder.name}`
        : `Synchronized "${relativePath}" in ${updatedFolder.name}`,
      severity: conflictDetected ? 'warning' : 'success',
    });

    broadcastToAllPeers({ type: 'folders:updated' });
    res.json({ folder: updatedFolder, conflictDetected });
  });

  app.post('/api/folders/:folderId/resolve-conflict', (req, res) => {
    const { folderId } = req.params;
    const { fileId, resolution, actorDevice } = req.body as {
      fileId: string;
      resolution: 'keep-existing' | 'accept-incoming' | 'keep-both';
      actorDevice?: string;
    };

    const updatedFolder = store.mutate((draft) => {
      const folder = draft.sharedFolders.find((f) => f.id === folderId);
      if (!folder) return null;
      const target = folder.files.find((f) => f.id === fileId);
      if (!target) return null;

      if (resolution === 'accept-incoming' && target.conflictingSha256) {
        target.sha256 = target.conflictingSha256;
        target.modifiedByDevice = target.conflictingDevice || target.modifiedByDevice;
        target.modifiedAt = new Date().toISOString();
      } else if (resolution === 'keep-both' && target.conflictingSha256) {
        const ext = path.extname(target.relativePath);
        const base = target.relativePath.slice(0, target.relativePath.length - ext.length);
        folder.files.push({
          id: `sfile_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
          relativePath: `${base} (resolved copy)${ext}`,
          size: target.size,
          sha256: target.conflictingSha256,
          modifiedAt: new Date().toISOString(),
          modifiedByDevice: target.conflictingDevice || 'Peer',
          conflictState: 'resolved',
        });
      }
      target.conflictState = 'resolved';
      delete target.conflictingSha256;
      delete target.conflictingDevice;

      folder.fileCount = folder.files.length;
      folder.syncStatus = folder.files.some((f) => f.conflictState === 'conflict-detected')
        ? 'conflict'
        : 'idle';
      folder.lastSyncedAt = new Date().toISOString();
      return folder;
    });

    if (!updatedFolder) {
      return res.status(404).json({ error: 'Folder or file not found.' });
    }

    store.appendAuditLog({
      eventType: 'conflict_resolved',
      actorDevice: actorDevice || 'Local User',
      summary: `Resolved sync conflict in "${updatedFolder.name}" using strategy: ${resolution}`,
      severity: 'success',
    });

    broadcastToAllPeers({ type: 'folders:updated' });
    res.json(updatedFolder);
  });

  app.delete('/api/folders/:folderId', (req, res) => {
    const { folderId } = req.params;
    store.mutate((draft) => {
      draft.sharedFolders = draft.sharedFolders.filter((f) => f.id !== folderId);
    });
    broadcastToAllPeers({ type: 'folders:updated' });
    res.json({ ok: true });
  });

  // Audit Logs API
  app.get('/api/audit-logs', (_req, res) => {
    res.json({ logs: store.getState().auditLogs });
  });

  app.post('/api/audit-logs', (req, res) => {
    const entry = req.body as Omit<AuditLogEntry, 'id' | 'timestamp'>;
    if (!entry || !entry.eventType || !entry.summary) {
      return res.status(400).json({ error: 'eventType and summary are required.' });
    }
    const created = store.appendAuditLog(entry);
    res.status(201).json(created);
  });

  // Resumable Encrypted Vault / Relay Chunk Upload & SHA-256 Verification API
  app.post('/api/vault/chunk', (req, res) => {
    try {
      const { transferId, chunkIndex, dataBase64 } = req.body as {
        transferId: string;
        chunkIndex: number;
        dataBase64: string;
      };
      if (!isSafeId(transferId) || !Number.isInteger(chunkIndex) || typeof dataBase64 !== 'string' || !dataBase64) {
        return res.status(400).json({ error: 'Valid transferId, integer chunkIndex, and dataBase64 are required.' });
      }
      if (chunkIndex < 0 || chunkIndex >= MAX_CHUNKS_PER_TRANSFER) {
        return res.status(400).json({ error: 'chunkIndex out of range.' });
      }
      const callerPeerId = (req as AuthedRequest).session.peerId;
      const owner = vaultTransferOwners.get(transferId);
      if (owner && owner !== callerPeerId) {
        return res.status(403).json({ error: 'This transfer belongs to another device.' });
      }
      vaultTransferOwners.set(transferId, callerPeerId);
      const transferChunkDir = safeJoin(CHUNKS_DIR, transferId);
      if (!fs.existsSync(transferChunkDir)) {
        fs.mkdirSync(transferChunkDir, { recursive: true });
      }
      const chunkBuffer = Buffer.from(dataBase64, 'base64');
      activeRelayBytesWindow += chunkBuffer.length;
      fs.writeFileSync(path.join(transferChunkDir, `${String(chunkIndex).padStart(8, '0')}.part`), chunkBuffer);
      res.json({ ok: true, chunkIndex, bytes: chunkBuffer.length });
    } catch (error) {
      console.error('Chunk upload error:', error);
      res.status(500).json({ error: 'Failed to store transfer chunk.' });
    }
  });

  app.post('/api/vault/complete', async (req, res) => {
    try {
      const { transferId, fileName, totalChunks, expectedSha256 } = req.body as {
        transferId: string;
        fileName: string;
        totalChunks: number;
        expectedSha256?: string;
      };
      if (
        !isSafeId(transferId) ||
        typeof fileName !== 'string' ||
        !fileName ||
        !Number.isInteger(totalChunks) ||
        totalChunks < 1 ||
        totalChunks > MAX_CHUNKS_PER_TRANSFER
      ) {
        return res.status(400).json({ error: 'Valid transferId, fileName, and totalChunks are required.' });
      }
      if (vaultTransferOwners.get(transferId) !== (req as AuthedRequest).session.peerId) {
        return res.status(403).json({ error: 'This transfer belongs to another device.' });
      }
      const safeName = sanitizeFilename(fileName);
      const transferChunkDir = safeJoin(CHUNKS_DIR, transferId);

      const finalFileId = `${generateFileId()}_${safeName}`;
      const finalPath = safeJoin(VAULT_DIR, finalFileId);

      const hash = crypto.createHash('sha256');
      const writeStream = fs.createWriteStream(finalPath);
      const streamDone = new Promise<void>((resolve, reject) => {
        writeStream.on('finish', () => resolve());
        writeStream.on('error', (err) => reject(err));
      });
      let totalSize = 0;

      for (let i = 0; i < totalChunks; i++) {
        const partPath = path.join(transferChunkDir, `${String(i).padStart(8, '0')}.part`);
        if (!fs.existsSync(partPath)) {
          writeStream.destroy();
          return res.status(400).json({ error: `Missing chunk ${i} during assembly.` });
        }
        const chunkData = fs.readFileSync(partPath);
        hash.update(chunkData);
        writeStream.write(chunkData);
        totalSize += chunkData.length;
      }
      writeStream.end();
      await streamDone;

      const actualSha256 = hash.digest('hex');
      const verified = !expectedSha256 || expectedSha256.toLowerCase() === actualSha256.toLowerCase();

      // Cleanup chunk directory (transferChunkDir is guaranteed to be a strict child of CHUNKS_DIR)
      fs.rmSync(transferChunkDir, { recursive: true, force: true });
      vaultTransferOwners.delete(transferId);

      res.json({
        ok: true,
        fileId: finalFileId,
        size: totalSize,
        sha256: actualSha256,
        verified,
        downloadUrl: `/api/vault/download/${encodeURIComponent(finalFileId)}`,
      });
    } catch (error) {
      console.error('Vault assembly error:', error);
      res.status(500).json({ error: 'Failed to finalize file transfer.' });
    }
  });

  app.get('/api/vault/download/:fileId', (req, res) => {
    const safeId = req.params.fileId;
    if (!/^[a-f0-9]{32}_[^/\\]{1,120}$/.test(safeId)) {
      return res.status(400).json({ error: 'Invalid file id.' });
    }
    const filePath = safeJoin(VAULT_DIR, safeId);
    if (!fs.existsSync(filePath)) {
      return res.status(404).json({ error: 'File not found in local vault.' });
    }
    res.download(filePath, safeId.slice(33));
  });

  // Direct ZIP Bundle Download Endpoint
  app.get('/download/vega-app.zip', (_req, res) => {
    const zipPath = path.resolve(process.cwd(), 'release', 'vega-app.zip');
    if (!fs.existsSync(zipPath)) {
      return res.status(404).json({ error: 'ZIP package not found.' });
    }
    res.setHeader('Content-Type', 'application/zip');
    res.setHeader('Content-Disposition', 'attachment; filename="vega-app.zip"');
    res.sendFile(zipPath);
  });

  const httpServer = http.createServer(app);

  // Frontend Serving (Vite Dev Middleware vs Production Dist)
  if (process.env.NODE_ENV !== 'production') {
    process.env.DISABLE_HMR = process.env.DISABLE_HMR || 'true';
    const { createServer: createViteServer } = await import('vite');
    const vite = await createViteServer({
      server: {
        middlewareMode: true,
        ws: { server: httpServer },
        hmr: { server: httpServer },
      },
      appType: 'spa',
    });
    app.use(vite.middlewares);
  } else {
    const distDir = path.resolve(process.cwd(), 'dist');
    app.use(express.static(distDir));
    app.get('*', (_req, res) => {
      res.sendFile(path.join(distDir, 'index.html'));
    });
  }

  // Bind real-time WebSocket signaling & zero-Base64 binary relay hub on /ws
  const wss = new WebSocketServer({
    noServer: true,
    perMessageDeflate: false,
    maxPayload: 32 * 1024 * 1024,
  });

  httpServer.on('upgrade', (req, socket, head) => {
    const pathname = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`).pathname;
    if (pathname !== '/ws') return;
    const reject = (code: number, reason: string) => {
      socket.write(`HTTP/1.1 ${code} ${reason}\r\nConnection: close\r\n\r\n`);
      socket.destroy();
    };
    const ip = req.socket.remoteAddress || 'unknown';
    if (LAN_ONLY && !isLocalAddress(ip)) return reject(403, 'Forbidden');
    if (!isSameOrigin(req.headers.origin, req.headers.host)) return reject(403, 'Forbidden');
    const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);
    const token = url.searchParams.get('t') || extractBearer(req.headers.authorization);
    const session = sessions.verify(token);
    if (!session || !token) return reject(401, 'Unauthorized');
    upgradeAuth.set(req, { session, token, ip });
    wss.handleUpgrade(req, socket, head, (ws) => {
      wss.emit('connection', ws, req);
    });
  });

  wss.on('connection', (ws, req) => {
    const auth = upgradeAuth.get(req);
    if (!auth) {
      ws.close(1008, 'Unauthorized');
      return;
    }
    let registeredPeerId: string | null = null;

    ws.on('message', (rawData, isBinary) => {
      if (isBinary) {
        const buf = Buffer.isBuffer(rawData)
          ? rawData
          : Array.isArray(rawData)
            ? Buffer.concat(rawData)
            : Buffer.from(rawData as ArrayBuffer);
        // Binary Vega frame: [0x56 ('V'), flags(1), targetIdLen(2 BE), targetPeerId(...), payload...]
        // Hot path: one boolean check (sender must be registered) + a length bound; no extra copies.
        if (registeredPeerId && buf.byteLength >= 4 && buf[0] === 0x56) {
          const targetLen = buf.readUInt16BE(2);
          if (targetLen > 0 && targetLen <= 128 && 4 + targetLen <= buf.byteLength) {
            const targetPeerId = buf.subarray(4, 4 + targetLen).toString('utf8');
            const target = connectedPeers.get(targetPeerId);
            if (target && target.ws.readyState === WebSocket.OPEN) {
              activeRelayBytesWindow += buf.byteLength;
              target.ws.send(buf, { binary: true });
            }
          }
        }
        return;
      }

      try {
        const msg = JSON.parse(rawData.toString()) as {
          type: string;
          targetPeerId?: string;
          [key: string]: unknown;
        };

        if (msg.type === 'peer:register') {
          const device = msg.device as PeerDevice;
          if (!device || !device.peerId) return;
          if (device.peerId !== auth.session.peerId) {
            ws.send(JSON.stringify({ type: 'relay:error', originalType: 'peer:register', error: 'peerId does not match session.' }));
            return;
          }
          const incumbent = connectedPeers.get(device.peerId);
          if (incumbent && incumbent.ws !== ws && incumbent.sessionToken !== auth.token && incumbent.ip !== auth.ip) {
            ws.send(JSON.stringify({ type: 'relay:error', originalType: 'peer:register', error: 'Device id already connected.' }));
            return;
          }
          registeredPeerId = device.peerId;
          connectedPeers.set(device.peerId, {
            ws,
            sessionToken: auth.token,
            ip: auth.ip,
            device: {
              ...device,
              online: true,
              lastSeenAt: new Date().toISOString(),
            },
          });
          broadcastToAllPeers({ type: 'peers:list', peers: getLivePeersList() });
          return;
        }

        if (msg.type === 'peer:ping') {
          ws.send(JSON.stringify({ type: 'peer:pong', clientSentAt: msg.clientSentAt }));
          if (registeredPeerId && typeof msg.latencyMs === 'number') {
            const rec = connectedPeers.get(registeredPeerId);
            if (rec) {
              rec.device.latencyMs = msg.latencyMs;
              rec.device.lastSeenAt = new Date().toISOString();
            }
          }
          return;
        }

        if (!registeredPeerId) return; // everything below requires a registered peer

        if (msg.type === 'transfer:metrics') {
          if (typeof msg.bytesDelta === 'number') {
            activeRelayBytesWindow += msg.bytesDelta;
          }
          if (typeof msg.activeCount === 'number') {
            activeTransfersCount = msg.activeCount;
          }
          return;
        }

        // Targeted signaling & encrypted P2P chunk/control relay
        if (msg.targetPeerId) {
          if (msg.type === 'transfer:chunk' && typeof msg.chunkLength === 'number') {
            activeRelayBytesWindow += msg.chunkLength;
          }
          if (msg.type === 'pairing:response' && typeof msg.token === 'string') {
            const approved = Boolean(msg.approved);
            const responderId = registeredPeerId;
            store.mutate((draft) => {
              const s = draft.pairingSessions[(msg.token as string).toUpperCase()];
              // Only the host that created the session may decide it, and only once.
              if (s && s.hostPeerId === responderId && s.status === 'pending') {
                s.status = approved ? 'approved' : 'rejected';
              }
            });
          }

          const delivered = sendToPeer(msg.targetPeerId, {
            ...msg,
            fromPeerId: registeredPeerId,
          });
          if (!delivered && msg.type !== 'webrtc:ice-candidate') {
            ws.send(
              JSON.stringify({
                type: 'relay:error',
                originalType: msg.type,
                targetPeerId: msg.targetPeerId,
                error: 'Target peer is currently offline or unreachable.',
              })
            );
          }
        }
      } catch (err) {
        console.error('WebSocket message parse error:', err);
      }
    });

    ws.on('close', () => {
      if (registeredPeerId && connectedPeers.get(registeredPeerId)?.ws === ws) {
        connectedPeers.delete(registeredPeerId);
        broadcastToAllPeers({ type: 'peers:list', peers: getLivePeersList() });
      }
    });
  });

  httpServer.listen(PORT, '0.0.0.0', () => {
    console.log(`Vega (वेग) server listening on http://0.0.0.0:${PORT}`);
    console.log(`Swagger API docs available at http://localhost:${PORT}/api-docs`);
  });
}

createServer().catch((err) => {
  console.error('Fatal server startup failure:', err);
  process.exit(1);
});
