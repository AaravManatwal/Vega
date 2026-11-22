import React, { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import {
  computeBlobSha256Streaming,
  deriveSharedSessionKey,
  DeviceIdentityKeys,
  generateDeviceIdentityKeys,
} from '../lib/crypto.ts';
import {
  categorizeFile,
  detectDevicePlatform,
  getDefaultDeviceName,
} from '../lib/formatters.ts';
import { getTranslations } from '../lib/i18n.ts';
import { apiFetch, configureApi, getSessionToken } from '../lib/apiClient.ts';
import { offlineDb } from '../lib/offlineDb.ts';
import { TransferEngine, type IncomingCompletionResult } from '../utils/TransferEngine.ts';
import { WebRtcPeerManager } from '../utils/WebRtcPeerManager.ts';
import type { ToastItem, ToastVariant } from '../components/ToastContainer.tsx';
import type {
  AppNotification,
  AppSettings,
  AppTheme,
  AuditLogEntry,
  DevicePlatform,
  DuplicatePolicy,
  FileCategory,
  FolderPermissionRole,
  LocalFileItem,
  PairingRequestPayload,
  PairingSession,
  PeerDevice,
  ScreenId,
  SharedSyncFolder,
  SystemMetricsSnapshot,
  TransferHistoryRecord,
  TransferJob,
  TrustedDevice,
} from '../types/vega.ts';

interface PendingIncomingTransfer {
  transferId: string;
  batchId: string;
  senderPeerId: string;
  senderName: string;
  senderPlatform: DevicePlatform;
  senderPublicKeyJwk: JsonWebKey | null;
  fileName: string;
  relativePath: string;
  mimeType: string;
  fileSize: number;
  totalChunks: number;
  chunkSize: number;
  sha256Expected: string;
}

interface VegaContextValue {
  screen: ScreenId;
  setScreen: (screen: ScreenId) => void;
  fileManagerCategory: 'all' | FileCategory;
  setFileManagerCategory: (cat: 'all' | FileCategory) => void;
  selectedTransferId: string | null;
  setSelectedTransferId: (id: string | null) => void;
  selectedSendPeerId: string | null;
  setSelectedSendPeerId: (peerId: string | null) => void;
  preselectedSendFiles: Array<{ file: File; relativePath: string }>;
  queuePreselectedSendFiles: (items: Array<{ file: File; relativePath: string }>) => void;
  clearPreselectedSendFiles: () => void;

  peerId: string;
  platform: DevicePlatform;
  identity: DeviceIdentityKeys | null;
  settings: AppSettings;
  updateSettings: (patch: Partial<AppSettings>) => Promise<void>;
  t: ReturnType<typeof getTranslations>;

  wsConnected: boolean;
  isOffline: boolean;
  discoveryActive: boolean;
  setDiscoveryActive: (active: boolean) => void;
  refreshDiscovery: () => void;
  peers: PeerDevice[];

  trustedDevices: TrustedDevice[];
  renameTrustedDevice: (id: string, localAlias: string) => Promise<void>;
  removeTrustedDevice: (id: string) => Promise<void>;
  isPeerTrusted: (peerId: string) => boolean;

  activePairingSession: PairingSession | null;
  generateQrPairing: () => Promise<PairingSession | null>;
  cancelQrPairing: () => Promise<void>;
  requestPairingWithToken: (token: string) => Promise<{ ok: boolean; error?: string }>;
  requestPairingWithPeer: (peer: PeerDevice) => void;
  incomingPairingRequest: PairingRequestPayload | null;
  respondToPairingRequest: (approved: boolean) => Promise<void>;

  localFiles: LocalFileItem[];
  addFilesToVault: (files: File[], source?: LocalFileItem['source']) => Promise<LocalFileItem[]>;
  deleteLocalFile: (id: string) => Promise<void>;
  downloadLocalFile: (item: LocalFileItem) => Promise<void>;

  transfers: TransferJob[];
  pendingIncomingTransfer: PendingIncomingTransfer | null;
  respondToIncomingTransfer: (accepted: boolean) => Promise<void>;
  startFileTransfer: (
    files: Array<{ file: File; relativePath?: string }>,
    targetPeer: PeerDevice,
    duplicatePolicy?: DuplicatePolicy
  ) => Promise<void>;
  pauseTransfer: (transferId: string) => void;
  resumeTransfer: (transferId: string) => Promise<void>;
  cancelTransfer: (transferId: string) => void;
  retryTransfer: (transferId: string) => Promise<void>;
  pauseAllTransfers: () => void;
  resumeAllTransfers: () => Promise<void>;
  cancelAllTransfers: () => void;

  history: TransferHistoryRecord[];
  deleteHistoryRecords: (ids: string[]) => Promise<void>;
  clearAllHistory: () => Promise<void>;

  sharedFolders: SharedSyncFolder[];
  refreshFolders: () => Promise<void>;
  createSharedFolder: (name: string, conflictPolicy: SharedSyncFolder['conflictPolicy']) => Promise<void>;
  updateFolderPermission: (
    folderId: string,
    peer: { peerId: string; deviceName: string; platform: DevicePlatform },
    role: FolderPermissionRole
  ) => Promise<void>;
  syncFilesToSharedFolder: (folderId: string, files: File[]) => Promise<{ synced: number; conflicts: number }>;
  resolveFolderConflict: (
    folderId: string,
    fileId: string,
    resolution: 'keep-existing' | 'accept-incoming' | 'keep-both'
  ) => Promise<void>;
  deleteSharedFolder: (folderId: string) => Promise<void>;

  auditLogs: AuditLogEntry[];
  refreshAuditLogs: () => Promise<void>;
  metrics: SystemMetricsSnapshot | null;
  refreshMetrics: () => Promise<void>;

  notifications: AppNotification[];
  markAllNotificationsRead: () => Promise<void>;
  clearNotifications: () => Promise<void>;

  toasts: ToastItem[];
  showToast: (toast: Omit<ToastItem, 'id'>) => void;
  dismissToast: (id: string) => void;

  storageEstimate: { usageBytes: number; quotaBytes: number; vaultBytes: number; chunkCacheBytes: number };
  refreshStorageEstimate: () => Promise<void>;
  clearChunkCache: () => Promise<void>;
}

const VegaContext = createContext<VegaContextValue | null>(null);

function getOrCreatePeerId(): string {
  const existing = sessionStorage.getItem('vega_peer_id');
  if (existing) return existing;
  const fresh = `peer_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 7)}`;
  sessionStorage.setItem('vega_peer_id', fresh);
  return fresh;
}

export function VegaProvider({ children }: { children: React.ReactNode }) {
  const platform = useMemo(() => detectDevicePlatform(), []);
  const peerId = useMemo(() => {
    const id = getOrCreatePeerId();
    configureApi(id);
    return id;
  }, []);

  const defaultSettings: AppSettings = useMemo(() => {
    let storedTheme: AppTheme = 'dark';
    try {
      const saved = localStorage.getItem('vega_theme');
      if (saved === 'light' || saved === 'dark') storedTheme = saved;
    } catch {
      // ignore localStorage restrictions
    }
    return {
      deviceName: getDefaultDeviceName(platform),
      language: 'en',
      theme: storedTheme,
      downloadLocation: platform === 'android' ? '/storage/emulated/0/Download/Vega' : 'C:\\Users\\Downloads\\Vega',
      chunkSizeKb: 512,
      requireApprovalForKnown: false,
      verifySha256: true,
      enableNotifications: true,
      enableAnimations: true,
      reducedMotion: false,
      hapticFeedback: true,
      duplicatePolicy: 'rename',
      conflictPolicy: 'newest-wins',
    };
  }, [platform]);

  const [screen, setScreen] = useState<ScreenId>('dashboard');
  const [fileManagerCategory, setFileManagerCategory] = useState<'all' | FileCategory>('all');
  const [selectedTransferId, setSelectedTransferId] = useState<string | null>(null);
  const [selectedSendPeerId, setSelectedSendPeerId] = useState<string | null>(null);
  const [preselectedSendFiles, setPreselectedSendFiles] = useState<
    Array<{ file: File; relativePath: string }>
  >([]);
  const [settings, setSettings] = useState<AppSettings>(defaultSettings);
  const [identity, setIdentity] = useState<DeviceIdentityKeys | null>(null);

  const [wsConnected, setWsConnected] = useState(false);
  const [isOffline, setIsOffline] = useState(!navigator.onLine);
  const [discoveryActive, setDiscoveryActive] = useState(true);
  const [peers, setPeers] = useState<PeerDevice[]>([]);
  const [trustedDevices, setTrustedDevices] = useState<TrustedDevice[]>([]);
  const [activePairingSession, setActivePairingSession] = useState<PairingSession | null>(null);
  const [incomingPairingRequest, setIncomingPairingRequest] = useState<PairingRequestPayload | null>(null);

  const [localFiles, setLocalFiles] = useState<LocalFileItem[]>([]);
  const [transfers, setTransfers] = useState<TransferJob[]>([]);
  const [pendingIncomingTransfer, setPendingIncomingTransfer] = useState<PendingIncomingTransfer | null>(null);
  const [history, setHistory] = useState<TransferHistoryRecord[]>([]);
  const [sharedFolders, setSharedFolders] = useState<SharedSyncFolder[]>([]);
  const [auditLogs, setAuditLogs] = useState<AuditLogEntry[]>([]);
  const [metrics, setMetrics] = useState<SystemMetricsSnapshot | null>(null);
  const [notifications, setNotifications] = useState<AppNotification[]>([]);
  const [toasts, setToasts] = useState<ToastItem[]>([]);
  const [storageEstimate, setStorageEstimate] = useState({
    usageBytes: 0,
    quotaBytes: 0,
    vaultBytes: 0,
    chunkCacheBytes: 0,
  });

  const wsRef = useRef<WebSocket | null>(null);
  const wsHadConnectedRef = useRef(false);
  const settingsRef = useRef(settings);
  settingsRef.current = settings;
  const identityRef = useRef(identity);
  identityRef.current = identity;
  const peersRef = useRef(peers);
  peersRef.current = peers;
  const pendingIncomingQueueRef = useRef<PendingIncomingTransfer[]>([]);
  const pendingAcceptMapRef = useRef<Map<string, (accepted: boolean) => void>>(new Map());
  const incomingJobsRef = useRef<Map<string, TransferJob>>(new Map());
  const transferEngineRef = useRef<TransferEngine | null>(null);
  const webRtcRef = useRef<WebRtcPeerManager | null>(null);

  const t = useMemo(() => getTranslations(settings.language), [settings.language]);

  const dismissToast = useCallback((id: string) => {
    setToasts((prev) => prev.filter((item) => item.id !== id));
  }, []);

  const showToast = useCallback(
    (toast: Omit<ToastItem, 'id'>) => {
      const id = `toast_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;
      setToasts((prev) => [{ ...toast, id }, ...prev].slice(0, 4));
      setTimeout(() => {
        setToasts((prev) => prev.filter((item) => item.id !== id));
      }, 4500);
    },
    []
  );

  const pushNotification = useCallback(
    async (notif: Omit<AppNotification, 'id' | 'createdAt' | 'read'>) => {
      if (!settingsRef.current.enableNotifications) return;
      const item: AppNotification = {
        ...notif,
        id: `notif_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
        createdAt: new Date().toISOString(),
        read: false,
      };
      setNotifications((prev) => [item, ...prev].slice(0, 100));
      await offlineDb.saveNotification(item);

      const toastVariant: ToastVariant =
        notif.type === 'success' || notif.type === 'error' || notif.type === 'warning'
          ? notif.type
          : 'info';
      showToast({
        title: notif.title,
        message: notif.message,
        variant: toastVariant,
        actionLabel: notif.actionScreen ? 'View' : undefined,
        onAction: notif.actionScreen ? () => setScreen(notif.actionScreen!) : undefined,
      });
    },
    [showToast]
  );

  // Sync theme ('light' / 'dark') & reduced-motion root CSS classes onto <html>
  useEffect(() => {
    const root = document.documentElement;
    root.classList.remove('light', 'dark');
    root.classList.add(settings.theme);
    root.style.colorScheme = settings.theme;
    try {
      localStorage.setItem('vega_theme', settings.theme);
    } catch {
      // ignore
    }
    root.lang = settings.language;
    document.title =
      settings.language === 'hi'
        ? 'वेग (Vega) — ऑफ़लाइन फ़ाइल शेयरिंग'
        : 'Vega (वेग) — Universal Offline File Transfer';
    if (settings.reducedMotion || !settings.enableAnimations) {
      root.classList.add('reduced-motion');
    } else {
      root.classList.remove('reduced-motion');
    }
  }, [settings.theme, settings.language, settings.reducedMotion, settings.enableAnimations]);

  const refreshStorageEstimate = useCallback(async () => {
    try {
      const files = await offlineDb.listFiles();
      const vaultBytes = files.reduce((s, f) => s + f.size, 0);
      const chunkCacheBytes = await offlineDb.getAllChunkBytesCount();
      let usageBytes = vaultBytes + chunkCacheBytes;
      let quotaBytes = 1024 * 1024 * 1024;
      if (navigator.storage && navigator.storage.estimate) {
        const est = await navigator.storage.estimate();
        usageBytes = est.usage ?? usageBytes;
        quotaBytes = est.quota ?? quotaBytes;
      }
      setStorageEstimate({ usageBytes, quotaBytes, vaultBytes, chunkCacheBytes });
    } catch {
      // ignore storage estimate failure on restricted browsers
    }
  }, []);

  const refreshFolders = useCallback(async () => {
    try {
      const res = await apiFetch('/api/folders');
      if (res.ok) {
        const data = (await res.json()) as { folders: SharedSyncFolder[] };
        setSharedFolders(data.folders);
      }
    } catch {
      // offline fallback preserves existing folders
    }
  }, []);

  const refreshAuditLogs = useCallback(async () => {
    try {
      const res = await apiFetch('/api/audit-logs');
      if (res.ok) {
        const data = (await res.json()) as { logs: AuditLogEntry[] };
        setAuditLogs(data.logs);
      }
    } catch {
      // offline fallback
    }
  }, []);

  const refreshMetrics = useCallback(async () => {
    try {
      const res = await apiFetch('/api/monitoring/metrics');
      if (res.ok) {
        const data = (await res.json()) as SystemMetricsSnapshot;
        setMetrics(data);
      }
    } catch {
      // offline fallback
    }
  }, []);

  // Initial Hydration (IndexedDB + Crypto Keys + Onboarding check)
  useEffect(() => {
    let active = true;
    (async () => {
      const [loadedSettings, keys, files, trusted, localHist, notifs] = await Promise.all([
        offlineDb.loadSettings(defaultSettings),
        generateDeviceIdentityKeys(),
        offlineDb.listFiles(),
        offlineDb.listTrustedDevices(),
        offlineDb.listHistory(),
        offlineDb.listNotifications(),
      ]);
      if (!active) return;
      setSettings(loadedSettings);
      setIdentity(keys);
      setLocalFiles(files);
      setTrustedDevices(trusted);
      let storedLocalHist: TransferHistoryRecord[] = [];
      try {
        const raw = localStorage.getItem('vega_transfer_history');
        if (raw) {
          const parsed = JSON.parse(raw);
          if (Array.isArray(parsed)) storedLocalHist = parsed as TransferHistoryRecord[];
        }
      } catch {
        // ignore
      }

      const initialMerged = new Map<string, TransferHistoryRecord>();
      for (const item of [...storedLocalHist, ...localHist]) {
        initialMerged.set(item.id, item);
      }
      const initialHistoryList = Array.from(initialMerged.values()).sort(
        (a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime()
      );
      setHistory(initialHistoryList);
      setNotifications(notifs);
      refreshStorageEstimate();

      // Merge server history if reachable
      try {
        const histRes = await apiFetch('/api/history');
        if (histRes.ok) {
          const serverData = (await histRes.json()) as { history: TransferHistoryRecord[] };
          if (serverData.history.length > 0) {
            const merged = new Map<string, TransferHistoryRecord>();
            for (const item of [...initialHistoryList, ...serverData.history]) {
              merged.set(item.id, item);
            }
            const sortedMerged = Array.from(merged.values()).sort(
              (a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime()
            );
            setHistory(sortedMerged);
            try {
              localStorage.setItem('vega_transfer_history', JSON.stringify(sortedMerged));
            } catch {
              // ignore
            }
          }
        }
      } catch {
        // offline
      }

      await Promise.all([refreshFolders(), refreshAuditLogs(), refreshMetrics()]);
    })();
    return () => {
      active = false;
    };
  }, [defaultSettings, refreshAuditLogs, refreshFolders, refreshMetrics, refreshStorageEstimate]);

  // Network online/offline listeners
  useEffect(() => {
    const onOnline = () => setIsOffline(false);
    const onOffline = () => setIsOffline(true);
    window.addEventListener('online', onOnline);
    window.addEventListener('offline', onOffline);
    return () => {
      window.removeEventListener('online', onOnline);
      window.removeEventListener('offline', onOffline);
    };
  }, []);

  const updateSettings = useCallback(async (patch: Partial<AppSettings>) => {
    setSettings((prev) => {
      const sanitizedPatch = { ...patch };
      if (typeof sanitizedPatch.deviceName === 'string') {
        const trimmed = sanitizedPatch.deviceName.trim().slice(0, 40);
        sanitizedPatch.deviceName = trimmed || prev.deviceName;
      }
      const next = { ...prev, ...sanitizedPatch };
      void offlineDb.saveSettings(next);
      return next;
    });
  }, []);

  const sendWsMessage = useCallback((payload: Record<string, unknown>) => {
    const ws = wsRef.current;
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(payload));
      return true;
    }
    return false;
  }, []);

  const sendWsBinaryChunk = useCallback(
    (
      targetPeerId: string,
      packet: {
        transferId: string;
        chunkIndex: number;
        encrypted: boolean;
        ivBytes: Uint8Array;
        cipherBytes: Uint8Array;
      }
    ): boolean => {
      const ws = wsRef.current;
      if (!ws || ws.readyState !== WebSocket.OPEN) return false;
      const enc = new TextEncoder();
      const targetBytes = enc.encode(targetPeerId);
      const tidBytes = enc.encode(packet.transferId);
      const ivLen = packet.encrypted ? packet.ivBytes.byteLength : 0;
      const headerLen = 2 + 2 + targetBytes.byteLength + 2 + tidBytes.byteLength + 4 + 1 + ivLen;
      const frame = new Uint8Array(headerLen + packet.cipherBytes.byteLength);
      const view = new DataView(frame.buffer);
      let off = 0;
      frame[off++] = 0x56; // 'V' magic
      frame[off++] = packet.encrypted ? 1 : 0;
      view.setUint16(off, targetBytes.byteLength, false);
      off += 2;
      frame.set(targetBytes, off);
      off += targetBytes.byteLength;
      view.setUint16(off, tidBytes.byteLength, false);
      off += 2;
      frame.set(tidBytes, off);
      off += tidBytes.byteLength;
      view.setUint32(off, packet.chunkIndex, false);
      off += 4;
      frame[off++] = ivLen;
      if (ivLen > 0) {
        frame.set(packet.ivBytes, off);
        off += ivLen;
      }
      frame.set(packet.cipherBytes, off);
      ws.send(frame);
      return true;
    },
    []
  );

  const recordCompletedHistory = useCallback(
    async (job: TransferJob) => {
      const record: TransferHistoryRecord = {
        id: job.id,
        fileName: job.fileName,
        fileCategory: categorizeFile(job.fileName, job.mimeType),
        mimeType: job.mimeType,
        fileSize: job.fileSize,
        direction: job.direction,
        senderName: job.senderName,
        receiverName: job.receiverName,
        senderPlatform: job.senderPlatform,
        receiverPlatform: job.receiverPlatform,
        status: job.status === 'completed' ? 'completed' : job.status === 'cancelled' ? 'cancelled' : 'failed',
        sha256: job.sha256Verified || job.sha256Expected,
        integrityVerified: job.integrityVerified,
        encrypted: job.encrypted,
        connectionMethod: job.connectionMethod,
        startedAt: job.startedAt,
        completedAt: job.completedAt || new Date().toISOString(),
        durationMs: job.durationMs,
        averageSpeedBps: job.speedBytesPerSec,
      };
      setHistory((prev) => {
        const next = [record, ...prev.filter((h) => h.id !== record.id)];
        try {
          localStorage.setItem('vega_transfer_history', JSON.stringify(next));
        } catch {
          // ignore
        }
        return next;
      });
      await offlineDb.saveHistoryRecord(record);
      try {
        await apiFetch('/api/history', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(record),
        });
        void refreshAuditLogs();
        void refreshMetrics();
      } catch {
        // persisted locally in IndexedDB while offline
      }
    },
    [refreshAuditLogs, refreshMetrics]
  );

  const finalizeIncomingFile = useCallback(
    async (
      transferId: string,
      jobSnapshot: TransferJob,
      result: IncomingCompletionResult
    ) => {
      if (!result.complete || !result.verified || !result.sha256) return;
      const blob =
        result.assembledBlob ??
        (result.assembledBytes
          ? new Blob([result.assembledBytes.buffer as ArrayBuffer], {
              type: jobSnapshot.mimeType || 'application/octet-stream',
            })
          : null);
      if (!blob) return;
      const savedFile: LocalFileItem = {
        id: `file_${transferId}`,
        name: jobSnapshot.fileName,
        relativePath: jobSnapshot.relativePath || jobSnapshot.fileName,
        folderName: 'Received',
        mimeType: jobSnapshot.mimeType || 'application/octet-stream',
        size: jobSnapshot.fileSize,
        category: categorizeFile(jobSnapshot.fileName, jobSnapshot.mimeType),
        sha256: result.sha256,
        modifiedAt: new Date().toISOString(),
        source: 'received',
        encrypted: jobSnapshot.encrypted,
        verified: true,
      };
      await offlineDb.saveFile(savedFile, blob);
      setLocalFiles((prev) => [savedFile, ...prev]);
      void refreshStorageEstimate();

      sendWsMessage({
        type: 'transfer:verified',
        targetPeerId: jobSnapshot.senderPeerId,
        transferId,
        sha256: result.sha256,
        verified: true,
      });

      await pushNotification({
        title: 'File Received',
        message: `${jobSnapshot.fileName} received from ${jobSnapshot.senderName}.`,
        type: 'success',
        actionScreen: 'file-manager',
        relatedId: savedFile.id,
      });
    },
    [pushNotification, refreshStorageEstimate, sendWsMessage]
  );

  // Initialize WebRtcPeerManager singleton for direct zero-Base64 binary DataChannel streaming
  if (!webRtcRef.current) {
    webRtcRef.current = new WebRtcPeerManager({
      localPeerId: peerId,
      sendSignal: (targetPeerId, type, payload) =>
        sendWsMessage({
          type,
          targetPeerId,
          ...payload,
        }),
      onBinaryChunk: (_fromPeerId, frame) => {
        const engine = transferEngineRef.current;
        if (!engine) return;
        void engine
          .receiveRawChunk({
            transferId: frame.transferId,
            chunkIndex: frame.chunkIndex,
            encrypted: frame.encrypted,
            iv: frame.iv,
            payload: frame.payload,
            isDirectP2p: true,
          })
          .then((res) => {
            if (!res.complete) return;
            const jobSnapshot =
              engine.getIncomingJob(frame.transferId) || incomingJobsRef.current.get(frame.transferId);
            if (jobSnapshot) {
              return finalizeIncomingFile(frame.transferId, jobSnapshot, res);
            }
          });
      },
    });
  }

  // Initialize TransferEngine singleton once hooks are ready
  if (!transferEngineRef.current) {
    transferEngineRef.current = new TransferEngine({
      onJobUpdate: (updatedJob) => {
        if (updatedJob.direction === 'receive') {
          if (
            updatedJob.status === 'completed' ||
            updatedJob.status === 'cancelled' ||
            updatedJob.status === 'failed'
          ) {
            incomingJobsRef.current.delete(updatedJob.id);
          } else {
            incomingJobsRef.current.set(updatedJob.id, updatedJob);
          }
        }
        setTransfers((prev) => {
          const exists = prev.some((j) => j.id === updatedJob.id);
          return exists
            ? prev.map((j) => (j.id === updatedJob.id ? updatedJob : j))
            : [updatedJob, ...prev];
        });
        if (updatedJob.errorCode === 'NETWORK_DISCONNECTED' && updatedJob.errorMessage) {
          showToast({
            title: 'Transfer Interrupted',
            message: updatedJob.errorMessage,
            variant: 'error',
          });
        }
      },
      isDirectP2pReady: (targetPeerId) => Boolean(webRtcRef.current?.isChannelOpen(targetPeerId)),
      onSendChunk: async (targetPeerId, packet) => {
        if (webRtcRef.current?.isChannelOpen(targetPeerId)) {
          const ok = await webRtcRef.current.sendBinaryChunk(targetPeerId, {
            transferId: packet.transferId,
            chunkIndex: packet.chunkIndex,
            encrypted: packet.encrypted,
            iv: packet.ivBytes,
            payload: packet.cipherBytes,
          });
          if (ok) return true;
        }
        return sendWsBinaryChunk(targetPeerId, packet);
      },
      onControlSignal: (targetPeerId, transferId, action) => {
        sendWsMessage({
          type: 'transfer:control',
          targetPeerId,
          transferId,
          action,
        });
      },
      onCompleted: async (completedJob) => {
        await recordCompletedHistory(completedJob);
        if (completedJob.direction === 'send') {
          await pushNotification({
            title: 'File Sent',
            message: `${completedJob.fileName} sent to ${completedJob.receiverName}.`,
            type: 'success',
            actionScreen: 'transfer-details',
            relatedId: completedJob.id,
          });
        }
      },
      onFailed: async (failedJob, reason) => {
        await recordCompletedHistory(failedJob);
        await pushNotification({
          title: 'Transfer Failed',
          message: `${failedJob.fileName}: ${reason}`,
          type: 'error',
          actionScreen: 'transfer-details',
          relatedId: failedJob.id,
        });
      },
    });
  }

  // Connect WebSocket signaling & handle real-time messages
  useEffect(() => {
    if (!identity) return;

    let disposed = false;
    let reconnectTimer: ReturnType<typeof setTimeout> | null = null;
    let pingTimer: ReturnType<typeof setInterval> | null = null;

    const connect = async () => {
      if (disposed) return;
      let sessionToken: string;
      try {
        sessionToken = await getSessionToken();
      } catch {
        if (!disposed) reconnectTimer = setTimeout(() => void connect(), 3000);
        return;
      }
      if (disposed) return;
      const proto = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
      const ws = new WebSocket(`${proto}//${window.location.host}/ws?t=${encodeURIComponent(sessionToken)}`);
      ws.binaryType = 'arraybuffer';
      wsRef.current = ws;
      let everOpened = false;

      ws.onopen = () => {
        if (disposed) return;
        everOpened = true;
        setWsConnected(true);
        if (wsHadConnectedRef.current) {
          showToast({
            title: 'Network Ready',
            message: 'Ready to find nearby devices and share files.',
            variant: 'success',
          });
        } else {
          wsHadConnectedRef.current = true;
        }
        ws.send(
          JSON.stringify({
            type: 'peer:register',
            device: {
              peerId,
              deviceName: settingsRef.current.deviceName,
              platform,
              userAgentSummary: navigator.userAgent.slice(0, 64),
              publicKeyJwk: identity.publicKeyJwk,
              fingerprint: identity.fingerprint,
              connectionMethod: 'local-wifi-ws',
              latencyMs: 4,
              online: true,
              trusted: false,
              lastSeenAt: new Date().toISOString(),
            } satisfies PeerDevice,
          })
        );

        pingTimer = setInterval(() => {
          if (ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({ type: 'peer:ping', clientSentAt: Date.now() }));
          }
        }, 5000);
      };

      ws.onmessage = async (event) => {
        try {
          if (event.data instanceof ArrayBuffer) {
            const buf = new Uint8Array(event.data);
            if (buf.byteLength < 10 || buf[0] !== 0x56) return;
            const view = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
            let off = 1;
            const encrypted = (buf[off++] & 1) === 1;
            const targetLen = view.getUint16(off, false);
            off += 2 + targetLen;
            if (off + 7 > buf.byteLength) return;
            const tidLen = view.getUint16(off, false);
            off += 2;
            const decoder = new TextDecoder();
            const transferId = decoder.decode(buf.subarray(off, off + tidLen));
            off += tidLen;
            const chunkIndex = view.getUint32(off, false);
            off += 4;
            const ivLen = buf[off++];
            const iv = ivLen > 0 ? buf.subarray(off, off + ivLen) : new Uint8Array(0);
            off += ivLen;
            const payload = buf.subarray(off);

            const engine = transferEngineRef.current;
            if (!engine) return;
            const result = await engine.receiveRawChunk({
              transferId,
              chunkIndex,
              encrypted,
              iv,
              payload,
              isDirectP2p: false,
            });
            if (result.complete) {
              const jobSnapshot =
                engine.getIncomingJob(transferId) || incomingJobsRef.current.get(transferId);
              if (jobSnapshot) {
                await finalizeIncomingFile(transferId, jobSnapshot, result);
              }
            }
            return;
          }

          const msg = JSON.parse(event.data as string) as Record<string, unknown>;
          const type = msg.type as string;

          if (type === 'peer:pong' && typeof msg.clientSentAt === 'number') {
            const rtt = Math.max(1, Date.now() - msg.clientSentAt);
            ws.send(JSON.stringify({ type: 'peer:ping', latencyMs: rtt }));
            return;
          }

          if (type === 'peers:list' && Array.isArray(msg.peers)) {
            const incomingPeers = (msg.peers as PeerDevice[]).filter((p) => p.peerId !== peerId);
            setPeers(incomingPeers);
            return;
          }

          if (type === 'folders:updated') {
            void refreshFolders();
            void refreshAuditLogs();
            return;
          }

          if (type === 'pairing:request') {
            const payload = msg.payload as PairingRequestPayload;
            setIncomingPairingRequest(payload);
            void pushNotification({
              title: 'Connection Request',
              message: `${payload.fromDeviceName} wants to connect with this device.`,
              type: 'info',
              actionScreen: 'receive',
            });
            return;
          }

          if (type === 'pairing:response') {
            const approved = Boolean(msg.approved);
            const responder = msg.responder as {
              peerId: string;
              deviceName: string;
              platform: DevicePlatform;
              fingerprint: string;
              publicKeyJwk: JsonWebKey | null;
            };
            if (approved && responder) {
              const trustedItem: TrustedDevice = {
                id: `td_${responder.peerId}`,
                peerId: responder.peerId,
                deviceName: responder.deviceName,
                localAlias: responder.deviceName,
                platform: responder.platform,
                fingerprint: responder.fingerprint,
                publicKeyJwk: responder.publicKeyJwk,
                approvedAt: new Date().toISOString(),
                lastConnectedAt: new Date().toISOString(),
                transferCount: 0,
                totalBytesTransferred: 0,
              };
              await offlineDb.saveTrustedDevice(trustedItem);
              setTrustedDevices(await offlineDb.listTrustedDevices());
              setActivePairingSession((prev) => (prev ? { ...prev, status: 'approved' } : prev));
              void pushNotification({
                title: 'Device Connected',
                message: `${responder.deviceName} is now connected.`,
                type: 'success',
                actionScreen: 'receive',
              });
            } else {
              setActivePairingSession((prev) => (prev ? { ...prev, status: 'rejected' } : prev));
              void pushNotification({
                title: 'Connection Declined',
                message: `${responder?.deviceName || 'Device'} declined the request.`,
                type: 'warning',
              });
            }
            return;
          }

          if (type === 'transfer:init') {
            const reqPayload = msg.transfer as PendingIncomingTransfer;
            const trustedList = await offlineDb.listTrustedDevices();
            const isTrusted = trustedList.some((td) => td.peerId === reqPayload.senderPeerId);

            if (isTrusted && !settingsRef.current.requireApprovalForKnown) {
              await acceptIncomingTransferInternal(reqPayload);
            } else {
              setPendingIncomingTransfer((current) => {
                if (current) {
                  pendingIncomingQueueRef.current.push(reqPayload);
                  return current;
                }
                return reqPayload;
              });
              void pushNotification({
                title: 'Incoming File',
                message: `${reqPayload.senderName} wants to send "${reqPayload.fileName}".`,
                type: 'info',
                actionScreen: 'receive',
              });
            }
            return;
          }

          if (type === 'transfer:accept' || type === 'transfer:reject') {
            const transferId = msg.transferId as string;
            const resolve = pendingAcceptMapRef.current.get(transferId);
            if (resolve) {
              pendingAcceptMapRef.current.delete(transferId);
              resolve(type === 'transfer:accept');
            }
            return;
          }

          if (type === 'webrtc:offer' || type === 'webrtc:answer' || type === 'webrtc:ice-candidate') {
            const fromPeerId = msg.fromPeerId as string | undefined;
            if (fromPeerId) {
              void webRtcRef.current?.handleSignal(fromPeerId, type, msg);
            }
            return;
          }

          if (type === 'transfer:chunk') {
            const transferId = msg.transferId as string;
            const chunkIndex = msg.chunkIndex as number;
            const ivBase64 = msg.ivBase64 as string;
            const cipherBase64 = msg.cipherBase64 as string;

            const engine = transferEngineRef.current;
            if (!engine) return;

            const result = await engine.receiveChunk({
              transferId,
              chunkIndex,
              ivBase64,
              cipherBase64,
            });

            if (result.complete) {
              const jobSnapshot =
                engine.getIncomingJob(transferId) || incomingJobsRef.current.get(transferId);
              if (jobSnapshot) {
                await finalizeIncomingFile(transferId, jobSnapshot, result);
              }
            }
            return;
          }

          if (type === 'transfer:control') {
            const transferId = msg.transferId as string;
            const action = msg.action as 'pause' | 'resume' | 'cancel';
            transferEngineRef.current?.applyIncomingControl(transferId, action);
            return;
          }

          if (type === 'transfer:verified') {
            const transferId = msg.transferId as string;
            const sha256 = msg.sha256 as string;
            setTransfers((prev) =>
              prev.map((j) =>
                j.id === transferId
                  ? {
                      ...j,
                      status: 'completed',
                      sha256Verified: sha256,
                      integrityVerified: true,
                      completedAt: new Date().toISOString(),
                    }
                  : j
              )
            );
            return;
          }
        } catch (err) {
          console.error('WS incoming handler error:', err);
        }
      };

      ws.onclose = () => {
        setWsConnected(false);
        // Never opened => token likely stale (server restarted): renew it for the next attempt.
        if (!everOpened) void getSessionToken(true).catch(() => undefined);
        if (pingTimer) clearInterval(pingTimer);
        if (!disposed) {
          if (wsHadConnectedRef.current) {
            showToast({
              title: 'Reconnecting',
              message: 'Connecting to your local Wi-Fi...',
              variant: 'warning',
            });
          }
          reconnectTimer = setTimeout(() => void connect(), 3000);
        }
      };
    };

    void connect();

    return () => {
      disposed = true;
      if (pingTimer) clearInterval(pingTimer);
      if (reconnectTimer) clearTimeout(reconnectTimer);
      if (wsRef.current) wsRef.current.close();
    };
  }, [
    finalizeIncomingFile,
    identity,
    peerId,
    platform,
    pushNotification,
    refreshAuditLogs,
    refreshFolders,
    refreshStorageEstimate,
    sendWsMessage,
    showToast,
  ]);

  // Re-register peer name when settings.deviceName changes
  useEffect(() => {
    if (!wsConnected || !identity) return;
    sendWsMessage({
      type: 'peer:register',
      device: {
        peerId,
        deviceName: settings.deviceName,
        platform,
        userAgentSummary: navigator.userAgent.slice(0, 64),
        publicKeyJwk: identity.publicKeyJwk,
        fingerprint: identity.fingerprint,
        connectionMethod: 'local-wifi-ws',
        latencyMs: 4,
        online: true,
        trusted: false,
        lastSeenAt: new Date().toISOString(),
      } satisfies PeerDevice,
    });
  }, [identity, peerId, platform, sendWsMessage, settings.deviceName, wsConnected]);

  const acceptIncomingTransferInternal = useCallback(
    async (reqPayload: PendingIncomingTransfer) => {
      let sessionKey: CryptoKey | null = null;
      if (identityRef.current && reqPayload.senderPublicKeyJwk) {
        sessionKey = await deriveSharedSessionKey(
          identityRef.current.privateKey,
          reqPayload.senderPublicKeyJwk
        );
      }

      const job: TransferJob = {
        id: reqPayload.transferId,
        batchId: reqPayload.batchId,
        direction: 'receive',
        fileName: reqPayload.fileName,
        relativePath: reqPayload.relativePath,
        mimeType: reqPayload.mimeType,
        fileSize: reqPayload.fileSize,
        bytesTransferred: 0,
        totalChunks: reqPayload.totalChunks,
        completedChunks: 0,
        chunkSize: reqPayload.chunkSize,
        speedBytesPerSec: 0,
        etaSeconds: 0,
        status: 'transferring',
        senderPeerId: reqPayload.senderPeerId,
        senderName: reqPayload.senderName,
        senderPlatform: reqPayload.senderPlatform,
        receiverPeerId: peerId,
        receiverName: settingsRef.current.deviceName,
        receiverPlatform: platform,
        sha256Expected: reqPayload.sha256Expected,
        sha256Verified: null,
        integrityVerified: false,
        encrypted: Boolean(sessionKey),
        encryptionAlgorithm: 'AES-256-GCM',
        connectionMethod: 'local-wifi-ws',
        duplicatePolicy: settingsRef.current.duplicatePolicy,
        startedAt: new Date().toISOString(),
        completedAt: null,
        durationMs: 0,
      };

      incomingJobsRef.current.set(reqPayload.transferId, job);
      sendWsMessage({
        type: 'transfer:accept',
        targetPeerId: reqPayload.senderPeerId,
        transferId: reqPayload.transferId,
      });

      const replayResult = await transferEngineRef.current?.registerIncomingTransfer(job, sessionKey);
      if (replayResult?.complete) {
        await finalizeIncomingFile(reqPayload.transferId, job, replayResult);
      }
    },
    [finalizeIncomingFile, peerId, platform, sendWsMessage]
  );

  const respondToIncomingTransfer = useCallback(
    async (accepted: boolean) => {
      const current = pendingIncomingTransfer;
      if (!current) return;

      if (accepted) {
        await acceptIncomingTransferInternal(current);
      } else {
        sendWsMessage({
          type: 'transfer:reject',
          targetPeerId: current.senderPeerId,
          transferId: current.transferId,
        });
      }

      const nextInQueue = pendingIncomingQueueRef.current.shift() || null;
      setPendingIncomingTransfer(nextInQueue);
    },
    [acceptIncomingTransferInternal, pendingIncomingTransfer, sendWsMessage]
  );

  const refreshDiscovery = useCallback(() => {
    setDiscoveryActive(true);
    if (identity) {
      sendWsMessage({
        type: 'peer:register',
        device: {
          peerId,
          deviceName: settingsRef.current.deviceName,
          platform,
          userAgentSummary: navigator.userAgent.slice(0, 64),
          publicKeyJwk: identity.publicKeyJwk,
          fingerprint: identity.fingerprint,
          connectionMethod: 'local-wifi-ws',
          latencyMs: 4,
          online: true,
          trusted: false,
          lastSeenAt: new Date().toISOString(),
        },
      });
    }
  }, [identity, peerId, platform, sendWsMessage]);

  const isPeerTrusted = useCallback(
    (targetPeerId: string) => trustedDevices.some((td) => td.peerId === targetPeerId),
    [trustedDevices]
  );

  const renameTrustedDevice = useCallback(async (id: string, localAlias: string) => {
    setTrustedDevices((prev) => {
      const updated = prev.map((d) => (d.id === id ? { ...d, localAlias } : d));
      const found = updated.find((d) => d.id === id);
      if (found) void offlineDb.saveTrustedDevice(found);
      return updated;
    });
  }, []);

  const removeTrustedDevice = useCallback(async (id: string) => {
    const target = trustedDevices.find((d) => d.id === id);
    await offlineDb.deleteTrustedDevice(id);
    setTrustedDevices((prev) => prev.filter((d) => d.id !== id));
    if (target) {
      try {
        await apiFetch('/api/audit-logs', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            eventType: 'trust_revoked',
            actorDevice: settingsRef.current.deviceName,
            targetDevice: target.localAlias || target.deviceName,
            summary: `Revoked trust for ${target.localAlias || target.deviceName} (${target.fingerprint})`,
            severity: 'warning',
          }),
        });
        void refreshAuditLogs();
      } catch {
        // offline
      }
    }
  }, [refreshAuditLogs, trustedDevices]);

  const generateQrPairing = useCallback(async (): Promise<PairingSession | null> => {
    if (!identity) return null;
    try {
      const res = await apiFetch('/api/pairing/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          peerId,
          deviceName: settings.deviceName,
          platform,
          fingerprint: identity.fingerprint,
          publicKeyJwk: identity.publicKeyJwk,
        }),
      });
      if (!res.ok) return null;
      const session = (await res.json()) as PairingSession;
      setActivePairingSession(session);
      void refreshAuditLogs();
      return session;
    } catch {
      return null;
    }
  }, [identity, peerId, platform, refreshAuditLogs, settings.deviceName]);

  const cancelQrPairing = useCallback(async () => {
    if (!activePairingSession) return;
    try {
      await apiFetch(`/api/pairing/${encodeURIComponent(activePairingSession.token)}/cancel`, {
        method: 'POST',
      });
    } catch {
      // ignore
    }
    setActivePairingSession(null);
  }, [activePairingSession]);

  const requestPairingWithToken = useCallback(
    async (rawInput: string): Promise<{ ok: boolean; error?: string }> => {
      if (!identity) return { ok: false, error: 'Identity keys not initialized.' };
      let token = rawInput.trim();
      try {
        if (token.startsWith('{')) {
          const parsed = JSON.parse(token) as { token?: string };
          if (parsed.token) token = parsed.token;
        }
      } catch {
        // plain token string
      }
      token = token.toUpperCase();
      try {
        const res = await apiFetch(`/api/pairing/${encodeURIComponent(token)}`);
        if (!res.ok) {
          const errData = (await res.json().catch(() => ({}))) as { error?: string };
          return { ok: false, error: errData.error || 'Invalid or expired pairing code.' };
        }
        const session = (await res.json()) as PairingSession;
        if (session.hostPeerId === peerId) {
          return { ok: false, error: 'Cannot pair a device with itself.' };
        }
        const payload: PairingRequestPayload = {
          requestId: `preq_${Date.now()}`,
          token: session.token,
          fromPeerId: peerId,
          fromDeviceName: settings.deviceName,
          fromPlatform: platform,
          fromFingerprint: identity.fingerprint,
          fromPublicKeyJwk: identity.publicKeyJwk,
          requestedAt: new Date().toISOString(),
        };
        const sent = sendWsMessage({
          type: 'pairing:request',
          targetPeerId: session.hostPeerId,
          payload,
        });
        if (!sent) {
          return { ok: false, error: 'Other device is not connected right now.' };
        }
        return { ok: true };
      } catch {
        return { ok: false, error: 'Could not verify the code. Try again.' };
      }
    },
    [identity, peerId, platform, sendWsMessage, settings.deviceName]
  );

  const requestPairingWithPeer = useCallback(
    (peer: PeerDevice) => {
      if (!identity) return;
      const payload: PairingRequestPayload = {
        requestId: `preq_${Date.now()}`,
        token: `DIRECT-${peer.peerId.slice(-4).toUpperCase()}`,
        fromPeerId: peerId,
        fromDeviceName: settings.deviceName,
        fromPlatform: platform,
        fromFingerprint: identity.fingerprint,
        fromPublicKeyJwk: identity.publicKeyJwk,
        requestedAt: new Date().toISOString(),
      };
      sendWsMessage({
        type: 'pairing:request',
        targetPeerId: peer.peerId,
        payload,
      });
      void pushNotification({
        title: 'Connection Request Sent',
        message: `Waiting for ${peer.deviceName} to accept.`,
        type: 'info',
      });
    },
    [identity, peerId, platform, pushNotification, sendWsMessage, settings.deviceName]
  );

  const respondToPairingRequest = useCallback(
    async (approved: boolean) => {
      const req = incomingPairingRequest;
      if (!req || !identity) return;

      sendWsMessage({
        type: 'pairing:response',
        targetPeerId: req.fromPeerId,
        token: req.token,
        approved,
        responder: {
          peerId,
          deviceName: settings.deviceName,
          platform,
          fingerprint: identity.fingerprint,
          publicKeyJwk: identity.publicKeyJwk,
        },
      });

      if (approved) {
        const trustedItem: TrustedDevice = {
          id: `td_${req.fromPeerId}`,
          peerId: req.fromPeerId,
          deviceName: req.fromDeviceName,
          localAlias: req.fromDeviceName,
          platform: req.fromPlatform,
          fingerprint: req.fromFingerprint,
          publicKeyJwk: req.fromPublicKeyJwk,
          approvedAt: new Date().toISOString(),
          lastConnectedAt: new Date().toISOString(),
          transferCount: 0,
          totalBytesTransferred: 0,
        };
        await offlineDb.saveTrustedDevice(trustedItem);
        setTrustedDevices(await offlineDb.listTrustedDevices());
      }

      try {
        await apiFetch('/api/audit-logs', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            eventType: approved ? 'pairing_approved' : 'pairing_rejected',
            actorDevice: settings.deviceName,
            targetDevice: req.fromDeviceName,
            summary: `${approved ? 'Approved' : 'Rejected'} pairing with ${req.fromDeviceName} (${req.fromFingerprint})`,
            severity: approved ? 'success' : 'warning',
          }),
        });
        void refreshAuditLogs();
      } catch {
        // offline
      }

      setIncomingPairingRequest(null);
    },
    [identity, incomingPairingRequest, peerId, platform, refreshAuditLogs, sendWsMessage, settings.deviceName]
  );

  const addFilesToVault = useCallback(
    async (files: File[], source: LocalFileItem['source'] = 'local-vault') => {
      const added: LocalFileItem[] = [];
      const concurrency = 3;
      for (let i = 0; i < files.length; i += concurrency) {
        const batch = files.slice(i, i + concurrency);
        const results = await Promise.all(
          batch.map(async (file) => {
            const sha256 = await computeBlobSha256Streaming(file);
            const relPath =
              (file as File & { webkitRelativePath?: string }).webkitRelativePath || file.name;
            const item: LocalFileItem = {
              id: `file_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
              name: file.name,
              relativePath: relPath,
              folderName: relPath.includes('/') ? relPath.split('/')[0] : 'Local Vault',
              mimeType: file.type || 'application/octet-stream',
              size: file.size,
              category: categorizeFile(file.name, file.type),
              sha256,
              modifiedAt: new Date(file.lastModified || Date.now()).toISOString(),
              source,
              encrypted: true,
              verified: true,
            };
            await offlineDb.saveFile(item, file);
            return item;
          })
        );
        added.push(...results);
      }
      setLocalFiles(await offlineDb.listFiles());
      void refreshStorageEstimate();
      return added;
    },
    [refreshStorageEstimate]
  );

  const deleteLocalFile = useCallback(
    async (id: string) => {
      await offlineDb.deleteFile(id);
      setLocalFiles((prev) => prev.filter((f) => f.id !== id));
      void refreshStorageEstimate();
    },
    [refreshStorageEstimate]
  );

  const downloadLocalFile = useCallback(async (item: LocalFileItem) => {
    const blob = await offlineDb.getFileBlob(item.id);
    if (!blob) return;

    const win = window as Window & {
      showSaveFilePicker?: (options?: {
        suggestedName?: string;
      }) => Promise<FileSystemFileHandle>;
    };

    if (item.size > 64 * 1024 * 1024 && typeof win.showSaveFilePicker === 'function') {
      try {
        const handle = await win.showSaveFilePicker({ suggestedName: item.name });
        const writable = await handle.createWritable();
        await blob.stream().pipeTo(writable);
        return;
      } catch (err) {
        if ((err as { name?: string })?.name === 'AbortError') return;
        // Fallback to standard anchor download if cross-origin iframe blocks showSaveFilePicker
      }
    }

    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = item.name;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 60_000);
  }, []);

  const startFileTransfer = useCallback(
    async (
      files: Array<{ file: File; relativePath?: string }>,
      targetPeer: PeerDevice,
      duplicatePolicy: DuplicatePolicy = settingsRef.current.duplicatePolicy
    ) => {
      const engine = transferEngineRef.current;
      if (!engine) return;

      const batchId = `batch_${Date.now()}`;
      let sessionKey: CryptoKey | null = null;
      if (identityRef.current && targetPeer.publicKeyJwk) {
        sessionKey = await deriveSharedSessionKey(
          identityRef.current.privateKey,
          targetPeer.publicKeyJwk
        );
      }

      const directReady = (await webRtcRef.current?.ensureConnection(targetPeer.peerId)) ?? false;
      const methodUsed = directReady ? 'webrtc-p2p' : targetPeer.connectionMethod;

      setScreen('transfer-progress');

      for (const entry of files) {
        const { file } = entry;
        const relPath =
          entry.relativePath ||
          (file as File & { webkitRelativePath?: string }).webkitRelativePath ||
          file.name;
        const transferId = `tx_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
        const adaptiveChunkSize =
          file.size >= 8 * 1024 * 1024
            ? 1024 * 1024
            : Math.max(settingsRef.current.chunkSizeKb, 512) * 1024;

        const job = await engine.prepareOutgoingTransfer({
          transferId,
          batchId,
          file,
          relativePath: relPath,
          chunkSizeBytes: adaptiveChunkSize,
          senderPeerId: peerId,
          senderName: settingsRef.current.deviceName,
          senderPlatform: platform,
          receiverPeerId: targetPeer.peerId,
          receiverName: targetPeer.deviceName,
          receiverPlatform: targetPeer.platform,
          connectionMethod: methodUsed,
          duplicatePolicy,
          sessionKey,
        });

        setSelectedTransferId(transferId);

        const waitForAccept = new Promise<boolean>((resolve) => {
          const timer = setTimeout(() => {
            pendingAcceptMapRef.current.delete(transferId);
            resolve(true); // graceful fallback if peer on legacy client didn't emit accept
          }, 45_000);
          pendingAcceptMapRef.current.set(transferId, (accepted) => {
            clearTimeout(timer);
            resolve(accepted);
          });
        });

        sendWsMessage({
          type: 'transfer:init',
          targetPeerId: targetPeer.peerId,
          transfer: {
            transferId,
            batchId,
            senderPeerId: peerId,
            senderName: settingsRef.current.deviceName,
            senderPlatform: platform,
            senderPublicKeyJwk: identityRef.current?.publicKeyJwk ?? null,
            fileName: file.name,
            relativePath: relPath,
            mimeType: file.type || 'application/octet-stream',
            fileSize: file.size,
            totalChunks: job.totalChunks,
            chunkSize: job.chunkSize,
            sha256Expected: job.sha256Expected,
          } satisfies PendingIncomingTransfer,
        });

        const accepted = await waitForAccept;
        if (!accepted) {
          engine.cancel(transferId);
          showToast({
            variant: 'warning',
            title: 'Transfer Declined',
            message: `${targetPeer.deviceName} declined "${file.name}".`,
          });
          continue;
        }
        await engine.runOutgoingTransmission(transferId);
      }
    },
    [peerId, platform, sendWsMessage, showToast]
  );

  const pauseTransfer = useCallback((transferId: string) => {
    transferEngineRef.current?.pause(transferId);
  }, []);

  const resumeTransfer = useCallback(async (transferId: string) => {
    await transferEngineRef.current?.resume(transferId);
  }, []);

  const cancelTransfer = useCallback((transferId: string) => {
    transferEngineRef.current?.cancel(transferId);
  }, []);

  const retryTransfer = useCallback(async (transferId: string) => {
    await transferEngineRef.current?.retry(transferId);
  }, []);

  const pauseAllTransfers = useCallback(() => {
    transferEngineRef.current?.pauseAll();
  }, []);

  const resumeAllTransfers = useCallback(async () => {
    await transferEngineRef.current?.resumeAll();
  }, []);

  const cancelAllTransfers = useCallback(() => {
    transferEngineRef.current?.cancelAll();
  }, []);

  const queuePreselectedSendFiles = useCallback(
    (items: Array<{ file: File; relativePath: string }>) => {
      setPreselectedSendFiles(items);
    },
    []
  );

  const clearPreselectedSendFiles = useCallback(() => {
    setPreselectedSendFiles([]);
  }, []);

  const deleteHistoryRecords = useCallback(async (ids: string[]) => {
    const idSet = new Set(ids);
    setHistory((prev) => {
      const next = prev.filter((item) => !idSet.has(item.id));
      try {
        localStorage.setItem('vega_transfer_history', JSON.stringify(next));
      } catch {
        // ignore
      }
      return next;
    });
    for (const id of ids) {
      await offlineDb.deleteHistoryRecord(id);
    }
    try {
      await apiFetch('/api/history', {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ids }),
      });
    } catch {
      // offline
    }
  }, []);

  const clearAllHistory = useCallback(async () => {
    setHistory([]);
    try {
      localStorage.removeItem('vega_transfer_history');
    } catch {
      // ignore
    }
    await offlineDb.clearHistory();
    try {
      await apiFetch('/api/history', {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
      });
    } catch {
      // offline
    }
  }, []);

  const createSharedFolder = useCallback(
    async (name: string, conflictPolicy: SharedSyncFolder['conflictPolicy']) => {
      const res = await apiFetch('/api/folders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name,
          conflictPolicy,
          actorDevice: settingsRef.current.deviceName,
        }),
      });
      if (res.ok) {
        await refreshFolders();
        await refreshAuditLogs();
      }
    },
    [refreshAuditLogs, refreshFolders]
  );

  const updateFolderPermission = useCallback(
    async (
      folderId: string,
      peer: { peerId: string; deviceName: string; platform: DevicePlatform },
      role: FolderPermissionRole
    ) => {
      const res = await apiFetch(`/api/folders/${encodeURIComponent(folderId)}/permissions`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...peer,
          role,
          actorDevice: settingsRef.current.deviceName,
        }),
      });
      if (res.ok) {
        await refreshFolders();
        await refreshAuditLogs();
      }
    },
    [refreshAuditLogs, refreshFolders]
  );

  const syncFilesToSharedFolder = useCallback(
    async (folderId: string, files: File[]) => {
      let synced = 0;
      let conflicts = 0;
      for (const file of files) {
        const sha256 = await computeBlobSha256Streaming(file);
        const relPath =
          (file as File & { webkitRelativePath?: string }).webkitRelativePath || file.name;
        const res = await apiFetch(`/api/folders/${encodeURIComponent(folderId)}/sync-file`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            relativePath: relPath,
            size: file.size,
            sha256,
            modifiedAt: new Date(file.lastModified || Date.now()).toISOString(),
            modifiedByDevice: settingsRef.current.deviceName,
          }),
        });
        if (res.ok) {
          const data = (await res.json()) as { conflictDetected: boolean };
          if (data.conflictDetected) conflicts += 1;
          else synced += 1;
        }
        await addFilesToVault([file], 'sync-folder');
      }
      await refreshFolders();
      await refreshAuditLogs();
      return { synced, conflicts };
    },
    [addFilesToVault, refreshAuditLogs, refreshFolders]
  );

  const resolveFolderConflict = useCallback(
    async (
      folderId: string,
      fileId: string,
      resolution: 'keep-existing' | 'accept-incoming' | 'keep-both'
    ) => {
      const res = await apiFetch(`/api/folders/${encodeURIComponent(folderId)}/resolve-conflict`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          fileId,
          resolution,
          actorDevice: settingsRef.current.deviceName,
        }),
      });
      if (res.ok) {
        await refreshFolders();
        await refreshAuditLogs();
      }
    },
    [refreshAuditLogs, refreshFolders]
  );

  const deleteSharedFolder = useCallback(
    async (folderId: string) => {
      await apiFetch(`/api/folders/${encodeURIComponent(folderId)}`, { method: 'DELETE' });
      await refreshFolders();
    },
    [refreshFolders]
  );

  const markAllNotificationsRead = useCallback(async () => {
    setNotifications((prev) => {
      const updated = prev.map((n) => ({ ...n, read: true }));
      for (const n of updated) {
        void offlineDb.saveNotification(n);
      }
      return updated;
    });
  }, []);

  const clearNotifications = useCallback(async () => {
    setNotifications([]);
    await offlineDb.clearNotifications();
  }, []);

  const clearChunkCache = useCallback(async () => {
    await offlineDb.clearAllChunks();
    await refreshStorageEstimate();
  }, [refreshStorageEstimate]);

  const value: VegaContextValue = {
    screen,
    setScreen,
    fileManagerCategory,
    setFileManagerCategory,
    selectedTransferId,
    setSelectedTransferId,
    selectedSendPeerId,
    setSelectedSendPeerId,
    preselectedSendFiles,
    queuePreselectedSendFiles,
    clearPreselectedSendFiles,
    peerId,
    platform,
    identity,
    settings,
    updateSettings,
    t,
    wsConnected,
    isOffline,
    discoveryActive,
    setDiscoveryActive,
    refreshDiscovery,
    peers,
    trustedDevices,
    renameTrustedDevice,
    removeTrustedDevice,
    isPeerTrusted,
    activePairingSession,
    generateQrPairing,
    cancelQrPairing,
    requestPairingWithToken,
    requestPairingWithPeer,
    incomingPairingRequest,
    respondToPairingRequest,
    localFiles,
    addFilesToVault,
    deleteLocalFile,
    downloadLocalFile,
    transfers,
    pendingIncomingTransfer,
    respondToIncomingTransfer,
    startFileTransfer,
    pauseTransfer,
    resumeTransfer,
    cancelTransfer,
    retryTransfer,
    pauseAllTransfers,
    resumeAllTransfers,
    cancelAllTransfers,
    history,
    deleteHistoryRecords,
    clearAllHistory,
    sharedFolders,
    refreshFolders,
    createSharedFolder,
    updateFolderPermission,
    syncFilesToSharedFolder,
    resolveFolderConflict,
    deleteSharedFolder,
    auditLogs,
    refreshAuditLogs,
    metrics,
    refreshMetrics,
    notifications,
    markAllNotificationsRead,
    clearNotifications,
    toasts,
    showToast,
    dismissToast,
    storageEstimate,
    refreshStorageEstimate,
    clearChunkCache,
  };

  return <VegaContext.Provider value={value}>{children}</VegaContext.Provider>;
}

export function useVega() {
  const ctx = useContext(VegaContext);
  if (!ctx) throw new Error('useVega must be used inside VegaProvider');
  return ctx;
}
