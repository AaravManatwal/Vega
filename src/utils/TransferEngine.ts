import {
  base64ToBytes,
  computeBlobSha256Streaming,
  computeSha256Hex,
  decryptChunk,
  decryptChunkBinary,
  encryptChunkBinary,
  StreamingSha256,
} from '../lib/crypto.ts';
import { offlineDb } from '../lib/offlineDb.ts';
import type {
  ConnectionMethod,
  DevicePlatform,
  DuplicatePolicy,
  TransferJob,
  TransferStatus,
} from '../types/vega.ts';

export interface ChunkPlan {
  totalChunks: number;
  chunkSizeBytes: number;
}

export interface Sha256VerificationResult {
  valid: boolean;
  actualSha256: string;
}

const DIRECT_DISK_STREAM_THRESHOLD_BYTES = 64 * 1024 * 1024; // 64 MB

interface OpfsDirectStreamHandle {
  fileHandle: FileSystemFileHandle;
  writable: FileSystemWritableFileStream;
  fileName: string;
}

async function openOpfsStream(transferId: string): Promise<OpfsDirectStreamHandle | null> {
  try {
    if (
      typeof navigator === 'undefined' ||
      !navigator.storage ||
      typeof navigator.storage.getDirectory !== 'function'
    ) {
      return null;
    }
    const root = await navigator.storage.getDirectory();
    const safeName = `vega_rx_${transferId.replace(/[^a-zA-Z0-9_-]/g, '_')}.bin`;
    const fileHandle = await root.getFileHandle(safeName, { create: true });
    if (typeof fileHandle.createWritable !== 'function') {
      return null;
    }
    const writable = await fileHandle.createWritable({ keepExistingData: true });
    return { fileHandle, writable, fileName: safeName };
  } catch {
    return null;
  }
}

async function removeOpfsTempFile(fileName: string): Promise<void> {
  try {
    if (
      typeof navigator === 'undefined' ||
      !navigator.storage ||
      typeof navigator.storage.getDirectory !== 'function'
    ) {
      return;
    }
    const root = await navigator.storage.getDirectory();
    await root.removeEntry(fileName);
  } catch {
    // ignore cleanup error
  }
}

/**
 * Computes how many fixed-size chunks a file requires for transmission.
 */
export function computeFileChunkPlan(fileSize: number, chunkSizeBytes: number): ChunkPlan {
  const safeChunkSize = Math.max(1024, chunkSizeBytes);
  const totalChunks = Math.max(1, Math.ceil(fileSize / safeChunkSize));
  return { totalChunks, chunkSizeBytes: safeChunkSize };
}

/**
 * Slices a deterministic byte range from a File object for chunked processing.
 */
export async function sliceFileChunk(
  file: File,
  chunkIndex: number,
  chunkSizeBytes: number
): Promise<Uint8Array> {
  const start = chunkIndex * chunkSizeBytes;
  const end = Math.min(start + chunkSizeBytes, file.size);
  const sliceBuffer = await file.slice(start, end).arrayBuffer();
  return new Uint8Array(sliceBuffer);
}

/**
 * Computes a SHA-256 hex digest for an entire File or Blob using constant-memory streaming
 * on large files (multi-GB+) and native WebCrypto on smaller files.
 */
export async function computeFileSha256(file: Blob): Promise<string> {
  return computeBlobSha256Streaming(file);
}

/**
 * Computes SHA-256 digest and verifies it matches the expected hex checksum.
 */
export async function verifySha256Integrity(
  data: ArrayBuffer | Uint8Array,
  expectedSha256Hex: string
): Promise<Sha256VerificationResult> {
  const buffer =
    data instanceof Uint8Array
      ? (data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength) as ArrayBuffer)
      : data;
  const actualSha256 = await computeSha256Hex(buffer);
  return {
    valid: actualSha256.toLowerCase() === expectedSha256Hex.toLowerCase(),
    actualSha256,
  };
}

export interface OutgoingChunkPacket {
  transferId: string;
  chunkIndex: number;
  ivBytes: Uint8Array;
  cipherBytes: Uint8Array;
  encrypted: boolean;
  plainByteLength: number;
}

export interface IncomingCompletionResult {
  complete: boolean;
  verified: boolean;
  sha256?: string;
  assembledBlob?: Blob;
  assembledBytes?: Uint8Array;
}

export interface TransferEngineHooks {
  onJobUpdate: (job: TransferJob) => void;
  onSendChunk: (targetPeerId: string, packet: OutgoingChunkPacket) => Promise<boolean> | boolean;
  isDirectP2pReady?: (targetPeerId: string) => boolean;
  onControlSignal: (targetPeerId: string, transferId: string, action: 'pause' | 'resume' | 'cancel') => void;
  onCompleted?: (job: TransferJob) => Promise<void> | void;
  onFailed?: (job: TransferJob, reason: string) => Promise<void> | void;
}

interface OutgoingSession {
  job: TransferJob;
  file: File;
  targetPeerId: string;
  sessionKey: CryptoKey | null;
  currentChunkIndex: number;
  paused: boolean;
  cancelled: boolean;
  startedAtMs: number;
}

interface IncomingSession {
  job: TransferJob;
  sessionKey: CryptoKey | null;
  chunks: Map<number, Uint8Array>;
  receivedChunkSizes: Map<number, number>;
  bytesReceived: number;
  opfsStream: OpfsDirectStreamHandle | null;
  streamHasher: StreamingSha256 | null;
  nextSequentialHashChunk: number;
  pendingWrites: Array<Promise<void>>;
  startedAtMs: number;
  lastSampleAtMs: number;
  lastSampleBytes: number;
  lastUiEmitAtMs: number;
  paused: boolean;
  cancelled: boolean;
}

type EarlyBufferedChunk =
  | {
      kind: 'raw';
      chunkIndex: number;
      encrypted: boolean;
      iv: Uint8Array;
      payload: Uint8Array;
      isDirectP2p: boolean;
    }
  | {
      kind: 'base64';
      chunkIndex: number;
      ivBase64: string;
      cipherBase64: string;
    };

const PIPELINE_READ_AHEAD = 3;

export class TransferEngine {
  private outgoing = new Map<string, OutgoingSession>();
  private incoming = new Map<string, IncomingSession>();
  private earlyChunks = new Map<string, EarlyBufferedChunk[]>();
  private hooks: TransferEngineHooks;

  constructor(hooks: TransferEngineHooks) {
    this.hooks = hooks;
  }

  public async prepareOutgoingTransfer(params: {
    transferId: string;
    batchId: string;
    file: File;
    relativePath: string;
    chunkSizeBytes: number;
    senderPeerId: string;
    senderName: string;
    senderPlatform: DevicePlatform;
    receiverPeerId: string;
    receiverName: string;
    receiverPlatform: DevicePlatform;
    connectionMethod: ConnectionMethod;
    duplicatePolicy: DuplicatePolicy;
    sessionKey: CryptoKey | null;
  }): Promise<TransferJob> {
    const sha256Expected = await computeFileSha256(params.file);
    const { totalChunks, chunkSizeBytes } = computeFileChunkPlan(
      params.file.size,
      params.chunkSizeBytes
    );

    const job: TransferJob = {
      id: params.transferId,
      batchId: params.batchId,
      direction: 'send',
      fileName: params.file.name,
      relativePath: params.relativePath,
      mimeType: params.file.type || 'application/octet-stream',
      fileSize: params.file.size,
      bytesTransferred: 0,
      totalChunks,
      completedChunks: 0,
      chunkSize: chunkSizeBytes,
      speedBytesPerSec: 0,
      etaSeconds: 0,
      status: 'awaiting-approval',
      senderPeerId: params.senderPeerId,
      senderName: params.senderName,
      senderPlatform: params.senderPlatform,
      receiverPeerId: params.receiverPeerId,
      receiverName: params.receiverName,
      receiverPlatform: params.receiverPlatform,
      sha256Expected,
      sha256Verified: null,
      integrityVerified: false,
      encrypted: Boolean(params.sessionKey),
      encryptionAlgorithm: 'AES-256-GCM',
      connectionMethod: params.connectionMethod,
      duplicatePolicy: params.duplicatePolicy,
      startedAt: new Date().toISOString(),
      completedAt: null,
      durationMs: 0,
    };

    this.outgoing.set(params.transferId, {
      job,
      file: params.file,
      targetPeerId: params.receiverPeerId,
      sessionKey: params.sessionKey,
      currentChunkIndex: 0,
      paused: false,
      cancelled: false,
      startedAtMs: Date.now(),
    });

    this.hooks.onJobUpdate(job);
    return job;
  }

  private async prepareOutgoingPacket(
    transferId: string,
    file: File,
    chunkIndex: number,
    chunkSize: number,
    sessionKey: CryptoKey | null
  ): Promise<OutgoingChunkPacket> {
    const plainBytes = await sliceFileChunk(file, chunkIndex, chunkSize);
    if (sessionKey) {
      const enc = await encryptChunkBinary(sessionKey, plainBytes);
      return {
        transferId,
        chunkIndex,
        ivBytes: enc.iv,
        cipherBytes: enc.cipherBytes,
        encrypted: true,
        plainByteLength: plainBytes.byteLength,
      };
    }
    return {
      transferId,
      chunkIndex,
      ivBytes: new Uint8Array(0),
      cipherBytes: plainBytes,
      encrypted: false,
      plainByteLength: plainBytes.byteLength,
    };
  }

  public async runOutgoingTransmission(transferId: string): Promise<void> {
    const session = this.outgoing.get(transferId);
    if (!session) return;

    if (session.currentChunkIndex === 0) {
      session.startedAtMs = Date.now();
      session.job = { ...session.job, status: 'transferring', startedAt: new Date().toISOString() };
      this.hooks.onJobUpdate(session.job);
    }

    const { file, targetPeerId, sessionKey } = session;
    const chunkSize = session.job.chunkSize;
    const totalChunks = session.job.totalChunks;

    let bytesSentWindow = 0;
    let windowStartMs = Date.now();
    let lastUiEmitMs = 0;
    let lastYieldMs = performance.now();

    // Pre-slice and encrypt up to PIPELINE_READ_AHEAD chunks in parallel with network I/O
    const preparedQueue = new Map<number, Promise<OutgoingChunkPacket>>();
    const scheduleAhead = (fromIndex: number) => {
      for (let k = fromIndex; k < Math.min(totalChunks, fromIndex + PIPELINE_READ_AHEAD); k++) {
        if (!preparedQueue.has(k)) {
          preparedQueue.set(k, this.prepareOutgoingPacket(transferId, file, k, chunkSize, sessionKey));
        }
      }
    };

    scheduleAhead(session.currentChunkIndex);

    for (let i = session.currentChunkIndex; i < totalChunks; i++) {
      if (session.cancelled) {
        preparedQueue.clear();
        session.job = {
          ...session.job,
          status: 'cancelled',
          speedBytesPerSec: 0,
          completedAt: new Date().toISOString(),
        };
        this.hooks.onJobUpdate(session.job);
        this.outgoing.delete(transferId);
        return;
      }

      if (session.paused) {
        preparedQueue.clear();
        session.currentChunkIndex = i;
        session.job = {
          ...session.job,
          status: 'paused',
          speedBytesPerSec: 0,
        };
        this.hooks.onJobUpdate(session.job);
        return;
      }

      scheduleAhead(i + 1);
      const packetPromise = preparedQueue.get(i)!;
      preparedQueue.delete(i);
      const packet = await packetPromise;

      const directBinary = Boolean(this.hooks.isDirectP2pReady?.(targetPeerId));
      const sent = await this.hooks.onSendChunk(targetPeerId, packet);

      if (!sent) {
        preparedQueue.clear();
        session.paused = true;
        session.currentChunkIndex = i;
        session.job = {
          ...session.job,
          status: 'paused',
          speedBytesPerSec: 0,
          errorCode: 'NETWORK_DISCONNECTED',
          errorMessage: 'Connection interrupted mid-transfer. Resume from verified chunk offset when peer reconnects.',
        };
        this.hooks.onJobUpdate(session.job);
        return;
      }

      const end = Math.min((i + 1) * chunkSize, file.size);
      session.currentChunkIndex = i + 1;
      bytesSentWindow += packet.plainByteLength;
      const now = Date.now();
      const windowSec = Math.max((now - windowStartMs) / 1000, 0.1);
      const speed = Math.round(bytesSentWindow / windowSec);
      const remaining = Math.max(file.size - end, 0);
      const eta = speed > 0 ? remaining / speed : 0;

      if (now - windowStartMs >= 800) {
        bytesSentWindow = 0;
        windowStartMs = now;
      }

      session.job = {
        ...session.job,
        connectionMethod: directBinary ? 'webrtc-p2p' : session.job.connectionMethod,
        bytesTransferred: end,
        completedChunks: i + 1,
        speedBytesPerSec: speed,
        etaSeconds: eta,
        status: end >= file.size ? 'verifying' : 'transferring',
        durationMs: now - session.startedAtMs,
        errorCode: undefined,
        errorMessage: undefined,
      };

      if (i === 0 || end >= file.size || now - lastUiEmitMs >= 100) {
        lastUiEmitMs = now;
        this.hooks.onJobUpdate(session.job);
      }

      const perfNow = performance.now();
      if (perfNow - lastYieldMs >= 25) {
        lastYieldMs = perfNow;
        await new Promise((r) => setTimeout(r, 0));
      }
    }

    const durationMs = Math.max(Date.now() - session.startedAtMs, 1);
    const avgSpeed = Math.round((file.size / durationMs) * 1000);
    session.job = {
      ...session.job,
      bytesTransferred: file.size,
      completedChunks: totalChunks,
      speedBytesPerSec: avgSpeed,
      etaSeconds: 0,
      status: 'completed',
      sha256Verified: session.job.sha256Expected,
      integrityVerified: true,
      completedAt: new Date().toISOString(),
      durationMs,
    };
    this.hooks.onJobUpdate(session.job);
    await this.hooks.onCompleted?.(session.job);
    this.outgoing.delete(transferId);
  }

  public pause(transferId: string): void {
    const outSession = this.outgoing.get(transferId);
    if (outSession) {
      outSession.paused = true;
      outSession.job = {
        ...outSession.job,
        status: 'paused',
        speedBytesPerSec: 0,
      };
      this.hooks.onJobUpdate(outSession.job);
      this.hooks.onControlSignal(outSession.targetPeerId, transferId, 'pause');
      return;
    }

    const inSession = this.incoming.get(transferId);
    if (inSession) {
      inSession.paused = true;
      inSession.job = {
        ...inSession.job,
        status: 'paused',
        speedBytesPerSec: 0,
      };
      this.hooks.onJobUpdate(inSession.job);
      if (!inSession.opfsStream && inSession.chunks.size > 0) {
        const snapshot = Array.from(inSession.chunks.entries()).map(([chunkIndex, bytes]) => ({
          chunkIndex,
          bytes,
        }));
        void offlineDb.saveChunksBatch(transferId, snapshot).catch(() => {});
      }
    }
  }

  public async resume(transferId: string): Promise<void> {
    const outSession = this.outgoing.get(transferId);
    if (outSession) {
      outSession.paused = false;
      outSession.job = {
        ...outSession.job,
        status: 'transferring',
        errorCode: undefined,
        errorMessage: undefined,
      };
      this.hooks.onJobUpdate(outSession.job);
      this.hooks.onControlSignal(outSession.targetPeerId, transferId, 'resume');
      await this.runOutgoingTransmission(transferId);
      return;
    }

    const inSession = this.incoming.get(transferId);
    if (inSession) {
      inSession.paused = false;
      inSession.job = {
        ...inSession.job,
        status: 'transferring',
      };
      this.hooks.onJobUpdate(inSession.job);
    }
  }

  public cancel(transferId: string): void {
    this.earlyChunks.delete(transferId);
    const outSession = this.outgoing.get(transferId);
    if (outSession) {
      outSession.cancelled = true;
      outSession.job = {
        ...outSession.job,
        status: 'cancelled',
        speedBytesPerSec: 0,
        completedAt: new Date().toISOString(),
      };
      this.hooks.onJobUpdate(outSession.job);
      this.hooks.onControlSignal(outSession.targetPeerId, transferId, 'cancel');
      this.outgoing.delete(transferId);
      return;
    }

    const inSession = this.incoming.get(transferId);
    if (inSession) {
      inSession.cancelled = true;
      inSession.job = {
        ...inSession.job,
        status: 'cancelled',
        speedBytesPerSec: 0,
        completedAt: new Date().toISOString(),
      };
      this.hooks.onJobUpdate(inSession.job);
      if (inSession.opfsStream) {
        void inSession.opfsStream.writable.abort().catch(() => {});
        void removeOpfsTempFile(inSession.opfsStream.fileName);
      }
      void offlineDb.clearChunksForTransfer(transferId);
      this.incoming.delete(transferId);
    }
  }

  public async retry(transferId: string): Promise<void> {
    const session = this.outgoing.get(transferId);
    if (!session) return;
    session.paused = false;
    session.cancelled = false;
    session.currentChunkIndex = 0;
    session.startedAtMs = Date.now();
    await this.runOutgoingTransmission(transferId);
  }

  public async registerIncomingTransfer(
    job: TransferJob,
    sessionKey: CryptoKey | null
  ): Promise<IncomingCompletionResult> {
    const restoredChunks = await offlineDb.getChunksForTransfer(job.id);
    const chunkMap = new Map<number, Uint8Array>();
    const receivedChunkSizes = new Map<number, number>();
    let restoredBytes = 0;

    // For large files (>64 MB), open an Origin Private File System (OPFS) direct-to-disk writable stream
    // so chunks are flushed straight to storage instead of accumulating in JS RAM.
    const opfsStream =
      job.fileSize > DIRECT_DISK_STREAM_THRESHOLD_BYTES ? await openOpfsStream(job.id) : null;
    const streamHasher = opfsStream ? new StreamingSha256() : null;

    const sortedRestored = [...restoredChunks].sort((a, b) => a.chunkIndex - b.chunkIndex);
    let nextSequentialHashChunk = 0;

    for (const c of sortedRestored) {
      receivedChunkSizes.set(c.chunkIndex, c.bytes.byteLength);
      restoredBytes += c.bytes.byteLength;
      if (streamHasher && c.chunkIndex === nextSequentialHashChunk) {
        streamHasher.update(c.bytes);
        nextSequentialHashChunk += 1;
      }
      if (opfsStream) {
        const position = c.chunkIndex * job.chunkSize;
        await opfsStream.writable.write({
          type: 'write',
          position,
          data: c.bytes.buffer.slice(
            c.bytes.byteOffset,
            c.bytes.byteOffset + c.bytes.byteLength
          ) as ArrayBuffer,
        });
      } else {
        chunkMap.set(c.chunkIndex, c.bytes);
      }
    }

    const initializedJob: TransferJob = {
      ...job,
      bytesTransferred: restoredBytes,
      completedChunks: receivedChunkSizes.size,
      status: 'transferring',
    };

    const session: IncomingSession = {
      job: initializedJob,
      sessionKey,
      chunks: chunkMap,
      receivedChunkSizes,
      bytesReceived: restoredBytes,
      opfsStream,
      streamHasher,
      nextSequentialHashChunk,
      pendingWrites: [],
      startedAtMs: Date.now(),
      lastSampleAtMs: Date.now(),
      lastSampleBytes: restoredBytes,
      lastUiEmitAtMs: 0,
      paused: false,
      cancelled: false,
    };

    this.incoming.set(job.id, session);
    this.hooks.onJobUpdate(initializedJob);

    // Replay any early chunks that arrived before async key derivation finished
    const queued = this.earlyChunks.get(job.id);
    if (queued && queued.length > 0) {
      this.earlyChunks.delete(job.id);
      for (const item of queued) {
        if (session.cancelled) break;
        const res =
          item.kind === 'raw'
            ? await this.receiveRawChunk({
                transferId: job.id,
                chunkIndex: item.chunkIndex,
                encrypted: item.encrypted,
                iv: item.iv,
                payload: item.payload,
                isDirectP2p: item.isDirectP2p,
              })
            : await this.receiveChunk({
                transferId: job.id,
                chunkIndex: item.chunkIndex,
                ivBase64: item.ivBase64,
                cipherBase64: item.cipherBase64,
              });
        if (res.complete) {
          return res;
        }
      }
    }

    return { complete: false, verified: false };
  }

  public async receiveChunk(params: {
    transferId: string;
    chunkIndex: number;
    ivBase64: string;
    cipherBase64: string;
  }): Promise<IncomingCompletionResult> {
    const session = this.incoming.get(params.transferId);
    if (!session) {
      const list = this.earlyChunks.get(params.transferId) || [];
      list.push({
        kind: 'base64',
        chunkIndex: params.chunkIndex,
        ivBase64: params.ivBase64,
        cipherBase64: params.cipherBase64,
      });
      this.earlyChunks.set(params.transferId, list);
      return { complete: false, verified: false };
    }
    if (session.cancelled) return { complete: false, verified: false };

    const plainBytes = session.sessionKey
      ? await decryptChunk(session.sessionKey, params.ivBase64, params.cipherBase64)
      : base64ToBytes(params.cipherBase64);

    return this.ingestDecryptedIncomingChunk(session, params.transferId, params.chunkIndex, plainBytes);
  }

  public async receiveRawChunk(params: {
    transferId: string;
    chunkIndex: number;
    encrypted: boolean;
    iv: Uint8Array;
    payload: Uint8Array;
    isDirectP2p?: boolean;
  }): Promise<IncomingCompletionResult> {
    const session = this.incoming.get(params.transferId);
    if (!session) {
      const list = this.earlyChunks.get(params.transferId) || [];
      list.push({
        kind: 'raw',
        chunkIndex: params.chunkIndex,
        encrypted: params.encrypted,
        iv: new Uint8Array(params.iv),
        payload: new Uint8Array(params.payload),
        isDirectP2p: params.isDirectP2p ?? true,
      });
      this.earlyChunks.set(params.transferId, list);
      return { complete: false, verified: false };
    }
    if (session.cancelled) return { complete: false, verified: false };

    const plainBytes =
      session.sessionKey && params.encrypted
        ? await decryptChunkBinary(session.sessionKey, params.iv, params.payload)
        : params.payload.slice();

    if (params.isDirectP2p !== false && session.job.connectionMethod !== 'webrtc-p2p') {
      session.job = { ...session.job, connectionMethod: 'webrtc-p2p' };
    }
    return this.ingestDecryptedIncomingChunk(session, params.transferId, params.chunkIndex, plainBytes);
  }

  private async ingestDecryptedIncomingChunk(
    session: IncomingSession,
    transferId: string,
    chunkIndex: number,
    plainBytes: Uint8Array
  ): Promise<IncomingCompletionResult> {
    const prevSize = session.receivedChunkSizes.get(chunkIndex) ?? 0;
    session.receivedChunkSizes.set(chunkIndex, plainBytes.byteLength);
    session.bytesReceived += plainBytes.byteLength - prevSize;

    if (session.streamHasher) {
      if (chunkIndex === session.nextSequentialHashChunk) {
        session.streamHasher.update(plainBytes);
        session.nextSequentialHashChunk += 1;
        while (session.chunks.has(session.nextSequentialHashChunk)) {
          const buffered = session.chunks.get(session.nextSequentialHashChunk)!;
          session.streamHasher.update(buffered);
          session.chunks.delete(session.nextSequentialHashChunk);
          session.nextSequentialHashChunk += 1;
        }
      } else if (chunkIndex > session.nextSequentialHashChunk) {
        session.chunks.set(chunkIndex, plainBytes);
      }
    }

    if (session.opfsStream) {
      // Stream directly to disk via FileSystemWritableFileStream at deterministic byte offset
      const position = chunkIndex * session.job.chunkSize;
      const diskWrite = session.opfsStream.writable
        .write({
          type: 'write',
          position,
          data: plainBytes.buffer.slice(
            plainBytes.byteOffset,
            plainBytes.byteOffset + plainBytes.byteLength
          ) as ArrayBuffer,
        })
        .catch(() => {});
      session.pendingWrites.push(diskWrite);
      if (session.pendingWrites.length >= 12) {
        await Promise.all(session.pendingWrites.splice(0));
      }
    } else {
      // Store directly in RAM during active transfer (avoid per-chunk IndexedDB disk write amplification)
      session.chunks.set(chunkIndex, plainBytes);
    }

    const now = Date.now();
    const bytesReceived = session.bytesReceived;
    const completedChunksCount = session.receivedChunkSizes.size;
    const elapsedSec = Math.max((now - session.lastSampleAtMs) / 1000, 0.25);
    let speed = session.job.speedBytesPerSec;

    if (now - session.lastSampleAtMs >= 300 || completedChunksCount >= session.job.totalChunks) {
      speed = Math.max(
        Math.round((bytesReceived - session.lastSampleBytes) / elapsedSec),
        Math.round((bytesReceived / Math.max(now - session.startedAtMs, 1)) * 1000)
      );
      session.lastSampleAtMs = now;
      session.lastSampleBytes = bytesReceived;
    }

    const remaining = Math.max(session.job.fileSize - bytesReceived, 0);
    const eta = speed > 0 ? remaining / speed : 0;

    session.job = {
      ...session.job,
      bytesTransferred: bytesReceived,
      completedChunks: completedChunksCount,
      speedBytesPerSec: speed,
      etaSeconds: eta,
      status: completedChunksCount >= session.job.totalChunks ? 'verifying' : session.paused ? 'paused' : 'transferring',
    };

    if (
      completedChunksCount === 1 ||
      completedChunksCount >= session.job.totalChunks ||
      now - session.lastUiEmitAtMs >= 100
    ) {
      session.lastUiEmitAtMs = now;
      this.hooks.onJobUpdate(session.job);
    }

    if (completedChunksCount < session.job.totalChunks) {
      return { complete: false, verified: false };
    }

    if (session.pendingWrites.length > 0) {
      await Promise.all(session.pendingWrites.splice(0));
    }

    return this.verifyAndAssembleIncoming(transferId);
  }

  public async verifyAndAssembleIncoming(
    transferId: string
  ): Promise<IncomingCompletionResult> {
    const session = this.incoming.get(transferId);
    if (!session) return { complete: false, verified: false };

    try {
      let assembledBlob: Blob;
      let assembledBytes: Uint8Array | undefined;
      let actualSha256: string;

      if (session.opfsStream) {
        await session.opfsStream.writable.close();
        const diskFile = await session.opfsStream.fileHandle.getFile();
        assembledBlob = new Blob([diskFile], {
          type: session.job.mimeType || 'application/octet-stream',
        });
        if (session.streamHasher && session.nextSequentialHashChunk >= session.job.totalChunks) {
          actualSha256 = session.streamHasher.digestHex();
        } else {
          actualSha256 = await computeBlobSha256Streaming(assembledBlob);
        }
      } else {
        // Single contiguous buffer assembly -> zero double-copy + hardware WebCrypto SHA-256
        const contiguous = new Uint8Array(session.job.fileSize);
        let offset = 0;
        for (let i = 0; i < session.job.totalChunks; i++) {
          const part = session.chunks.get(i);
          if (!part) {
            throw new Error(`Missing chunk ${i} during SHA-256 verification.`);
          }
          contiguous.set(part, offset);
          offset += part.byteLength;
        }
        session.chunks.clear();
        assembledBytes = contiguous;
        assembledBlob = new Blob([contiguous.buffer], {
          type: session.job.mimeType || 'application/octet-stream',
        });
        const verification = await verifySha256Integrity(
          contiguous.buffer,
          session.job.sha256Expected
        );
        actualSha256 = verification.actualSha256;
      }

      if (actualSha256.toLowerCase() !== session.job.sha256Expected.toLowerCase()) {
        throw new Error(
          `SHA-256 mismatch: expected ${session.job.sha256Expected.slice(0, 12)}, got ${actualSha256.slice(0, 12)}`
        );
      }

      const durationMs = Math.max(Date.now() - session.startedAtMs, 1);
      const avgSpeed = Math.round((session.job.fileSize / durationMs) * 1000);

      session.job = {
        ...session.job,
        bytesTransferred: session.job.fileSize,
        completedChunks: session.job.totalChunks,
        speedBytesPerSec: avgSpeed,
        etaSeconds: 0,
        status: 'completed',
        sha256Verified: actualSha256,
        integrityVerified: true,
        completedAt: new Date().toISOString(),
        durationMs,
      };
      this.hooks.onJobUpdate(session.job);
      void offlineDb.clearChunksForTransfer(transferId).catch(() => {});
      await this.hooks.onCompleted?.(session.job);
      this.incoming.delete(transferId);
      this.earlyChunks.delete(transferId);

      return {
        complete: true,
        verified: true,
        sha256: actualSha256,
        assembledBlob,
        assembledBytes,
      };
    } catch (err) {
      const message = err instanceof Error ? err.message : 'SHA-256 verification error';
      if (session.opfsStream) {
        void session.opfsStream.writable.abort().catch(() => {});
        void removeOpfsTempFile(session.opfsStream.fileName);
      }
      session.job = {
        ...session.job,
        status: 'failed',
        integrityVerified: false,
        completedAt: new Date().toISOString(),
        durationMs: Math.max(Date.now() - session.startedAtMs, 1),
        errorCode: 'INTEGRITY_ERROR',
        errorMessage: message,
      };
      this.hooks.onJobUpdate(session.job);
      await this.hooks.onFailed?.(session.job, message);
      this.incoming.delete(transferId);
      this.earlyChunks.delete(transferId);
      return { complete: true, verified: false };
    }
  }

  public applyIncomingControl(transferId: string, action: 'pause' | 'resume' | 'cancel'): void {
    const session = this.incoming.get(transferId);
    if (!session) return;
    let nextStatus: TransferStatus = session.job.status;
    if (action === 'pause') {
      session.paused = true;
      nextStatus = 'paused';
    } else if (action === 'resume') {
      session.paused = false;
      nextStatus = 'transferring';
    } else if (action === 'cancel') {
      session.cancelled = true;
      nextStatus = 'cancelled';
    }

    session.job = {
      ...session.job,
      status: nextStatus,
      speedBytesPerSec: nextStatus === 'transferring' ? session.job.speedBytesPerSec : 0,
    };
    this.hooks.onJobUpdate(session.job);
    if (action === 'cancel') {
      if (session.opfsStream) {
        void session.opfsStream.writable.abort().catch(() => {});
        void removeOpfsTempFile(session.opfsStream.fileName);
      }
      void offlineDb.clearChunksForTransfer(transferId);
      this.incoming.delete(transferId);
    }
  }

  public getOutgoingJob(transferId: string): TransferJob | undefined {
    return this.outgoing.get(transferId)?.job;
  }

  public getIncomingJob(transferId: string): TransferJob | undefined {
    return this.incoming.get(transferId)?.job;
  }

  public getTransferState(transferId: string): TransferJob | undefined {
    return this.outgoing.get(transferId)?.job ?? this.incoming.get(transferId)?.job;
  }

  public pauseAll(): void {
    for (const transferId of this.outgoing.keys()) {
      this.pause(transferId);
    }
    for (const transferId of this.incoming.keys()) {
      this.pause(transferId);
    }
  }

  public async resumeAll(): Promise<void> {
    const pausedOutIds = Array.from(this.outgoing.entries())
      .filter(([, s]) => s.paused && !s.cancelled)
      .map(([id]) => id);
    const pausedInIds = Array.from(this.incoming.entries())
      .filter(([, s]) => s.paused && !s.cancelled)
      .map(([id]) => id);
    await Promise.all([
      ...pausedOutIds.map((id) => this.resume(id)),
      ...pausedInIds.map((id) => this.resume(id)),
    ]);
  }

  public cancelAll(): void {
    for (const transferId of Array.from(this.outgoing.keys())) {
      this.cancel(transferId);
    }
    for (const transferId of Array.from(this.incoming.keys())) {
      this.cancel(transferId);
    }
  }
}
