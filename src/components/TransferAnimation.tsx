import React from 'react';
import { motion } from 'motion/react';
import { CheckCircle2, File as FileIcon, PauseCircle, ShieldAlert } from 'lucide-react';
import { formatBytes, formatEta, formatSpeed, platformLabel } from '../lib/formatters.ts';
import type { DevicePlatform, TransferStatus } from '../types/vega.ts';
import { DeviceVector } from './graphics/VegaGraphics.tsx';

export interface TransferAnimationProps {
  fileName: string;
  fileSize: number;
  bytesTransferred: number;
  completedChunks: number;
  totalChunks: number;
  speedBytesPerSec: number;
  etaSeconds: number;
  status: TransferStatus;
  senderName: string;
  senderPlatform: DevicePlatform;
  receiverName: string;
  receiverPlatform: DevicePlatform;
  encrypted?: boolean;
  integrityVerified?: boolean;
  reducedMotion?: boolean;
  isHi?: boolean;
}

export function TransferAnimation({
  fileName,
  fileSize,
  bytesTransferred,
  speedBytesPerSec,
  etaSeconds,
  status,
  senderName,
  senderPlatform,
  receiverName,
  receiverPlatform,
  reducedMotion = false,
  isHi = false,
}: TransferAnimationProps) {
  const progressPct = fileSize > 0 ? Math.min(100, Math.max(0, (bytesTransferred / fileSize) * 100)) : 0;
  const isStreaming = status === 'transferring' || status === 'encrypting' || status === 'verifying';
  const isPaused = status === 'paused';
  const isFailed = status === 'failed' || status === 'cancelled';
  const isComplete = status === 'completed';

  const statusLabel = isComplete
    ? isHi
      ? 'पूर्ण'
      : 'Completed'
    : status === 'verifying'
    ? isHi
      ? 'जांच हो रही है...'
      : 'Verifying...'
    : status === 'encrypting'
    ? isHi
      ? 'तैयार हो रहा है...'
      : 'Preparing...'
    : isPaused
    ? isHi
      ? 'रुका हुआ'
      : 'Paused'
    : isFailed
    ? status === 'cancelled'
      ? isHi
        ? 'रद्द'
        : 'Cancelled'
      : isHi
        ? 'विफल'
        : 'Failed'
    : isHi
      ? 'भेजा जा रहा है...'
      : 'Transferring...';

  const ringRadius = 26;
  const ringCircumference = 2 * Math.PI * ringRadius;
  const ringOffset = ringCircumference - (progressPct / 100) * ringCircumference;
  const packetOffsets = [0, 0.33, 0.66];

  return (
    <div className="rounded-2xl border border-[#C5A059]/45 bg-white dark:bg-[#0A1F44] overflow-hidden shadow-[0_12px_32px_rgba(10,31,68,0.12)]">
      {/* Sender <-> Receiver Heritage Banner */}
      <div className="bg-[#0A1F44] bg-gradient-to-r from-[#0A1F44] via-[#132952] to-[#B84E00] p-5 text-white bg-rajasthani-jali">
        <div className="flex flex-wrap items-center justify-between gap-2 text-xs text-white/90 pb-4 border-b border-[#C5A059]/30">
          <div className="flex items-center gap-2 min-w-0">
            <FileIcon className="w-4 h-4 text-[#E4C788] shrink-0" />
            <span className="font-semibold text-white truncate max-w-[260px]">{fileName}</span>
          </div>
          <span className="inline-flex items-center gap-1 font-medium text-white font-mono tabular-nums">
            {isComplete && <CheckCircle2 className="w-3.5 h-3.5 text-[#86EFAC]" />}
            {isPaused && <PauseCircle className="w-3.5 h-3.5 text-[#FDE68A]" />}
            {isFailed && <ShieldAlert className="w-3.5 h-3.5 text-[#FCA5A5]" />}
            <span>{statusLabel}</span>
          </span>
        </div>

        <div className="pt-5 flex flex-col sm:flex-row items-center justify-between gap-4">
          {/* Sender */}
          <div className="flex items-center gap-3 sm:w-44 shrink-0">
            <div className="relative">
              <DeviceVector platform={senderPlatform} size={42} />
              {isStreaming && !reducedMotion && (
                <motion.span
                  className="absolute -inset-1 rounded-xl border border-[#F5D08A]/70 pointer-events-none"
                  animate={{ opacity: [0.7, 0.15, 0.7] }}
                  transition={{ repeat: Infinity, duration: 1.6, ease: 'easeInOut' }}
                />
              )}
            </div>
            <div className="min-w-0">
              <p className="text-[11px] text-white/75">{isHi ? 'भेजने वाला' : 'Sender'}</p>
              <p className="text-sm font-semibold text-white truncate">{senderName}</p>
              <p className="text-[11px] text-white/75">{platformLabel(senderPlatform)}</p>
            </div>
          </div>

          {/* Center Orbital Progress Ring + Data Stream */}
          <div className="flex-1 w-full flex items-center gap-3 px-2">
            <div className="flex-1 relative h-2 rounded-full bg-black/25 overflow-hidden">
              <div
                className="h-full rounded-full bg-[#D96B08] transition-all duration-200"
                style={{ width: `${progressPct}%` }}
              />
              {isStreaming && !reducedMotion && (
                <div className="absolute inset-0 pointer-events-none overflow-hidden flex items-center">
                  {packetOffsets.map((delayFactor, idx) => (
                    <motion.div
                      key={idx}
                      className="absolute w-2.5 h-2.5 rounded-full bg-[#FFE7BA] shadow-[0_0_8px_rgba(255,231,186,0.9)]"
                      initial={{ left: '0%', opacity: 0 }}
                      animate={{ left: ['0%', '96%'], opacity: [0, 1, 1, 0] }}
                      transition={{
                        repeat: Infinity,
                        duration: 1.25,
                        delay: delayFactor * 1.25,
                        ease: 'linear',
                      }}
                    />
                  ))}
                </div>
              )}
            </div>

            <div className="relative w-16 h-16 shrink-0 flex items-center justify-center">
              <svg width="64" height="64" viewBox="0 0 64 64" className="-rotate-90">
                <circle
                  cx="32"
                  cy="32"
                  r={ringRadius}
                  fill="rgba(10,31,68,0.55)"
                  stroke="rgba(255,255,255,0.2)"
                  strokeWidth="4.5"
                />
                <circle
                  cx="32"
                  cy="32"
                  r={ringRadius}
                  fill="none"
                  stroke={isFailed ? '#FCA5A5' : isPaused ? '#FCD34D' : '#E4C788'}
                  strokeWidth="4.5"
                  strokeLinecap="round"
                  strokeDasharray={ringCircumference}
                  strokeDashoffset={ringOffset}
                  className="transition-all duration-200"
                />
              </svg>
              <span className="absolute text-xs font-bold font-mono tabular-nums text-white">
                {Math.round(progressPct)}%
              </span>
            </div>

            <div className="flex-1 relative h-2 rounded-full bg-black/25 overflow-hidden">
              <div
                className="h-full rounded-full bg-[#E4C788] transition-all duration-200"
                style={{ width: `${progressPct}%` }}
              />
            </div>
          </div>

          {/* Receiver */}
          <div className="flex items-center gap-3 sm:w-44 shrink-0 sm:justify-end sm:text-right">
            <div className="min-w-0 order-2 sm:order-1">
              <p className="text-[11px] text-white/75">{isHi ? 'प्राप्तकर्ता' : 'Receiver'}</p>
              <p className="text-sm font-semibold text-white truncate">{receiverName}</p>
              <p className="text-[11px] text-white/75">{platformLabel(receiverPlatform)}</p>
            </div>
            <div className="relative order-1 sm:order-2">
              <DeviceVector platform={receiverPlatform} size={42} />
              {isComplete && (
                <span className="absolute -top-1 -right-1 w-4 h-4 rounded-full bg-emerald-500 text-white flex items-center justify-center">
                  <CheckCircle2 className="w-3 h-3" />
                </span>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* 3-Column Summary Strip */}
      <div className="grid grid-cols-3 divide-x divide-[#C5A059]/30 text-center py-3.5 px-2 bg-[#FAF6EC] dark:bg-[#06132B] border-t border-[#C5A059]/30">
        <div>
          <p className="text-[11px] font-medium text-[#7A633C] dark:text-[#93C5FD]">
            {isHi ? 'प्रगति' : 'Progress'}
          </p>
          <p className="mt-0.5 text-sm font-bold font-mono tabular-nums text-[#0A1F44] dark:text-white">
            {Math.round(progressPct)}%
          </p>
        </div>
        <div>
          <p className="text-[11px] font-medium text-[#7A633C] dark:text-[#93C5FD]">
            {isHi ? 'आकार' : 'Transferred'}
          </p>
          <p className="mt-0.5 text-sm font-bold font-mono tabular-nums text-[#0A1F44] dark:text-white">
            {formatBytes(bytesTransferred)} / {formatBytes(fileSize)}
          </p>
        </div>
        <div>
          <p className="text-[11px] font-medium text-[#7A633C] dark:text-[#93C5FD]">
            {isHi ? 'गति · समय' : 'Speed · ETA'}
          </p>
          <p className="mt-0.5 text-sm font-bold font-mono tabular-nums text-[#D96B08] dark:text-[#E4C788]">
            {isStreaming ? `${formatSpeed(speedBytesPerSec)} · ${formatEta(etaSeconds)}` : statusLabel}
          </p>
        </div>
      </div>
    </div>
  );
}
