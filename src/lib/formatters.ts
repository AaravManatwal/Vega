import type { DevicePlatform, FileCategory } from '../types/vega.ts';

export function detectDevicePlatform(): DevicePlatform {
  const ua = navigator.userAgent.toLowerCase();
  if (ua.includes('android')) return 'android';
  if (ua.includes('windows')) return 'windows';
  if (ua.includes('macintosh') || ua.includes('mac os')) return 'macos';
  if (ua.includes('linux')) return 'linux';
  return 'web';
}

export function getDefaultDeviceName(platform: DevicePlatform): string {
  const shortId = Math.random().toString(36).slice(2, 6).toUpperCase();
  switch (platform) {
    case 'android':
      return `Android-Device-${shortId}`;
    case 'windows':
      return `Windows-PC-${shortId}`;
    case 'macos':
      return `Mac-Node-${shortId}`;
    case 'linux':
      return `Linux-Node-${shortId}`;
    default:
      return `Vega-Web-${shortId}`;
  }
}

export function categorizeFile(fileName: string, mimeType: string): FileCategory {
  const lower = fileName.toLowerCase();
  const mime = mimeType.toLowerCase();

  if (mime.startsWith('image/') || /\.(png|jpe?g|gif|webp|svg|bmp|heic|avif)$/.test(lower)) {
    return 'images';
  }
  if (mime.startsWith('video/') || /\.(mp4|mkv|webm|mov|avi|m4v)$/.test(lower)) {
    return 'videos';
  }
  if (mime.startsWith('audio/') || /\.(mp3|wav|ogg|flac|aac|m4a)$/.test(lower)) {
    return 'audio';
  }
  if (/\.(zip|rar|7z|tar|gz|bz2|xz)$/.test(lower)) {
    return 'archives';
  }
  if (/\.(apk|exe|msi|msix|dmg|deb|appimage)$/.test(lower)) {
    return 'applications';
  }
  if (
    mime.includes('pdf') ||
    mime.includes('word') ||
    mime.includes('excel') ||
    mime.includes('powerpoint') ||
    mime.startsWith('text/') ||
    /\.(pdf|docx?|xlsx?|pptx?|txt|md|csv|json|xml|rtf)$/.test(lower)
  ) {
    return 'documents';
  }
  return 'other';
}

export function formatBytes(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  const exp = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  const value = bytes / Math.pow(1024, exp);
  return `${value >= 100 || exp === 0 ? value.toFixed(0) : value.toFixed(1)} ${units[exp]}`;
}

export function formatSpeed(bytesPerSec: number): string {
  if (!Number.isFinite(bytesPerSec) || bytesPerSec <= 0) return '0 KB/s';
  if (bytesPerSec >= 1024 * 1024) {
    return `${(bytesPerSec / (1024 * 1024)).toFixed(2)} MB/s`;
  }
  return `${(bytesPerSec / 1024).toFixed(0)} KB/s`;
}

export function formatEta(seconds: number): string {
  if (!Number.isFinite(seconds) || seconds <= 0) return '—';
  if (seconds < 60) return `${Math.ceil(seconds)}s`;
  const mins = Math.floor(seconds / 60);
  const secs = Math.ceil(seconds % 60);
  return `${mins}m ${secs}s`;
}

export function formatDuration(ms: number): string {
  if (!Number.isFinite(ms) || ms <= 0) return '< 1s';
  if (ms < 1000) return `${ms} ms`;
  const sec = ms / 1000;
  if (sec < 60) return `${sec.toFixed(1)}s`;
  const mins = Math.floor(sec / 60);
  const remSec = Math.round(sec % 60);
  return `${mins}m ${remSec}s`;
}

export function platformLabel(platform: DevicePlatform): string {
  switch (platform) {
    case 'android':
      return 'Android';
    case 'windows':
      return 'Windows 10/11';
    case 'macos':
      return 'macOS';
    case 'linux':
      return 'Linux';
    default:
      return 'Web Node';
  }
}
