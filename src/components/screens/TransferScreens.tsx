import React from 'react';
import {
  Pause,
  Play,
  RotateCcw,
  ShieldCheck,
  X,
} from 'lucide-react';
import { useVega } from '../../context/VegaContext.tsx';
import { formatBytes, formatDuration, formatEta, formatSpeed } from '../../lib/formatters.ts';
import {
  RecoveryErrorIllustration,
  VerifiedSuccessIllustration,
} from '../graphics/VegaGraphics.tsx';
import { HeritageScreenCard } from '../HeritageScreenCard.tsx';
import { TransferAnimation } from '../TransferAnimation.tsx';
import { TransferStatus } from '../TransferStatus.tsx';

export function TransferProgressScreen() {
  const {
    transfers,
    settings,
    pauseTransfer,
    resumeTransfer,
    cancelTransfer,
    retryTransfer,
    pauseAllTransfers,
    resumeAllTransfers,
    cancelAllTransfers,
    setScreen,
  } = useVega();

  const isHi = settings.language === 'hi';

  const hasStreaming = transfers.some(
    (j) =>
      j.status === 'transferring' ||
      j.status === 'encrypting' ||
      j.status === 'verifying' ||
      j.status === 'awaiting-approval'
  );
  const hasPaused = transfers.some((j) => j.status === 'paused');

  return (
    <HeritageScreenCard
      title={isHi ? 'लाइव ट्रांसफ़र' : 'Active Transfers'}
      subtitle={isHi ? 'आपकी फ़ाइलों की लाइव प्रगति' : 'Live file transfer progress'}
      onBack={() => setScreen('dashboard')}
      backLabel={isHi ? 'वापस जाएं' : 'Back'}
      rightAction={
        <button
          type="button"
          onClick={() => setScreen('send')}
          className="min-h-[38px] px-3.5 py-1.5 rounded-full bg-gradient-to-r from-[#C85A00] to-[#B84E00] border border-[#F5D08A]/75 text-white text-xs font-semibold whitespace-nowrap cursor-pointer"
        >
          {isHi ? 'नई फ़ाइल' : 'Send More'}
        </button>
      }
    >
      {(hasStreaming || hasPaused) && (
        <div className="flex flex-wrap items-center gap-2">
          {hasStreaming && (
            <button
              type="button"
              onClick={pauseAllTransfers}
              className="min-h-[38px] px-3.5 py-1.5 rounded-full border border-[#C5A059]/50 bg-white/90 dark:bg-[#0D2148] text-xs font-semibold text-[#0A1F44] dark:text-[#E4C788] inline-flex items-center gap-1.5 whitespace-nowrap cursor-pointer"
            >
              <Pause className="w-3.5 h-3.5" />
              <span>{isHi ? 'सभी रोकें' : 'Pause All'}</span>
            </button>
          )}
          {hasPaused && (
            <button
              type="button"
              onClick={() => void resumeAllTransfers()}
              className="min-h-[38px] px-3.5 py-1.5 rounded-full bg-gradient-to-r from-[#D96B08] to-[#B84E00] border border-[#F5D08A]/75 text-white text-xs font-semibold inline-flex items-center gap-1.5 whitespace-nowrap cursor-pointer"
            >
              <Play className="w-3.5 h-3.5" />
              <span>{isHi ? 'सभी शुरू करें' : 'Resume All'}</span>
            </button>
          )}
          <button
            type="button"
            onClick={cancelAllTransfers}
            className="min-h-[38px] px-3.5 py-1.5 rounded-full border border-red-300 dark:border-red-900/60 bg-white/90 dark:bg-[#0D2148] text-red-600 dark:text-red-400 text-xs font-semibold inline-flex items-center gap-1.5 whitespace-nowrap cursor-pointer"
          >
            <X className="w-3.5 h-3.5" />
            <span>{isHi ? 'सभी रद्द करें' : 'Cancel All'}</span>
          </button>
        </div>
      )}

      {transfers.length === 0 ? (
        <TransferStatus jobs={[]} />
      ) : (
        <div className="space-y-4">
          {transfers.length > 1 && <TransferStatus jobs={transfers} compact />}

          <div className="space-y-3.5">
            {transfers.map((job) => {
              const isActive =
                job.status === 'transferring' ||
                job.status === 'encrypting' ||
                job.status === 'verifying' ||
                job.status === 'awaiting-approval';
              return (
                <div
                  key={job.id}
                  className="rounded-[24px] border border-[#C5A059]/45 dark:border-[#C5A059]/30 bg-white/90 dark:bg-[#0D2148]/90 p-4 sm:p-5 space-y-3.5"
                >
                  <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2.5">
                    <div className="min-w-0">
                      <p className="text-sm sm:text-base font-bold text-[#0A1F44] dark:text-white truncate">
                        {job.fileName}
                      </p>
                      <p className="text-xs font-mono tabular-nums text-[#6B5A3E] dark:text-[#93C5FD]">
                        {formatBytes(job.bytesTransferred)} / {formatBytes(job.fileSize)} ·{' '}
                        {formatSpeed(job.speedBytesPerSec)} · ETA {formatEta(job.etaSeconds)}
                      </p>
                    </div>

                    <div className="flex flex-wrap items-center gap-2 shrink-0">
                      {job.direction === 'send' && isActive && (
                        <button
                          type="button"
                          onClick={() => pauseTransfer(job.id)}
                          className="min-h-[36px] px-3 py-1 rounded-full border border-[#C5A059]/50 text-xs font-semibold text-[#0A1F44] dark:text-[#E4C788] inline-flex items-center gap-1 whitespace-nowrap cursor-pointer"
                        >
                          <Pause className="w-3.5 h-3.5" />
                          <span>{isHi ? 'रोकें' : 'Pause'}</span>
                        </button>
                      )}
                      {job.direction === 'send' && job.status === 'paused' && (
                        <button
                          type="button"
                          onClick={() => void resumeTransfer(job.id)}
                          className="min-h-[36px] px-3 py-1 rounded-full bg-gradient-to-r from-[#D96B08] to-[#B84E00] text-white text-xs font-semibold inline-flex items-center gap-1 whitespace-nowrap cursor-pointer"
                        >
                          <Play className="w-3.5 h-3.5" />
                          <span>{isHi ? 'शुरू करें' : 'Resume'}</span>
                        </button>
                      )}
                      {job.direction === 'send' && (job.status === 'failed' || job.status === 'cancelled') && (
                        <button
                          type="button"
                          onClick={() => void retryTransfer(job.id)}
                          className="min-h-[36px] px-3 py-1 rounded-full bg-gradient-to-r from-[#D96B08] to-[#B84E00] text-white text-xs font-semibold inline-flex items-center gap-1 whitespace-nowrap cursor-pointer"
                        >
                          <RotateCcw className="w-3.5 h-3.5" />
                          <span>{isHi ? 'पुनः प्रयास' : 'Retry'}</span>
                        </button>
                      )}
                      {isActive && (
                        <button
                          type="button"
                          onClick={() => cancelTransfer(job.id)}
                          className="min-h-[36px] px-3 py-1 rounded-full border border-red-300 dark:border-red-900/50 text-red-600 dark:text-red-400 text-xs font-semibold inline-flex items-center gap-1 whitespace-nowrap cursor-pointer"
                        >
                          <X className="w-3.5 h-3.5" />
                          <span>{isHi ? 'रद्द करें' : 'Cancel'}</span>
                        </button>
                      )}
                    </div>
                  </div>

                  <TransferAnimation
                    fileName={job.fileName}
                    fileSize={job.fileSize}
                    bytesTransferred={job.bytesTransferred}
                    completedChunks={job.completedChunks}
                    totalChunks={job.totalChunks}
                    speedBytesPerSec={job.speedBytesPerSec}
                    etaSeconds={job.etaSeconds}
                    status={job.status}
                    senderName={job.senderName}
                    senderPlatform={job.senderPlatform}
                    receiverName={job.receiverName}
                    receiverPlatform={job.receiverPlatform}
                    encrypted={job.encrypted}
                    integrityVerified={job.integrityVerified}
                    reducedMotion={settings.reducedMotion || !settings.enableAnimations}
                    isHi={isHi}
                  />

                  {job.errorMessage && (
                    <p className="text-xs text-red-600 dark:text-red-400">{job.errorMessage}</p>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      )}
    </HeritageScreenCard>
  );
}

export function TransferDetailsScreen() {
  const { transfers, history, selectedTransferId, setScreen, settings } = useVega();
  const isHi = settings.language === 'hi';

  const activeJob = transfers.find((t) => t.id === selectedTransferId) || transfers[0] || null;
  const histItem = history.find((h) => h.id === selectedTransferId) || null;

  const target = activeJob
    ? {
        fileName: activeJob.fileName,
        size: activeJob.fileSize,
        sender: activeJob.senderName,
        receiver: activeJob.receiverName,
        status: activeJob.status,
        verified: activeJob.integrityVerified,
        durationMs: activeJob.durationMs,
        speed: activeJob.speedBytesPerSec,
        error: activeJob.errorMessage,
      }
    : histItem
    ? {
        fileName: histItem.fileName,
        size: histItem.fileSize,
        sender: histItem.senderName,
        receiver: histItem.receiverName,
        status: histItem.status,
        verified: histItem.integrityVerified,
        durationMs: histItem.durationMs,
        speed: histItem.averageSpeedBps,
        error: undefined,
      }
    : null;

  return (
    <HeritageScreenCard
      title={isHi ? 'ट्रांसफ़र विवरण' : 'Transfer Summary'}
      subtitle={target?.fileName}
      onBack={() => setScreen('transfer-history')}
      backLabel={isHi ? 'वापस जाएं' : 'Back'}
    >
      {!target ? (
        <div className="rounded-[24px] border border-[#C5A059]/45 bg-white/90 dark:bg-[#0D2148]/90 p-10 text-center space-y-3">
          <p className="text-sm font-bold text-[#0A1F44] dark:text-white">
            {isHi ? 'कोई ट्रांसफ़र चयनित नहीं है' : 'No Transfer Selected'}
          </p>
          <button
            type="button"
            onClick={() => setScreen('transfer-history')}
            className="min-h-[38px] px-4 py-1.5 rounded-full bg-gradient-to-r from-[#D96B08] to-[#B84E00] text-white text-xs font-semibold cursor-pointer"
          >
            {isHi ? 'इतिहास देखें' : 'View History'}
          </button>
        </div>
      ) : (
        <div className="rounded-[24px] border border-[#C5A059]/45 dark:border-[#C5A059]/30 bg-white/90 dark:bg-[#0D2148]/90 p-5 space-y-5">
          <div className="flex items-center gap-4">
            {target.status === 'failed' ? (
              <RecoveryErrorIllustration />
            ) : target.verified ? (
              <VerifiedSuccessIllustration />
            ) : (
              <ShieldCheck className="w-12 h-12 text-[#D96B08] dark:text-[#E4C788]" />
            )}
            <div className="min-w-0">
              <h2 className="text-lg font-bold text-[#0A1F44] dark:text-white capitalize">
                {target.verified ? (isHi ? 'पूर्ण' : 'Completed') : target.status}
              </h2>
              <p className="text-xs text-[#6B5A3E] dark:text-[#93C5FD] truncate">
                {target.sender} → {target.receiver} · {formatBytes(target.size)}
              </p>
            </div>
          </div>

          <dl className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm pt-4 border-t border-[#C5A059]/25 dark:border-[#1B3154]">
            <div>
              <dt className="text-xs text-[#7A633C] dark:text-[#93C5FD]">
                {isHi ? 'औसत गति' : 'Average Speed'}
              </dt>
              <dd className="font-mono tabular-nums font-medium text-[#0A1F44] dark:text-white">
                {formatSpeed(target.speed)}
              </dd>
            </div>
            <div>
              <dt className="text-xs text-[#7A633C] dark:text-[#93C5FD]">
                {isHi ? 'कुल समय' : 'Duration'}
              </dt>
              <dd className="font-mono tabular-nums font-medium text-[#0A1F44] dark:text-white">
                {formatDuration(target.durationMs)}
              </dd>
            </div>
          </dl>

          {target.error && (
            <div className="rounded-2xl bg-red-50 dark:bg-red-950/30 border border-red-300 dark:border-red-900 p-4 text-xs text-red-700 dark:text-red-300">
              {target.error}
            </div>
          )}
        </div>
      )}
    </HeritageScreenCard>
  );
}
