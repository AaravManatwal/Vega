import React, { useState } from 'react';
import { Download, Share, X } from 'lucide-react';
import { useVega } from '../context/VegaContext.tsx';
import { usePWAInstall } from '../hooks/usePWAInstall.ts';

interface PWAInstallButtonProps {
  compact?: boolean;
}

export const PWAInstallButton: React.FC<PWAInstallButtonProps> = ({ compact = false }) => {
  const { isInstallable, isInstalled, isIOS, install } = usePWAInstall();
  const { settings, showToast } = useVega();
  const [showIOSGuide, setShowIOSGuide] = useState(false);

  const isHi = settings.language === 'hi';

  if (isInstalled) {
    return null;
  }

  if (isInstallable) {
    return (
      <button
        type="button"
        onClick={async () => {
          const accepted = await install();
          if (accepted) {
            showToast({
              variant: 'success',
              title: isHi ? 'वेग इंस्टॉल हो गया' : 'Vega Installed',
              message: isHi
                ? 'अब आप वेग को सीधे होम स्क्रीन या डेस्कटॉप से ऑफ़लाइन खोल सकते हैं।'
                : 'You can now launch Vega directly as a standalone offline app.',
            });
          }
        }}
        className={`rounded-xl border border-[#C5A059]/60 bg-white/90 dark:bg-[#0A1F44]/80 text-[#B84E00] dark:text-[#E4C788] hover:bg-[#FAF6EC] dark:hover:bg-[#003366] font-medium inline-flex items-center gap-1.5 whitespace-nowrap shrink-0 cursor-pointer transition-colors ${
          compact ? 'px-2.5 py-1.5 text-xs' : 'px-3.5 py-2 text-xs'
        }`}
      >
        <Download className="w-3.5 h-3.5 shrink-0" />
        <span>{isHi ? 'ऐप इंस्टॉल करें' : 'Install App'}</span>
      </button>
    );
  }

  if (isIOS) {
    return (
      <>
        <button
          type="button"
          onClick={() => setShowIOSGuide(true)}
          className={`rounded-xl border border-[#C5A059]/60 bg-white/90 dark:bg-[#0A1F44]/80 text-[#0A1F44] dark:text-[#E4C788] hover:bg-[#FAF6EC] dark:hover:bg-[#003366]/65 font-medium inline-flex items-center gap-1.5 whitespace-nowrap shrink-0 cursor-pointer transition-colors ${
            compact ? 'px-2.5 py-1.5 text-xs' : 'px-3.5 py-2 text-xs'
          }`}
        >
          <Share className="w-3.5 h-3.5 shrink-0 text-[#D96B08] dark:text-[#E4C788]" />
          <span>{isHi ? 'होम स्क्रीन पर जोड़ें' : 'Install App'}</span>
        </button>

        {showIOSGuide && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
            <div className="w-full max-w-sm rounded-[24px] border border-[#C5A059]/60 bg-[#FFFDF8] dark:bg-[#0A1F44] p-6 shadow-xl space-y-4">
              <div className="flex items-center justify-between gap-2">
                <h3 className="text-base font-bold text-[#0A1F44] dark:text-white font-heritage">
                  {isHi ? 'iPhone / iPad पर इंस्टॉल करें' : 'Install on iPhone / iPad'}
                </h3>
                  <button
                    type="button"
                    onClick={() => setShowIOSGuide(false)}
                    aria-label="Close guide"
                    className="p-1.5 rounded-lg text-[#6B5A3E] hover:text-[#0A1F44] dark:text-[#93C5FD] dark:hover:text-white cursor-pointer"
                  >
                    <X className="w-4 h-4" />
                  </button>
                </div>
                <ol className="text-sm text-[#5B4D38] dark:text-[#DBEAFE] space-y-2 list-decimal list-inside">
                <li>
                  {isHi ? (
                    <>Safari टूलबार में <strong>Share</strong> बटन दबाएं।</>
                  ) : (
                    <>Tap the <strong>Share</strong> button in the Safari toolbar.</>
                  )}
                </li>
                <li>
                  {isHi ? (
                    <>नीचे स्क्रॉल करके <strong>Add to Home Screen</strong> चुनें।</>
                  ) : (
                    <>Scroll down and tap <strong>Add to Home Screen</strong>.</>
                  )}
                </li>
              </ol>
              <button
                type="button"
                onClick={() => setShowIOSGuide(false)}
                className="w-full py-2.5 rounded-full bg-gradient-to-r from-[#C85A00] to-[#B84E00] border border-[#F5D08A]/75 text-white text-sm font-semibold cursor-pointer"
              >
                {isHi ? 'बंद करें' : 'Close'}
              </button>
            </div>
          </div>
        )}
      </>
    );
  }

  return null;
};
