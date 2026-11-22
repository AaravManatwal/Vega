import React from 'react';
import { motion } from 'motion/react';
import type { DevicePlatform, FileCategory } from '../../types/vega.ts';

// 1. Official VEGA Brand Mark (uses the custom user-provided SVG emblem)
export function VegaLogo({ size = 36, animated = false }: { size?: number; animated?: boolean }) {
  return (
    <img
      src="/assets/aistudio/vega-logo-original_8c38a436.svg"
      width={size}
      height={size}
      alt="Vega Logo"
      draggable={false}
      style={{ width: size, height: size }}
      className={`shrink-0 object-contain select-none rounded-[22%] ${
        animated ? 'transition-transform duration-300' : ''
      }`}
    />
  );
}

// 1b. Rotating Rajasthani Mandala Splash Emblem (16-petal lotus Mandala + counter-rotating star + central VEGA crest)
export function MandalaSplashCrest({ size = 240, logoSize = 84 }: { size?: number; logoSize?: number }) {
  const petalAngles = Array.from({ length: 16 }, (_, i) => i * 22.5);
  const starAngles = Array.from({ length: 8 }, (_, i) => i * 45);

  return (
    <div
      className="relative flex items-center justify-center select-none"
      style={{ width: size, height: size }}
    >
      {/* Ambient Electric Blue & Gold-Leaf glow */}
      <div
        aria-hidden="true"
        className="absolute inset-5 rounded-full bg-[#007AFF]/20 blur-2xl pointer-events-none"
      />
      <div
        aria-hidden="true"
        className="absolute inset-10 rounded-full bg-[#C5A059]/15 blur-xl pointer-events-none"
      />

      {/* Outer 16-Petal Rajasthani Mandala Ring — graceful clockwise rotation */}
      <motion.svg
        width={size}
        height={size}
        viewBox="0 0 260 260"
        fill="none"
        aria-hidden="true"
        className="absolute inset-0"
        animate={{ rotate: 360 }}
        transition={{ repeat: Infinity, duration: 28, ease: 'linear' }}
      >
        <circle cx="130" cy="130" r="122" stroke="#C5A059" strokeOpacity="0.35" strokeWidth="1" strokeDasharray="3 6" />
        <circle cx="130" cy="130" r="110" stroke="#007AFF" strokeOpacity="0.4" strokeWidth="1.2" />
        {petalAngles.map((deg) => (
          <g key={deg} transform={`rotate(${deg} 130 130)`}>
            <path
              d="M130 14 C135 28 139 38 130 48 C121 38 125 28 130 14 Z"
              fill="#C5A059"
              fillOpacity="0.18"
              stroke="#C5A059"
              strokeOpacity="0.72"
              strokeWidth="1.1"
            />
            <circle cx="130" cy="10" r="2" fill="#E4C788" fillOpacity="0.85" />
          </g>
        ))}
      </motion.svg>

      {/* Inner 8-Point Jharokha Star Mandala — graceful counter-clockwise rotation */}
      <motion.svg
        width={size}
        height={size}
        viewBox="0 0 260 260"
        fill="none"
        aria-hidden="true"
        className="absolute inset-0"
        animate={{ rotate: -360 }}
        transition={{ repeat: Infinity, duration: 20, ease: 'linear' }}
      >
        <circle cx="130" cy="130" r="78" stroke="#C5A059" strokeOpacity="0.55" strokeWidth="1.3" />
        <circle cx="130" cy="130" r="66" stroke="#38BDF8" strokeOpacity="0.35" strokeWidth="1" strokeDasharray="4 4" />
        {starAngles.map((deg) => (
          <g key={deg} transform={`rotate(${deg} 130 130)`}>
            <path
              d="M130 48 L138 66 L130 74 L122 66 Z"
              fill="#007AFF"
              fillOpacity="0.28"
              stroke="#C5A059"
              strokeOpacity="0.8"
              strokeWidth="1.1"
            />
          </g>
        ))}
      </motion.svg>

      {/* Central Stationary VEGA Emblem */}
      <div className="relative z-10 rounded-[22px] p-1.5 bg-[#101a35]/95 ring-1 ring-[#C5A059]/65 shadow-[0_0_28px_rgba(47,125,255,0.45)]">
        <VegaLogo size={logoSize} animated />
      </div>
    </div>
  );
}

// 2. VEGA Rajasthani Heritage Splash Illustration (Deep Navy, Electric Blue & Gold-Leaf #C5A059)
export function SplashIllustration() {
  return (
    <svg viewBox="0 0 360 190" fill="none" className="w-full max-w-[340px] h-auto" aria-hidden="true">
      {/* Mandana Gold-Leaf & Electric Blue Concentric Orbits */}
      <circle cx="180" cy="95" r="78" stroke="#C5A059" strokeOpacity="0.32" strokeWidth="1.2" strokeDasharray="4 6" />
      <circle cx="180" cy="95" r="56" stroke="#007AFF" strokeOpacity="0.45" strokeWidth="1.2" />
      <path d="M126 32 C150 22 168 18 180 10 C192 18 210 22 234 32" stroke="#C5A059" strokeOpacity="0.52" strokeWidth="1.4" strokeLinecap="round" />

      {/* Android Phone Node */}
      <rect x="40" y="56" width="54" height="78" rx="13" fill="#0A1F44" stroke="#C5A059" strokeOpacity="0.8" strokeWidth="1.5" />
      <rect x="48" y="66" width="38" height="50" rx="6" fill="#003366" />
      <path d="M67 84V98M62 89L67 84L72 89" stroke="#C5A059" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
      <rect x="61" y="122" width="12" height="3" rx="1.5" fill="#007AFF" />

      {/* Windows PC Node */}
      <rect x="246" y="56" width="76" height="58" rx="10" fill="#0A1F44" stroke="#C5A059" strokeOpacity="0.8" strokeWidth="1.5" />
      <rect x="253" y="63" width="62" height="42" rx="5" fill="#003366" />
      <path d="M284 78V91M279 86L284 91L289 86" stroke="#38BDF8" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M238 120H330L323 128H245L238 120Z" fill="#1E3A5F" />

      {/* High-Speed Bidirectional Electric Blue & Gold-Leaf Data Beams */}
      <motion.path
        d="M100 84C142 58 202 58 240 84"
        stroke="#007AFF"
        strokeWidth="2.8"
        strokeLinecap="round"
        strokeDasharray="8 6"
        animate={{ strokeDashoffset: [0, -28] }}
        transition={{ repeat: Infinity, duration: 1.25, ease: 'linear' }}
      />
      <motion.path
        d="M240 106C202 132 142 132 100 106"
        stroke="#C5A059"
        strokeWidth="2.4"
        strokeLinecap="round"
        strokeDasharray="8 6"
        animate={{ strokeDashoffset: [0, 28] }}
        transition={{ repeat: Infinity, duration: 1.4, ease: 'linear' }}
      />

      {/* Central Royal Mandana V-Shield Crest */}
      <circle cx="180" cy="95" r="25" fill="#0A1F44" stroke="#C5A059" strokeWidth="1.8" />
      <circle cx="180" cy="95" r="20" stroke="#007AFF" strokeOpacity="0.55" strokeWidth="1" strokeDasharray="3 3" />
      <path d="M169 86H175L180 99L177.5 104.5L169 86Z" fill="#FFFFFF" />
      <path d="M180 106L177.5 101L185 85.5H191L183 102.5C182 104.6 181 106 180 106Z" fill="#C5A059" />
    </svg>
  );
}

// 3. Device Illustrations (Android, Windows, Web/Desktop)
export function DeviceVector({ platform, size = 44 }: { platform: DevicePlatform; size?: number }) {
  if (platform === 'android') {
    return (
      <svg width={size} height={size} viewBox="0 0 48 48" fill="none" aria-label="Android Device" className="shrink-0">
        <rect x="13" y="4" width="22" height="40" rx="6" fill="#0A1F44" stroke="#007AFF" strokeWidth="1.8" />
        <rect x="16" y="9" width="16" height="27" rx="2.5" fill="#003366" fillOpacity="0.85" />
        <circle cx="24" cy="40" r="1.6" fill="#66B2FF" />
        <path d="M20 20L24 16L28 20M24 16V27" stroke="#66B2FF" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    );
  }
  if (platform === 'windows') {
    return (
      <svg width={size} height={size} viewBox="0 0 48 48" fill="none" aria-label="Windows Computer" className="shrink-0">
        <rect x="6" y="8" width="36" height="25" rx="5" fill="#0A1F44" stroke="#38BDF8" strokeWidth="1.8" />
        <rect x="9" y="11" width="30" height="19" rx="2" fill="#003366" fillOpacity="0.85" />
        <path d="M4 36H44L41 40H7L4 36Z" fill="#1E3A5F" />
        <rect x="17" y="15" width="6" height="5" fill="#66B2FF" />
        <rect x="25" y="15" width="6" height="5" fill="#66B2FF" />
        <rect x="17" y="21" width="6" height="5" fill="#007AFF" />
        <rect x="25" y="21" width="6" height="5" fill="#007AFF" />
      </svg>
    );
  }
  return (
    <svg width={size} height={size} viewBox="0 0 48 48" fill="none" aria-label="Peer Node" className="shrink-0">
      <rect x="8" y="9" width="32" height="24" rx="5" fill="#0A1F44" stroke="#007AFF" strokeWidth="1.8" />
      <circle cx="24" cy="21" r="6" stroke="#66B2FF" strokeWidth="1.8" />
      <path d="M16 38H32" stroke="#64748B" strokeWidth="2.4" strokeLinecap="round" />
      <path d="M24 33V38" stroke="#64748B" strokeWidth="2.4" />
    </svg>
  );
}

// 4. Connection Illustration
export function P2PConnectionGraphic() {
  return (
    <svg viewBox="0 0 220 64" fill="none" className="w-44 h-12" aria-hidden="true">
      <circle cx="22" cy="32" r="14" fill="#0A1F44" fillOpacity="0.14" stroke="#0A1F44" strokeWidth="1.5" />
      <circle cx="198" cy="32" r="14" fill="#007AFF" fillOpacity="0.14" stroke="#007AFF" strokeWidth="1.5" />
      <path d="M40 32H180" stroke="#007AFF" strokeOpacity="0.5" strokeWidth="2" strokeDasharray="4 4" />
      <rect x="92" y="18" width="36" height="28" rx="8" fill="#0A1F44" stroke="#007AFF" strokeWidth="1.5" />
      <path d="M104 32V28C104 25.8 105.8 24 108 24H112C114.2 24 116 25.8 116 28V32" stroke="#66B2FF" strokeWidth="1.8" />
      <rect x="102" y="31" width="16" height="10" rx="2" fill="#007AFF" />
    </svg>
  );
}

// 5. Custom File Category Icons
export function CategoryVectorIcon({ category, size = 24 }: { category: FileCategory; size?: number }) {
  const palette: Record<FileCategory, { bg: string }> = {
    images: { bg: '#007AFF' },
    videos: { bg: '#003366' },
    audio: { bg: '#0284C7' },
    documents: { bg: '#0A1F44' },
    downloads: { bg: '#0369A1' },
    archives: { bg: '#334155' },
    applications: { bg: '#1D4ED8' },
    other: { bg: '#475569' },
  };
  const colors = palette[category];

  return (
    <svg width={size} height={size} viewBox="0 0 28 28" fill="none" aria-hidden="true" className="shrink-0">
      <rect x="2" y="2" width="24" height="24" rx="8" fill={colors.bg} fillOpacity="0.14" stroke={colors.bg} strokeOpacity="0.38" />
      {category === 'images' && (
        <>
          <rect x="7" y="8" width="14" height="12" rx="2" stroke={colors.bg} strokeWidth="1.6" />
          <circle cx="11" cy="12" r="1.4" fill={colors.bg} />
          <path d="M8 18L12.5 14L15.5 16.5L18 14L20.5 18" stroke={colors.bg} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
        </>
      )}
      {category === 'videos' && (
        <>
          <rect x="6.5" y="8" width="15" height="12" rx="2" stroke={colors.bg} strokeWidth="1.6" />
          <path d="M12.5 11.5L17 14L12.5 16.5V11.5Z" fill={colors.bg} />
        </>
      )}
      {category === 'audio' && (
        <path d="M11 18V10L19 8.5V16.5M11 18C11 19.1 10.1 20 9 20C7.9 20 7 19.1 7 18C7 16.9 7.9 16 9 16C10.1 16 11 16.9 11 18ZM19 16.5C19 17.6 18.1 18.5 17 18.5C15.9 18.5 15 17.6 15 16.5C15 15.4 15.9 14.5 17 14.5C18.1 14.5 19 15.4 19 16.5Z" stroke={colors.bg} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
      )}
      {(category === 'documents' || category === 'downloads' || category === 'other') && (
        <>
          <path d="M9 7H15.5L19 10.5V21H9V7Z" stroke={colors.bg} strokeWidth="1.6" strokeLinejoin="round" />
          <path d="M11.5 13.5H16.5M11.5 16.5H15" stroke={colors.bg} strokeWidth="1.5" strokeLinecap="round" />
        </>
      )}
      {category === 'archives' && (
        <>
          <rect x="7" y="7" width="14" height="14" rx="2" stroke={colors.bg} strokeWidth="1.6" />
          <path d="M14 7V21M12 10H16M12 13.5H16M12 17H16" stroke={colors.bg} strokeWidth="1.5" strokeLinecap="round" />
        </>
      )}
      {category === 'applications' && (
        <>
          <rect x="7" y="7" width="6" height="6" rx="1.5" stroke={colors.bg} strokeWidth="1.6" />
          <rect x="15" y="7" width="6" height="6" rx="1.5" stroke={colors.bg} strokeWidth="1.6" />
          <rect x="7" y="15" width="6" height="6" rx="1.5" stroke={colors.bg} strokeWidth="1.6" />
          <path d="M18 15V21M15 18H21" stroke={colors.bg} strokeWidth="1.6" strokeLinecap="round" />
        </>
      )}
    </svg>
  );
}

// 6. Storage Ring Gauge Widget (Inspired by Reference Photo #4)
export function StorageDonutRing({
  usedBytes,
  quotaBytes,
  size = 92,
  onDark = false,
}: {
  usedBytes: number;
  quotaBytes: number;
  size?: number;
  onDark?: boolean;
}) {
  const pct = quotaBytes > 0 ? Math.min(100, Math.max(0.5, (usedBytes / quotaBytes) * 100)) : 0;
  const displayPct = quotaBytes > 0 ? ((usedBytes / quotaBytes) * 100) : 0;
  const radius = 36;
  const circumference = 2 * Math.PI * radius;
  const dashOffset = circumference - (pct / 100) * circumference;

  return (
    <div className="relative inline-flex items-center justify-center shrink-0" style={{ width: size, height: size }}>
      <svg width={size} height={size} viewBox="0 0 92 92" className="-rotate-90">
        <circle
          cx="46"
          cy="46"
          r={radius}
          fill="none"
          stroke="currentColor"
          strokeWidth="8"
          className={onDark ? 'text-[#1B3154]' : 'text-[#DCE3EC] dark:text-[#1B3154]'}
        />
        <circle
          cx="46"
          cy="46"
          r={radius}
          fill="none"
          stroke="url(#smp-ring-grad)"
          strokeWidth="8"
          strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={dashOffset}
          className="transition-all duration-300"
        />
        <defs>
          <linearGradient id="smp-ring-grad" x1="0" y1="0" x2="92" y2="92" gradientUnits="userSpaceOnUse">
            <stop offset="0%" stopColor="#007AFF" />
            <stop offset="60%" stopColor="#38BDF8" />
            <stop offset="100%" stopColor="#66B2FF" />
          </linearGradient>
        </defs>
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
        <span
          className={`text-sm font-bold font-mono tabular-nums ${
            onDark ? 'text-white' : 'text-[#0A1F44] dark:text-white'
          }`}
        >
          {displayPct < 1 && displayPct > 0 ? '<1%' : `${Math.round(displayPct)}%`}
        </span>
      </div>
    </div>
  );
}

// 7. Empty State Illustration
export function EmptyVaultIllustration() {
  return (
    <svg width="88" height="88" viewBox="0 0 88 88" fill="none" aria-hidden="true">
      <circle cx="44" cy="44" r="36" fill="#007AFF" fillOpacity="0.08" stroke="#007AFF" strokeOpacity="0.3" strokeDasharray="4 4" />
      <path d="M24 32C24 29.8 25.8 28 28 28H37L41 32H60C62.2 32 64 33.8 64 36V56C64 58.2 62.2 60 60 60H28C25.8 60 24 58.2 24 56V32Z" stroke="#0A1F44" strokeWidth="2" />
      <path d="M37 46H51" stroke="#007AFF" strokeWidth="2" strokeLinecap="round" />
    </svg>
  );
}

// 8. Success Illustration
export function VerifiedSuccessIllustration() {
  return (
    <svg width="72" height="72" viewBox="0 0 72 72" fill="none" aria-hidden="true">
      <circle cx="36" cy="36" r="30" fill="#15803D" fillOpacity="0.12" stroke="#15803D" strokeWidth="2" />
      <path d="M24 36.5L32 44.5L48.5 28" stroke="#15803D" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

// 9. Error & Loading Graphics
export function RecoveryErrorIllustration() {
  return (
    <svg width="72" height="72" viewBox="0 0 72 72" fill="none" aria-hidden="true">
      <circle cx="36" cy="36" r="30" fill="#DC2626" fillOpacity="0.12" stroke="#DC2626" strokeWidth="2" />
      <path d="M36 24V39" stroke="#DC2626" strokeWidth="3" strokeLinecap="round" />
      <circle cx="36" cy="47" r="2.2" fill="#DC2626" />
    </svg>
  );
}

export function OrbitalSyncLoader({ size = 36 }: { size?: number }) {
  return (
    <motion.svg
      width={size}
      height={size}
      viewBox="0 0 40 40"
      fill="none"
      animate={{ rotate: 360 }}
      transition={{ repeat: Infinity, duration: 1.4, ease: 'linear' }}
      aria-label="Syncing"
    >
      <circle cx="20" cy="20" r="15" stroke="#0A1F44" strokeOpacity="0.22" strokeWidth="3" />
      <path d="M20 5C28.2843 5 35 11.7157 35 20" stroke="#007AFF" strokeWidth="3" strokeLinecap="round" />
    </motion.svg>
  );
}
