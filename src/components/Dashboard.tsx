import React from 'react';
import {
  Activity,
  ArrowDown,
  ArrowUp,
  HelpCircle,
  History,
  Menu,
  Moon,
  Pause,
  Play,
  Sun,
} from 'lucide-react';
import { useVega } from '../context/VegaContext.tsx';
import { VegaLogo } from './graphics/VegaGraphics.tsx';
import { PWAInstallButton } from './PWAInstallButton.tsx';
import { TransferAnimation } from './TransferAnimation.tsx';

export interface TransferDashboardProps {
  onOpenMenu?: () => void;
}

/**
 * Compact concentric Rajasthani Mandala / Kundan medallion rings around the
 * Send & Receive circular buttons.
 */
function HeritageMedallionRings({ variant }: { variant: 'send' | 'receive' }) {
  const strokeMain = variant === 'send' ? '#D96B08' : '#C5A059';
  const strokeAccent = variant === 'send' ? '#C5A059' : '#0A1F44';

  return (
    <svg
      viewBox="0 0 120 120"
      aria-hidden="true"
      className="pointer-events-none absolute inset-0 w-full h-full transition-transform duration-500 ease-out group-hover:rotate-12"
    >
      <circle
        cx="60"
        cy="60"
        r="55"
        fill="none"
        stroke={strokeMain}
        strokeOpacity="0.5"
        strokeWidth="1.2"
        strokeDasharray="4 4"
      />
      <circle
        cx="60"
        cy="60"
        r="49"
        fill="none"
        stroke={strokeAccent}
        strokeOpacity="0.38"
        strokeWidth="1.5"
      />
      {[0, 45, 90, 135, 180, 225, 270, 315].map((deg) => {
        const rad = (deg * Math.PI) / 180;
        const x = 60 + 55 * Math.cos(rad);
        const y = 60 + 55 * Math.sin(rad);
        return (
          <circle
            key={deg}
            cx={x}
            cy={y}
            r={deg % 90 === 0 ? 2.4 : 1.5}
            fill={strokeMain}
            fillOpacity={deg % 90 === 0 ? 0.92 : 0.62}
          />
        );
      })}
    </svg>
  );
}

export function TransferDashboard({ onOpenMenu }: TransferDashboardProps) {
  const {
    transfers,
    settings,
    updateSettings,
    t,
    setScreen,
    clearPreselectedSendFiles,
    pauseTransfer,
    resumeTransfer,
  } = useVega();

  const isHi = settings.language === 'hi';
  const isDark = settings.theme === 'dark';

  const activeTransfers = transfers.filter(
    (tr) =>
      tr.status === 'transferring' ||
      tr.status === 'verifying' ||
      tr.status === 'encrypting' ||
      tr.status === 'awaiting-approval' ||
      tr.status === 'paused'
  );

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      {/* Unified Rajasthani Heritage Home Card */}
      <section
        aria-label="Offline File Sharing"
        className="relative overflow-hidden rounded-none sm:rounded-[34px] bg-[#FFFDF8] dark:bg-[#0A1F44] bg-gradient-to-b from-[#FFFDF8] via-[#F7F1E2] to-[#EDE2C8] dark:from-[#0A1F44] dark:via-[#07193B] dark:to-[#04122B] text-[#0A1F44] dark:text-white min-h-[100svh] sm:min-h-[640px] shadow-[0_20px_54px_rgba(10,31,68,0.14)] dark:shadow-[0_24px_64px_rgba(6,17,41,0.55)] sm:border sm:border-[#C5A059]/70 dark:sm:border-[#C5A059]/55 flex flex-col justify-between px-4 pt-3.5 pb-6 sm:px-7 sm:pt-5 sm:pb-7 gap-3 bg-rajasthani-jali-light"
      >
        {/* Top Utility Bar (Cleanly separated ABOVE the Jharokha Arch) */}
        <header className="relative z-20 flex items-center justify-between gap-2 pb-1">
          <div className="flex items-center gap-2 min-w-0">
            {onOpenMenu && (
              <button
                type="button"
                onClick={onOpenMenu}
                aria-label="Open navigation menu"
                className="lg:hidden min-h-[42px] min-w-[42px] -ml-1 flex items-center justify-center rounded-xl text-[#0A1F44] dark:text-white/90 hover:bg-[#EFE8D5] dark:hover:bg-[#003366] transition-colors cursor-pointer"
              >
                <Menu className="w-5 h-5" />
              </button>
            )}
            <div className="flex items-center gap-2 min-w-0">
              <VegaLogo size={32} />
              <div className="flex items-baseline gap-1.5 min-w-0">
                <span className="font-heritage text-lg sm:text-xl tracking-wider text-[#0A1F44] dark:text-white whitespace-nowrap">
                  {t.appName}
                </span>
                <span className="font-heritage text-xs sm:text-sm text-[#8A651B] dark:text-[#C5A059] whitespace-nowrap">
                  {t.appNativeName}
                </span>
              </div>
            </div>
          </div>

          <div className="flex items-center gap-1.5 shrink-0">
            <PWAInstallButton compact />

            <button
              type="button"
              onClick={() =>
                void updateSettings({ language: settings.language === 'en' ? 'hi' : 'en' })
              }
              className="min-h-[38px] px-3 py-1.5 rounded-full border border-[#C5A059]/60 dark:border-[#C5A059]/45 bg-white/90 dark:bg-[#0D2148]/90 hover:bg-[#FAF6EC] dark:hover:bg-[#142E60] text-xs font-semibold text-[#0A1F44] dark:text-[#E4C788] whitespace-nowrap shrink-0 transition-colors cursor-pointer shadow-xs"
            >
              {settings.language === 'en' ? 'हिन्दी' : 'EN'}
            </button>

            <button
              type="button"
              onClick={() =>
                void updateSettings({ theme: settings.theme === 'dark' ? 'light' : 'dark' })
              }
              aria-label={isDark ? 'Switch to Light theme' : 'Switch to Dark theme'}
              title={isDark ? 'Switch to Light theme' : 'Switch to Dark theme'}
              className="min-h-[38px] min-w-[38px] flex items-center justify-center rounded-full border border-[#C5A059]/60 dark:border-[#C5A059]/45 bg-white/90 dark:bg-[#0D2148]/90 hover:bg-[#FAF6EC] dark:hover:bg-[#142E60] text-[#0A1F44] dark:text-white transition-colors cursor-pointer shadow-xs"
            >
              {isDark ? (
                <Sun className="w-4 h-4 text-[#E4C788]" />
              ) : (
                <Moon className="w-4 h-4 text-[#8A651B]" />
              )}
            </button>
          </div>
        </header>

        {/* Inner Jharokha Arch Showcase Stage (Never overlaps top header!) */}
        <div className="relative flex-1 flex flex-col justify-between overflow-hidden rounded-[28px] border border-[#C5A059]/45 dark:border-[#C5A059]/35 bg-[#FFFDF8]/75 dark:bg-[#081A3E]/70 px-4 pt-6 pb-6 sm:px-8 sm:pt-7 sm:pb-7 shadow-inner">
          {/* Decorative Rajasthani Jharokha Arch + Warm Sandstone-Gold Wave Split */}
          <svg
            className="absolute inset-0 w-full h-full pointer-events-none"
            viewBox="0 0 800 640"
            preserveAspectRatio="none"
            aria-hidden="true"
          >
            <defs>
              <linearGradient id="vega-wave-fill-dark" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0%" stopColor="#0D2654" stopOpacity="0.95" />
                <stop offset="100%" stopColor="#14326B" stopOpacity="0.98" />
              </linearGradient>
              <linearGradient id="vega-wave-fill-light" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0%" stopColor="#F4E6C8" stopOpacity="0.92" />
                <stop offset="100%" stopColor="#E6CC96" stopOpacity="0.96" />
              </linearGradient>
            </defs>

            {/* Sweeping Diagonal Wave separating Send (upper-left) & Receive (lower-right) */}
            <path
              d="M 0 385 C 250 385 545 330 800 215 L 800 640 L 0 640 Z"
              fill={isDark ? 'url(#vega-wave-fill-dark)' : 'url(#vega-wave-fill-light)'}
            />
            <path
              d="M 0 400 C 265 396 555 342 800 230"
              fill="none"
              stroke={isDark ? '#D96B08' : '#C5A059'}
              strokeOpacity="0.24"
              strokeWidth="1.5"
            />
            <path
              d="M 0 385 C 250 385 545 330 800 215"
              fill="none"
              stroke="#C5A059"
              strokeOpacity={isDark ? '0.68' : '0.82'}
              strokeWidth="2.4"
            />

            {/* Cusped Jharokha Arch cleanly framing this stage */}
            <path
              d="M 22 618 V 98 C 22 58 108 44 225 44 C 315 44 362 28 400 10 C 438 28 485 44 575 44 C 692 44 778 58 778 98 V 618"
              fill="none"
              stroke="#C5A059"
              strokeOpacity={isDark ? '0.34' : '0.45'}
              strokeWidth="1.6"
            />
          </svg>

          {/* Corner Heritage Diamonds */}
          <span
            aria-hidden="true"
            className="pointer-events-none absolute bottom-3 left-3 w-2 h-2 rotate-45 bg-[#C5A059]"
          />
          <span
            aria-hidden="true"
            className="pointer-events-none absolute bottom-3 right-3 w-2 h-2 rotate-45 bg-[#C5A059]"
          />

          {/* Centered Title + How it works */}
          <div className="relative z-10 flex flex-col items-center text-center pt-1">
            <h1 className="font-heritage text-2xl sm:text-[28px] tracking-wide text-[#0A1F44] dark:text-white">
              {isHi ? 'ऑफ़लाइन फ़ाइल शेयरिंग' : 'Offline File Sharing'}
            </h1>

            <button
              type="button"
              onClick={() => setScreen('help')}
              className="group mt-3 inline-flex flex-col items-center gap-1.5 cursor-pointer focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-[#D96B08]"
            >
              <span className="relative w-12 h-12 rounded-full border border-[#C5A059]/80 bg-[#FFF5E6]/90 dark:bg-[#0D2148]/90 flex items-center justify-center shadow-xs group-hover:scale-105 transition-transform">
                <span className="w-8 h-8 rounded-full bg-gradient-to-b from-[#D96B08] to-[#B84E00] border border-[#F5D08A]/85 text-white flex items-center justify-center">
                  <HelpCircle className="w-4 h-4" />
                </span>
              </span>
              <span className="text-xs font-semibold tracking-wide text-[#B84E00] dark:text-[#E4C788] group-hover:text-[#D96B08] dark:group-hover:text-white transition-colors">
                {isHi ? 'कैसे उपयोग करें' : 'How it works'}
              </span>
            </button>
          </div>

          {/* Diagonal Compact Heritage Medallion Buttons: Send & Receive */}
          <div className="relative z-10 flex-1 flex flex-col justify-center gap-7 sm:gap-9 py-4 px-1 sm:px-8 max-w-xl w-full mx-auto">
            {/* Upper-Left: SEND Saffron-Gold Medallion */}
            <div className="flex justify-start">
              <button
                type="button"
                onClick={() => setScreen('send')}
                className="group inline-flex items-center gap-4 sm:gap-6 cursor-pointer rounded-full pr-4 py-1 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-[#D96B08]"
              >
                <span className="relative w-24 h-24 sm:w-28 sm:h-28 flex items-center justify-center shrink-0">
                  <HeritageMedallionRings variant="send" />
                  <span className="w-[74px] h-[74px] sm:w-[84px] sm:h-[84px] rounded-full bg-[#FFF5E6]/95 dark:bg-[#221712]/90 border border-[#C5A059]/85 flex items-center justify-center shadow-[0_10px_28px_rgba(200,90,0,0.28)] group-hover:scale-105 transition-transform duration-200">
                    <span className="w-12 h-12 sm:w-14 sm:h-14 rounded-full bg-gradient-to-b from-[#E06D06] to-[#B84E00] border border-[#F5D08A]/85 text-white flex items-center justify-center shadow-[0_4px_14px_rgba(200,90,0,0.45)]">
                      <ArrowUp className="w-6 h-6 sm:w-7 sm:h-7 stroke-[2.7]" />
                    </span>
                  </span>
                </span>

                <span className="font-heritage text-2xl sm:text-[28px] tracking-wide text-[#0A1F44] dark:text-white group-hover:text-[#B84E00] dark:group-hover:text-[#E4C788] transition-colors">
                  {isHi ? 'भेजें' : 'Send'}
                </span>
              </button>
            </div>

            {/* Lower-Right: RECEIVE Royal Indigo & Gold Medallion */}
            <div className="flex justify-end">
              <button
                type="button"
                onClick={() => {
                  clearPreselectedSendFiles();
                  setScreen('receive');
                }}
                className="group inline-flex items-center gap-4 sm:gap-6 cursor-pointer rounded-full pl-4 py-1 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-[#0A1F44]"
              >
                <span className="font-heritage text-2xl sm:text-[28px] tracking-wide text-[#0A1F44] dark:text-white group-hover:text-[#0F2D5E] dark:group-hover:text-[#E4C788] transition-colors">
                  {isHi ? 'प्राप्त करें' : 'Receive'}
                </span>

                <span className="relative w-24 h-24 sm:w-28 sm:h-28 flex items-center justify-center shrink-0">
                  <HeritageMedallionRings variant="receive" />
                  <span className="w-[74px] h-[74px] sm:w-[84px] sm:h-[84px] rounded-full bg-white/90 dark:bg-[#08224D]/90 border border-[#C5A059]/85 flex items-center justify-center shadow-[0_10px_28px_rgba(10,31,68,0.28)] group-hover:scale-105 transition-transform duration-200">
                    <span className="w-12 h-12 sm:w-14 sm:h-14 rounded-full bg-gradient-to-b from-[#0F2D5E] to-[#071836] border border-[#C5A059]/85 text-white flex items-center justify-center shadow-[0_4px_14px_rgba(10,31,68,0.45)]">
                      <ArrowDown className="w-6 h-6 sm:w-7 sm:h-7 stroke-[2.7] text-[#E4C788]" />
                    </span>
                  </span>
                </span>
              </button>
            </div>
          </div>

          {/* Minimal Footer Action */}
          <div className="relative z-10 flex justify-center pt-1">
            <button
              type="button"
              onClick={() => setScreen('transfer-history')}
              className="min-w-[180px] h-11 px-7 rounded-full bg-gradient-to-r from-[#C85A00] via-[#D96B08] to-[#B84E00] hover:brightness-105 active:scale-[0.98] text-white text-sm font-bold inline-flex items-center justify-center gap-2 border border-[#F5D08A]/80 shadow-[0_8px_24px_rgba(200,90,0,0.28)] transition-[transform,filter] duration-150 cursor-pointer"
            >
              <History className="w-4 h-4 text-[#FFE7BA]" />
              <span>{isHi ? 'इतिहास' : 'History'}</span>
            </button>
          </div>
        </div>
      </section>

      {/* Active Transfers (Shown strictly when transfers are actively running or paused) */}
      {activeTransfers.length > 0 && (
        <section className="px-4 sm:px-0 pb-6 space-y-3">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-bold text-[#0A1F44] dark:text-white flex items-center gap-2">
              <Activity className="w-4 h-4 text-[#D96B08] dark:text-[#E4C788]" />
              <span>
                {isHi
                  ? `सक्रिय ट्रांसफ़र (${activeTransfers.length})`
                  : `Active Transfers (${activeTransfers.length})`}
              </span>
            </h2>
            <button
              onClick={() => setScreen('transfer-progress')}
              className="text-xs font-semibold text-[#B84E00] dark:text-[#E4C788] hover:underline whitespace-nowrap cursor-pointer"
            >
              {isHi ? 'सभी देखें' : 'View All'}
            </button>
          </div>
          {activeTransfers.slice(0, 2).map((job) => (
            <div key={job.id} className="space-y-2">
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
              {job.direction === 'send' && (
                <div className="flex justify-end gap-2">
                  {job.status === 'paused' ? (
                    <button
                      onClick={() => void resumeTransfer(job.id)}
                      className="min-h-[40px] px-4 py-2 rounded-full bg-gradient-to-r from-[#C85A00] to-[#B84E00] text-white text-xs font-medium inline-flex items-center gap-1.5 whitespace-nowrap cursor-pointer border border-[#F5D08A]/75"
                    >
                      <Play className="w-3.5 h-3.5" />
                      <span>{isHi ? 'शुरू करें' : 'Resume'}</span>
                    </button>
                  ) : (
                    <button
                      onClick={() => pauseTransfer(job.id)}
                      className="min-h-[40px] px-4 py-2 rounded-full border border-[#C5A059]/45 text-xs font-medium inline-flex items-center gap-1.5 whitespace-nowrap cursor-pointer"
                    >
                      <Pause className="w-3.5 h-3.5" />
                      <span>{isHi ? 'रोकें' : 'Pause'}</span>
                    </button>
                  )}
                </div>
              )}
            </div>
          ))}
        </section>
      )}
    </div>
  );
}
