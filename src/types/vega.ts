export type DevicePlatform = 'android' | 'windows' | 'macos' | 'linux' | 'web';

export type ConnectionMethod = 'webrtc-p2p' | 'local-wifi-ws' | 'hotspot-direct' | 'offline-queue';

export type FileCategory =
  | 'images'
  | 'videos'
  | 'audio'
  | 'documents'
  | 'downloads'
  | 'archives'
  | 'applications'
  | 'other';

export type TransferStatus =
  | 'queued'
  | 'awaiting-approval'
  | 'encrypting'
  | 'transferring'
  | 'paused'
  | 'verifying'
  | 'completed'
  | 'failed'
  | 'cancelled';

export type DuplicatePolicy = 'rename' | 'overwrite' | 'skip';

export type ConflictResolutionPolicy = 'newest-wins' | 'keep-both' | 'source-priority' | 'manual';

export type FolderPermissionRole = 'admin' | 'write' | 'read' | 'revoked';

export type AppLanguage = 'en' | 'hi';

export type AppTheme = 'light' | 'dark';

export type ScreenId =
  | 'splash'
  | 'onboarding'
  | 'dashboard'
  | 'send'
  | 'receive'
  | 'discovery'
  | 'qr-scanner'
  | 'qr-generator'
  | 'pairing'
  | 'trusted-devices'
  | 'file-manager'
  | 'folder-sync'
  | 'transfer-progress'
  | 'transfer-details'
  | 'transfer-history'
  | 'storage'
  | 'notifications'
  | 'settings'
  | 'about'
  | 'help';

export interface PeerDevice {
  peerId: string;
  deviceName: string;
  platform: DevicePlatform;
  userAgentSummary: string;
  publicKeyJwk: JsonWebKey | null;
  fingerprint: string;
  connectionMethod: ConnectionMethod;
  latencyMs: number;
  online: boolean;
  trusted: boolean;
  lastSeenAt: string;
  ipHint?: string;
}

export interface TrustedDevice {
  id: string;
  peerId: string;
  deviceName: string;
  localAlias: string;
  platform: DevicePlatform;
  fingerprint: string;
  publicKeyJwk?: JsonWebKey | null;
  approvedAt: string;
  lastConnectedAt: string;
  transferCount: number;
  totalBytesTransferred: number;
}

export interface PairingSession {
  token: string;
  hostPeerId: string;
  hostDeviceName: string;
  hostPlatform: DevicePlatform;
  hostFingerprint: string;
  hostPublicKeyJwk: JsonWebKey | null;
  qrDataUrl: string;
  createdAt: string;
  expiresAt: string;
  status: 'pending' | 'approved' | 'rejected' | 'expired' | 'cancelled';
}

export interface PairingRequestPayload {
  requestId: string;
  token: string;
  fromPeerId: string;
  fromDeviceName: string;
  fromPlatform: DevicePlatform;
  fromFingerprint: string;
  fromPublicKeyJwk: JsonWebKey | null;
  requestedAt: string;
}

export interface LocalFileItem {
  id: string;
  name: string;
  relativePath: string;
  folderName: string;
  mimeType: string;
  size: number;
  category: FileCategory;
  sha256: string;
  modifiedAt: string;
  source: 'local-vault' | 'received' | 'sync-folder';
  encrypted: boolean;
  verified: boolean;
  downloadUrl?: string;
}

export interface SelectedTransferFile {
  file: File;
  relativePath: string;
}

export interface TransferJob {
  id: string;
  batchId: string;
  direction: 'send' | 'receive';
  fileName: string;
  relativePath: string;
  mimeType: string;
  fileSize: number;
  bytesTransferred: number;
  totalChunks: number;
  completedChunks: number;
  chunkSize: number;
  speedBytesPerSec: number;
  etaSeconds: number;
  status: TransferStatus;
  senderPeerId: string;
  senderName: string;
  senderPlatform: DevicePlatform;
  receiverPeerId: string;
  receiverName: string;
  receiverPlatform: DevicePlatform;
  sha256Expected: string;
  sha256Verified: string | null;
  integrityVerified: boolean;
  encrypted: boolean;
  encryptionAlgorithm: 'AES-256-GCM';
  connectionMethod: ConnectionMethod;
  duplicatePolicy: DuplicatePolicy;
  startedAt: string;
  completedAt: string | null;
  durationMs: number;
  errorCode?: string;
  errorMessage?: string;
}

export interface TransferHistoryRecord {
  id: string;
  fileName: string;
  fileCategory: FileCategory;
  mimeType: string;
  fileSize: number;
  direction: 'send' | 'receive';
  senderName: string;
  receiverName: string;
  senderPlatform: DevicePlatform;
  receiverPlatform: DevicePlatform;
  status: 'completed' | 'failed' | 'cancelled';
  sha256: string;
  integrityVerified: boolean;
  encrypted: boolean;
  connectionMethod: ConnectionMethod;
  startedAt: string;
  completedAt: string;
  durationMs: number;
  averageSpeedBps: number;
}

export interface SharedSyncFolder {
  id: string;
  name: string;
  localPathLabel: string;
  conflictPolicy: ConflictResolutionPolicy;
  autoSync: boolean;
  encryptionRequired: boolean;
  fileCount: number;
  totalSizeBytes: number;
  lastSyncedAt: string;
  syncStatus: 'idle' | 'syncing' | 'conflict' | 'offline-queued';
  permissions: Array<{
    peerId: string;
    deviceName: string;
    platform: DevicePlatform;
    role: FolderPermissionRole;
    updatedAt: string;
  }>;
  files: Array<{
    id: string;
    relativePath: string;
    size: number;
    sha256: string;
    modifiedAt: string;
    modifiedByDevice: string;
    conflictState?: 'none' | 'conflict-detected' | 'resolved';
    conflictingSha256?: string;
    conflictingDevice?: string;
  }>;
}

export interface AuditLogEntry {
  id: string;
  timestamp: string;
  eventType:
    | 'pairing_requested'
    | 'pairing_approved'
    | 'pairing_rejected'
    | 'trust_revoked'
    | 'transfer_started'
    | 'transfer_completed'
    | 'transfer_failed'
    | 'integrity_verified'
    | 'integrity_mismatch'
    | 'folder_sync'
    | 'conflict_resolved'
    | 'permission_updated';
  actorDevice: string;
  targetDevice?: string;
  summary: string;
  severity: 'info' | 'success' | 'warning' | 'error';
  metadata?: Record<string, string | number | boolean>;
}

export interface AppNotification {
  id: string;
  title: string;
  message: string;
  type: 'info' | 'success' | 'warning' | 'error';
  createdAt: string;
  read: boolean;
  actionScreen?: ScreenId;
  relatedId?: string;
}

export interface AppSettings {
  deviceName: string;
  language: AppLanguage;
  theme: AppTheme;
  downloadLocation: string;
  chunkSizeKb: 64 | 256 | 512 | 1024;
  requireApprovalForKnown: boolean;
  verifySha256: boolean;
  enableNotifications: boolean;
  enableAnimations: boolean;
  reducedMotion: boolean;
  hapticFeedback: boolean;
  duplicatePolicy: DuplicatePolicy;
  conflictPolicy: ConflictResolutionPolicy;
}

export interface SystemMetricsSnapshot {
  timestamp: string;
  activePeersCount: number;
  activeTransfersCount: number;
  totalBytesTransferred: number;
  currentThroughputBps: number;
  averageLatencyMs: number;
  uptimeSeconds: number;
  memoryRssMb: number;
  heapUsedMb: number;
  totalVerifiedTransfers: number;
  totalFailedTransfers: number;
  protocolVersion: string;
}
