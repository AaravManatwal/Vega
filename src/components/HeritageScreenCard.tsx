import React from 'react';
import { ArrowLeft } from 'lucide-react';

export interface HeritageScreenCardProps {
  title: string;
  subtitle?: string;
  onBack: () => void;
  backLabel?: string;
  rightAction?: React.ReactNode;
  children: React.ReactNode;
}

export function HeritageScreenCard({
  title,
  subtitle,
  onBack,
  backLabel = 'Back',
  rightAction,
  children,
}: HeritageScreenCardProps) {
  return (
    <div className="max-w-2xl mx-auto">
      <section
        aria-label={title}
        className="relative overflow-hidden rounded-none sm:rounded-[34px] bg-[#FFFDF8] dark:bg-[#0A1F44] bg-gradient-to-b from-[#FFFDF8] via-[#F7F1E2] to-[#EDE2C8] dark:from-[#0A1F44] dark:via-[#07193B] dark:to-[#04122B] text-[#0A1F44] dark:text-white min-h-[100svh] sm:min-h-[640px] shadow-[0_20px_54px_rgba(10,31,68,0.14)] dark:shadow-[0_24px_64px_rgba(6,17,41,0.58)] sm:border sm:border-[#C5A059]/70 dark:sm:border-[#C5A059]/55 flex flex-col px-5 pt-5 pb-8 sm:px-7 sm:pt-7 sm:pb-8 gap-5 bg-rajasthani-jali-light"
      >
        {/* Subtle Rajasthani Jharokha Arch Outline */}
        <svg
          className="absolute inset-0 w-full h-full pointer-events-none"
          viewBox="0 0 800 900"
          preserveAspectRatio="none"
          aria-hidden="true"
        >
          <path
            d="M 24 874 V 116 C 24 72 110 56 225 56 C 315 56 362 36 400 14 C 438 36 485 56 575 56 C 690 56 776 72 776 116 V 874"
            fill="none"
            stroke="#C5A059"
            strokeOpacity="0.28"
            strokeWidth="1.6"
          />
        </svg>

        {/* Minimal Top Row: Back Button + Heritage Title + Optional Action */}
        <div className="relative z-10 flex items-center justify-between gap-3">
          <div className="flex items-center gap-3.5 min-w-0">
            <button
              type="button"
              onClick={onBack}
              aria-label={backLabel}
              className="w-11 h-11 rounded-full bg-white/95 dark:bg-[#0F2752] border border-[#C5A059]/70 text-[#0A1F44] dark:text-[#E4C788] hover:bg-[#0A1F44] hover:text-white dark:hover:bg-[#C85A00] dark:hover:text-white flex items-center justify-center shrink-0 shadow-xs transition-colors cursor-pointer"
            >
              <ArrowLeft className="w-5 h-5" />
            </button>

            <div className="min-w-0">
              <h1 className="font-heritage text-xl sm:text-2xl tracking-wide text-[#0A1F44] dark:text-white leading-tight truncate">
                {title}
              </h1>
              {subtitle && (
                <p className="text-xs sm:text-sm font-medium text-[#7A633C] dark:text-[#93C5FD] truncate">
                  {subtitle}
                </p>
              )}
            </div>
          </div>

          {rightAction && <div className="shrink-0">{rightAction}</div>}
        </div>

        {/* Screen Body */}
        <div className="relative z-10 flex-1 flex flex-col gap-4 min-h-0">{children}</div>
      </section>
    </div>
  );
}
