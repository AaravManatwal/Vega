import React from 'react';
import {
  CheckCircle2,
  Loader2,
  Pause,
  PauseCircle,
  Play,
  RotateCcw,
  X,
  XCircle,
} from 'lucide-react';
import { useVega } from '../context/VegaContext.tsx';
import { formatBytes, formatEta, formatSpeed } from '../lib/formatters.ts';
import type { TransferJob } from '../types/vega.ts';

export interface TransferStatusProps {
  jobs?: TransferJob[];
  compact?: boolean;
  onInspectJob?: (jobId: string) => void;
}

export function TransferStatus({ jobs }: TransferStatusProps) {
  const {
    transfers,
    settings,
    pauseTransfer,
    resumeTransfer,
    cancelTransfer,
    retryTransfer,
  } = useVega();

  const isHi = settings.language === 'hi';
  const list = jobs ?? transfers;

  if (list.length === 0) {
    return (
      <div className="rounded-[24px] border border-[#C5A059]/45 bg-white/90 dark:bg-[#0D2148]/90 p-6 text-center">
        <p className="text-sm font-semibold text-[#0A1F44] dark:text-white">
          {isHi ? 'अभी कोई सक्रिय ट्रांसफ़र नहीं है' : 'No active file transfers'}
        </p>
        <p className="mt-1 text-xs text-[#6B5A3E] dark:text-[#93C5FD]">
          {isHi
            ? 'फ़ाइलें चुनें और नज़दीकी डिवाइस से जुड़कर ट्रांसफ़र शुरू करें।'
            : 'Select files and connect with a nearby device to start sharing.'}
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {list.map((job) => {
        const pct =
          job.fileSize > 0
            ? Math.min(100, Math.max(0, (job.bytesTransferred / job.fileSize) * 100))
            : job.status === 'completed'
            ? 100
            : 0;
        const isStreaming =
          job.status === 'transferring' || job.status === 'encrypting' || job.status === 'verifying';
        const isSuccess = job.status === 'completed';
        const isFailed = job.status === 'failed' || job.status === 'cancelled';
        const isPaused = job.status === 'paused';

        const barColor = isSuccess
          ? 'bg-emerald-600 dark:bg-emerald-400'
          : isFailed
          ? 'bg-red-600 dark:bg-red-500'
          : isPaused
          ? 'bg-[#D97706] dark:bg-[#F59E0B]'
          : 'bg-gradient-to-r from-[#C85A00] to-[#D96B08]';

        const StatusIcon = isSuccess
          ? CheckCircle2
          : isFailed
          ? XCircle
          : isPaused
          ? PauseCircle
          : Loader2;

        const iconClass = isSuccess
          ? 'text-emerald-600 dark:text-emerald-400'
          : isFailed
          ? 'text-red-600 dark:text-red-400'
          : isPaused
          ? 'text-amber-600 dark:text-[#F59E0B]'
          : 'text-[#D96B08] dark:text-[#E4C788] animate-spin';

        const statusText = isSuccess
          ? isHi
            ? 'पूर्ण'
            : 'Completed'
          : job.status === 'verifying'
          ? isHi
            ? 'जांच हो रही है...'
            : 'Verifying...'
          : job.status === 'awaiting-approval'
          ? isHi
            ? 'स्वीकृति की प्रतीक्षा...'
            : 'Waiting for approval...'
          : job.status === 'paused'
          ? isHi
            ? 'रुका हुआ'
            : 'Paused'
          : job.status === 'cancelled'
          ? isHi
            ? 'रद्द'
            : 'Cancelled'
          : job.status === 'failed'
          ? isHi
            ? 'विफल'
            : 'Failed'
          : job.direction === 'send'
          ? isHi
            ? 'भेजा जा रहा है...'
            : 'Sending...'
          : isHi
          ? 'प्राप्त हो रहा है...'
          : 'Receiving...';

        return (
          <div
            key={job.id}
            className="rounded-2xl border border-[#C5A059]/35 bg-white dark:bg-[#0A1F44] p-4 space-y-3"
          >
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2.5">
              <div className="flex items-center gap-2.5 min-w-0">
                <StatusIcon className={`w-5 h-5 shrink-0 ${iconClass}`} aria-label={statusText} />
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-[#0A1F44] dark:text-white truncate">
                    {job.fileName}
                  </p>
                  <p className="text-xs font-mono tabular-nums text-[#4A5E7A] dark:text-[#93C5FD]">
                    {statusText} ·{' '}
                    {job.direction === 'send' ? `To ${job.receiverName}` : `From ${job.senderName}`} ·{' '}
                    {formatBytes(job.bytesTransferred)} / {formatBytes(job.fileSize)}
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-2 shrink-0">
                {job.direction === 'send' && isStreaming && (
                  <button
                    type="button"
                    onClick={() => pauseTransfer(job.id)}
                    className="min-h-[38px] px-3 py-1.5 rounded-full border border-[#C5A059]/50 dark:border-[#1B3154] text-xs font-medium text-[#0A1F44] dark:text-white hover:bg-[#FAF6EC] dark:hover:bg-[#1B3154]/60 inline-flex items-center gap-1 whitespace-nowrap cursor-pointer"
                  >
                    <Pause className="w-3.5 h-3.5" />
                    <span>{isHi ? 'रोकें' : 'Pause'}</span>
                  </button>
                )}
                {job.direction === 'send' && isPaused && (
                  <button
                    type="button"
                    onClick={() => void resumeTransfer(job.id)}
                    className="min-h-[38px] px-3 py-1.5 rounded-full bg-gradient-to-r from-[#C85A00] to-[#B84E00] border border-[#F5D08A]/75 text-white text-xs font-medium inline-flex items-center gap-1 whitespace-nowrap cursor-pointer"
                  >
                    <Play className="w-3.5 h-3.5" />
                    <span>{isHi ? 'शुरू करें' : 'Resume'}</span>
                  </button>
                )}
                {job.direction === 'send' && isFailed && (
                  <button
                    type="button"
                    onClick={() => void retryTransfer(job.id)}
                    className="min-h-[38px] px-3 py-1.5 rounded-full bg-gradient-to-r from-[#C85A00] to-[#B84E00] border border-[#F5D08A]/75 text-white text-xs font-medium inline-flex items-center gap-1 whitespace-nowrap cursor-pointer"
                  >
                    <RotateCcw className="w-3.5 h-3.5" />
                    <span>{isHi ? 'पुनः प्रयास' : 'Retry'}</span>
                  </button>
                )}
                {(isStreaming || isPaused) && (
                  <button
                    type="button"
                    onClick={() => cancelTransfer(job.id)}
                    className="min-h-[38px] px-3 py-1.5 rounded-full border border-red-200 dark:border-red-900/50 text-red-600 dark:text-red-400 text-xs font-medium inline-flex items-center gap-1 whitespace-nowrap cursor-pointer"
                  >
                    <X className="w-3.5 h-3.5" />
                    <span>{isHi ? 'रद्द करें' : 'Cancel'}</span>
                  </button>
                )}
              </div>
            </div>

            {/* Progress Bar */}
            <div className="space-y-1.5">
              <div
                role="progressbar"
                aria-valuemin={0}
                aria-valuemax={100}
                aria-valuenow={Math.round(pct)}
                aria-label={`${job.fileName} transfer progress`}
                className="h-2.5 w-full rounded-full bg-[#E8EDF5] dark:bg-[#06132B] overflow-hidden"
              >
                <div
                  className={`h-full rounded-full transition-all duration-200 ${barColor}`}
                  style={{ width: `${pct}%` }}
                />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2 text-xs font-mono tabular-nums text-[#4A5E7A] dark:text-[#93C5FD]">
                <span>{Math.round(pct)}%</span>
                <span>
                  {isStreaming
                    ? `${formatSpeed(job.speedBytesPerSec)} · ${formatEta(job.etaSeconds)}`
                    : isSuccess
                    ? statusText
                    : isPaused
                    ? isHi
                      ? 'रुका हुआ'
                      : 'Paused'
                    : job.errorMessage || statusText}
                </span>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}
