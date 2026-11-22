export interface BinaryChunkFrame {
  transferId: string;
  chunkIndex: number;
  encrypted: boolean;
  iv: Uint8Array;
  payload: Uint8Array;
}

interface PeerConnectionEntry {
  pc: RTCPeerConnection;
  dc: RTCDataChannel | null;
  makingOffer: boolean;
  pendingCandidates: RTCIceCandidateInit[];
}

interface IncomingAssemblyBuffer {
  peerId: string;
  createdAt: number;
  totalParts: number;
  receivedParts: number;
  parts: Array<Uint8Array | null>;
}

const DEFAULT_DC_SEGMENT_BYTES = 60 * 1024;
const MAX_DC_SEGMENT_BYTES = 224 * 1024;
const HIGH_WATER_MARK_BYTES = 12 * 1024 * 1024;
const LOW_WATER_THRESHOLD_BYTES = 3 * 1024 * 1024;

const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder();

function computeFrameId(transferIdBytes: Uint8Array, chunkIndex: number): number {
  let hash = 0x811c9dc5;
  for (let i = 0; i < transferIdBytes.byteLength; i++) {
    hash ^= transferIdBytes[i];
    hash = Math.imul(hash, 0x01000193);
  }
  hash ^= chunkIndex & 0xff;
  hash = Math.imul(hash, 0x01000193);
  hash ^= (chunkIndex >>> 8) & 0xff;
  hash = Math.imul(hash, 0x01000193);
  hash ^= (chunkIndex >>> 16) & 0xff;
  hash = Math.imul(hash, 0x01000193);
  hash ^= (chunkIndex >>> 24) & 0xff;
  hash = Math.imul(hash, 0x01000193);
  return hash >>> 0;
}

/**
 * Manages direct browser-to-browser WebRTC DataChannels for zero-Base64 binary chunk streaming
 * over local Wi-Fi / LAN, using existing WebSocket signaling for SDP & ICE exchange.
 */
export class WebRtcPeerManager {
  private peers = new Map<string, PeerConnectionEntry>();
  private assemblies = new Map<string, IncomingAssemblyBuffer>();
  private sendSignal: (targetPeerId: string, type: string, payload: Record<string, unknown>) => boolean;
  private onBinaryChunk: (fromPeerId: string, frame: BinaryChunkFrame) => void;
  private onChannelStateChange?: (peerId: string, open: boolean) => void;
  private localPeerId: string;

  constructor(options: {
    localPeerId: string;
    sendSignal: (targetPeerId: string, type: string, payload: Record<string, unknown>) => boolean;
    onBinaryChunk: (fromPeerId: string, frame: BinaryChunkFrame) => void;
    onChannelStateChange?: (peerId: string, open: boolean) => void;
  }) {
    this.localPeerId = options.localPeerId;
    this.sendSignal = options.sendSignal;
    this.onBinaryChunk = options.onBinaryChunk;
    this.onChannelStateChange = options.onChannelStateChange;
  }

  public isChannelOpen(targetPeerId: string): boolean {
    const entry = this.peers.get(targetPeerId);
    return Boolean(entry?.dc && entry.dc.readyState === 'open');
  }

  public async ensureConnection(targetPeerId: string): Promise<boolean> {
    if (typeof RTCPeerConnection === 'undefined') return false;
    const existing = this.peers.get(targetPeerId);
    if (existing?.dc?.readyState === 'open') return true;

    const entry = existing || this.createPeerEntry(targetPeerId, true);
    if (entry.pc.signalingState === 'stable' && !entry.makingOffer && entry.dc?.readyState !== 'open') {
      try {
        entry.makingOffer = true;
        const offer = await entry.pc.createOffer();
        await entry.pc.setLocalDescription(offer);
        this.sendSignal(targetPeerId, 'webrtc:offer', { sdp: entry.pc.localDescription });
      } catch {
        // fallback cleanly to WS binary relay if WebRTC offer fails
      } finally {
        entry.makingOffer = false;
      }
    }

    if (entry.dc?.readyState === 'open') return true;
    return new Promise<boolean>((resolve) => {
      const start = Date.now();
      const poll = () => {
        if (entry.dc?.readyState === 'open') {
          resolve(true);
          return;
        }
        if (Date.now() - start > 350) {
          resolve(false);
          return;
        }
        setTimeout(poll, 20);
      };
      poll();
    });
  }

  public async handleSignal(
    fromPeerId: string,
    type: string,
    msg: Record<string, unknown>
  ): Promise<void> {
    if (typeof RTCPeerConnection === 'undefined' || !fromPeerId) return;

    if (type === 'webrtc:offer') {
      const sdp = msg.sdp as RTCSessionDescriptionInit | undefined;
      if (!sdp) return;
      const entry = this.peers.get(fromPeerId) || this.createPeerEntry(fromPeerId, false);
      const polite = this.localPeerId < fromPeerId;
      const offerCollision = entry.makingOffer || entry.pc.signalingState !== 'stable';
      if (offerCollision && !polite) return;

      try {
        await entry.pc.setRemoteDescription(new RTCSessionDescription(sdp));
        for (const cand of entry.pendingCandidates.splice(0)) {
          await entry.pc.addIceCandidate(new RTCIceCandidate(cand)).catch(() => {});
        }
        const answer = await entry.pc.createAnswer();
        await entry.pc.setLocalDescription(answer);
        this.sendSignal(fromPeerId, 'webrtc:answer', { sdp: entry.pc.localDescription });
      } catch {
        // ignore negotiation race
      }
      return;
    }

    if (type === 'webrtc:answer') {
      const sdp = msg.sdp as RTCSessionDescriptionInit | undefined;
      const entry = this.peers.get(fromPeerId);
      if (!sdp || !entry) return;
      try {
        if (entry.pc.signalingState === 'have-local-offer') {
          await entry.pc.setRemoteDescription(new RTCSessionDescription(sdp));
          for (const cand of entry.pendingCandidates.splice(0)) {
            await entry.pc.addIceCandidate(new RTCIceCandidate(cand)).catch(() => {});
          }
        }
      } catch {
        // ignore stale answer
      }
      return;
    }

    if (type === 'webrtc:ice-candidate') {
      const candidate = msg.candidate as RTCIceCandidateInit | undefined;
      if (!candidate) return;
      const entry = this.peers.get(fromPeerId) || this.createPeerEntry(fromPeerId, false);
      try {
        if (entry.pc.remoteDescription) {
          await entry.pc.addIceCandidate(new RTCIceCandidate(candidate));
        } else {
          entry.pendingCandidates.push(candidate);
        }
      } catch {
        // ignore late candidate
      }
    }
  }

  private getMaxSegmentBytes(pc: RTCPeerConnection): number {
    const maxSctp = pc.sctp?.maxMessageSize;
    if (!maxSctp || !Number.isFinite(maxSctp)) return DEFAULT_DC_SEGMENT_BYTES;
    return Math.min(MAX_DC_SEGMENT_BYTES, Math.max(DEFAULT_DC_SEGMENT_BYTES, Math.floor(maxSctp * 0.85)));
  }

  public async sendBinaryChunk(targetPeerId: string, frame: BinaryChunkFrame): Promise<boolean> {
    const entry = this.peers.get(targetPeerId);
    const dc = entry?.dc;
    if (!entry || !dc || dc.readyState !== 'open') return false;

    const segmentBytes = this.getMaxSegmentBytes(entry.pc);
    const tidBytes = textEncoder.encode(frame.transferId);
    const ivLen = frame.encrypted ? frame.iv.byteLength : 0;
    const bodyLen = 1 + 2 + 4 + tidBytes.byteLength + ivLen + frame.payload.byteLength;
    const totalParts = Math.max(1, Math.ceil(bodyLen / segmentBytes));

    // Inner envelope: [encFlag(1), tidLen(2), chunkIdx(4), tidBytes, iv(if enc), payload]
    const envelope = new Uint8Array(bodyLen);
    const view = new DataView(envelope.buffer);
    let offset = 0;
    envelope[offset++] = frame.encrypted ? 1 : 0;
    view.setUint16(offset, tidBytes.byteLength, false);
    offset += 2;
    view.setUint32(offset, frame.chunkIndex, false);
    offset += 4;
    envelope.set(tidBytes, offset);
    offset += tidBytes.byteLength;
    if (frame.encrypted && ivLen > 0) {
      envelope.set(frame.iv, offset);
      offset += ivLen;
    }
    envelope.set(frame.payload, offset);

    const frameId = computeFrameId(tidBytes, frame.chunkIndex);

    for (let partIndex = 0; partIndex < totalParts; partIndex++) {
      if (dc.readyState !== 'open') return false;

      if (dc.bufferedAmount > HIGH_WATER_MARK_BYTES) {
        await new Promise<void>((resolve) => {
          const timer = setTimeout(() => {
            dc.removeEventListener('bufferedamountlow', onLow);
            resolve();
          }, 80);
          const onLow = () => {
            clearTimeout(timer);
            dc.removeEventListener('bufferedamountlow', onLow);
            resolve();
          };
          dc.addEventListener('bufferedamountlow', onLow);
        });
      }

      const start = partIndex * segmentBytes;
      const slice = envelope.subarray(start, Math.min(start + segmentBytes, envelope.byteLength));
      // Segment header: [frameId(4), partIndex(2), totalParts(2)] + slice
      const packet = new Uint8Array(8 + slice.byteLength);
      const pView = new DataView(packet.buffer);
      pView.setUint32(0, frameId, false);
      pView.setUint16(4, partIndex, false);
      pView.setUint16(6, totalParts, false);
      packet.set(slice, 8);

      try {
        dc.send(packet);
      } catch {
        return false;
      }
    }

    return true;
  }

  public closePeer(peerId: string): void {
    const entry = this.peers.get(peerId);
    if (!entry) return;
    entry.dc?.close();
    entry.pc.close();
    this.peers.delete(peerId);
    for (const [key, buf] of this.assemblies.entries()) {
      if (buf.peerId === peerId) {
        this.assemblies.delete(key);
      }
    }
  }

  public dispose(): void {
    for (const peerId of Array.from(this.peers.keys())) {
      this.closePeer(peerId);
    }
    this.assemblies.clear();
  }

  private createPeerEntry(targetPeerId: string, initiator: boolean): PeerConnectionEntry {
    const iceServers: RTCIceServer[] = navigator.onLine
      ? [{ urls: 'stun:stun.l.google.com:19302' }]
      : [];
    const pc = new RTCPeerConnection({ iceServers });

    const entry: PeerConnectionEntry = {
      pc,
      dc: null,
      makingOffer: false,
      pendingCandidates: [],
    };
    this.peers.set(targetPeerId, entry);

    pc.onicecandidate = (ev) => {
      if (ev.candidate) {
        this.sendSignal(targetPeerId, 'webrtc:ice-candidate', {
          candidate: ev.candidate.toJSON(),
        });
      }
    };

    pc.onconnectionstatechange = () => {
      if (pc.connectionState === 'failed' || pc.connectionState === 'closed') {
        this.onChannelStateChange?.(targetPeerId, false);
      }
    };

    const bindDataChannel = (dc: RTCDataChannel) => {
      dc.binaryType = 'arraybuffer';
      dc.bufferedAmountLowThreshold = LOW_WATER_THRESHOLD_BYTES;
      entry.dc = dc;
      dc.onopen = () => this.onChannelStateChange?.(targetPeerId, true);
      dc.onclose = () => this.onChannelStateChange?.(targetPeerId, false);
      dc.onmessage = (ev) => {
        if (ev.data instanceof ArrayBuffer) {
          this.handleIncomingSegment(targetPeerId, new Uint8Array(ev.data));
        }
      };
    };

    if (initiator) {
      const dc = pc.createDataChannel('vega-fast', { ordered: true });
      bindDataChannel(dc);
    } else {
      pc.ondatachannel = (ev) => bindDataChannel(ev.channel);
    }

    return entry;
  }

  private handleIncomingSegment(fromPeerId: string, packet: Uint8Array): void {
    if (packet.byteLength < 8) return;
    const view = new DataView(packet.buffer, packet.byteOffset, packet.byteLength);
    const frameId = view.getUint32(0, false);
    const partIndex = view.getUint16(4, false);
    const totalParts = view.getUint16(6, false);
    if (totalParts === 0 || partIndex >= totalParts) return;
    const slice = packet.subarray(8);

    if (totalParts === 1 && partIndex === 0) {
      this.decodeEnvelope(fromPeerId, slice);
      return;
    }

    const key = `${fromPeerId}:${frameId}`;
    let buf = this.assemblies.get(key);
    const now = Date.now();
    if (!buf || buf.totalParts !== totalParts) {
      if (this.assemblies.size > 64) {
        for (const [k, v] of this.assemblies.entries()) {
          if (now - v.createdAt > 60_000) this.assemblies.delete(k);
        }
      }
      buf = {
        peerId: fromPeerId,
        createdAt: now,
        totalParts,
        receivedParts: 0,
        parts: new Array<Uint8Array | null>(totalParts).fill(null),
      };
      this.assemblies.set(key, buf);
    }

    if (!buf.parts[partIndex]) {
      buf.parts[partIndex] = slice;
      buf.receivedParts += 1;
    }

    if (buf.receivedParts === buf.totalParts) {
      this.assemblies.delete(key);
      const totalLen = buf.parts.reduce((sum, p) => sum + (p?.byteLength || 0), 0);
      const joined = new Uint8Array(totalLen);
      let off = 0;
      for (const p of buf.parts) {
        if (!p) return;
        joined.set(p, off);
        off += p.byteLength;
      }
      this.decodeEnvelope(fromPeerId, joined);
    }
  }

  private decodeEnvelope(fromPeerId: string, envelope: Uint8Array): void {
    if (envelope.byteLength < 7) return;
    const view = new DataView(envelope.buffer, envelope.byteOffset, envelope.byteLength);
    let offset = 0;
    const encrypted = envelope[offset++] === 1;
    const tidLen = view.getUint16(offset, false);
    offset += 2;
    const chunkIndex = view.getUint32(offset, false);
    offset += 4;
    if (offset + tidLen > envelope.byteLength) return;
    const transferId = textDecoder.decode(envelope.subarray(offset, offset + tidLen));
    offset += tidLen;

    let iv: Uint8Array = new Uint8Array(0);
    if (encrypted) {
      if (offset + 12 > envelope.byteLength) return;
      iv = envelope.subarray(offset, offset + 12);
      offset += 12;
    }
    const payload = envelope.subarray(offset);
    this.onBinaryChunk(fromPeerId, { transferId, chunkIndex, encrypted, iv, payload });
  }
}
