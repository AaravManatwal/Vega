import React, { useState } from 'react';
import { Check } from 'lucide-react';
import { useVega } from '../context/VegaContext.tsx';
import { HeritageScreenCard } from './HeritageScreenCard.tsx';

const SETTINGS_COPY = {
  en: {
    title: 'Settings',
    subtitle: 'Language, theme & sharing preferences',
    languageLabel: 'Language',
    themeLabel: 'Theme',
    themeLight: 'Light',
    themeDark: 'Dark',
    deviceNameLabel: 'Device Name',
    saveBtn: 'Save',
    savedMsg: 'Saved',
    trustedAutoLabel: 'Ask Before Receiving Files',
    trustedAutoDesc: 'When turned off, saved devices can send you files directly.',
    notifLabel: 'Alerts',
    notifDesc: 'Show an alert when a file arrives or finishes.',
    deviceNameError: 'Enter a device name (2–40 characters).',
  },
  hi: {
    title: 'सेटिंग्स',
    subtitle: 'भाषा, थीम और शेयरिंग विकल्प',
    languageLabel: 'भाषा',
    themeLabel: 'थीम',
    themeLight: 'लाइट',
    themeDark: 'डार्क',
    deviceNameLabel: 'डिवाइस का नाम',
    saveBtn: 'सहेजें',
    savedMsg: 'सहेजा गया',
    trustedAutoLabel: 'फ़ाइल लेने से पहले अनुमति मांगें',
    trustedAutoDesc: 'बंद रहने पर, जुड़े डिवाइस से फ़ाइलें सीधे प्राप्त होंगी।',
    notifLabel: 'सूचनाएं',
    notifDesc: 'फ़ाइल आने या ट्रांसफ़र पूरा होने पर सूचना दिखाएं।',
    deviceNameError: 'कृपया डिवाइस का नाम दर्ज करें (2–40 अक्षर)।',
  },
} as const;

export function Settings() {
  const { settings, updateSettings, setScreen } = useVega();
  const copy = SETTINGS_COPY[settings.language];
  const isHi = settings.language === 'hi';

  const [nameDraft, setNameDraft] = useState(settings.deviceName);
  const [nameError, setNameError] = useState<string | null>(null);
  const [savedNotice, setSavedNotice] = useState<'name' | null>(null);

  return (
    <HeritageScreenCard
      title={copy.title}
      subtitle={copy.subtitle}
      onBack={() => setScreen('dashboard')}
      backLabel={isHi ? 'वापस जाएं' : 'Back'}
    >
      <div className="rounded-[24px] border border-[#C5A059]/50 dark:border-[#C5A059]/35 bg-white/90 dark:bg-[#0D2148]/90 p-5 space-y-5 shadow-xs">
        {/* Device Name */}
        <div className="space-y-2">
          <label className="block text-xs font-semibold text-[#7A633C] dark:text-[#93C5FD]">
            {copy.deviceNameLabel}
          </label>
          <div className="flex gap-2">
            <input
              type="text"
              maxLength={40}
              value={nameDraft}
              onChange={(e) => {
                setNameDraft(e.target.value);
                if (nameError) setNameError(null);
              }}
              className="flex-1 min-h-[40px] px-3.5 py-2 rounded-full border border-[#C5A059]/45 bg-[#FAF6EC] dark:bg-[#06132B] text-sm text-[#0A1F44] dark:text-white focus:outline-none focus:border-[#D96B08]"
            />
            <button
              type="button"
              onClick={async () => {
                const cleaned = nameDraft.trim();
                if (cleaned.length < 2 || cleaned.length > 40) {
                  setNameError(copy.deviceNameError);
                  return;
                }
                setNameError(null);
                await updateSettings({ deviceName: cleaned });
                setNameDraft(cleaned);
                setSavedNotice('name');
                setTimeout(() => setSavedNotice(null), 1800);
              }}
              className="min-h-[40px] px-4 py-2 rounded-full bg-gradient-to-r from-[#C85A00] to-[#B84E00] border border-[#F5D08A]/75 text-white text-xs font-semibold inline-flex items-center gap-1.5 whitespace-nowrap cursor-pointer"
            >
              {savedNotice === 'name' && <Check className="w-3.5 h-3.5" />}
              <span>{savedNotice === 'name' ? copy.savedMsg : copy.saveBtn}</span>
            </button>
          </div>
          {nameError && <p className="text-xs text-red-600 dark:text-red-400">{nameError}</p>}
        </div>

        {/* Language & Theme */}
        <div className="pt-4 border-t border-[#C5A059]/25 dark:border-[#1B3154] grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="space-y-2">
            <label className="block text-xs font-semibold text-[#7A633C] dark:text-[#93C5FD]">
              {copy.languageLabel}
            </label>
            <div className="grid grid-cols-2 gap-2">
              <button
                type="button"
                onClick={() => void updateSettings({ language: 'en' })}
                className={`min-h-[40px] py-2 px-3 rounded-full border text-xs font-semibold transition-colors cursor-pointer ${
                  settings.language === 'en'
                    ? 'bg-gradient-to-r from-[#D96B08] to-[#B84E00] border-[#F5D08A]/80 text-white shadow-xs'
                    : 'border-[#C5A059]/45 bg-[#FAF6EC] dark:bg-[#06132B] text-[#0A1F44] dark:text-[#DBEAFE] hover:border-[#D96B08]'
                }`}
              >
                English
              </button>
              <button
                type="button"
                onClick={() => void updateSettings({ language: 'hi' })}
                className={`min-h-[40px] py-2 px-3 rounded-full border text-xs font-semibold transition-colors cursor-pointer ${
                  settings.language === 'hi'
                    ? 'bg-gradient-to-r from-[#D96B08] to-[#B84E00] border-[#F5D08A]/80 text-white shadow-xs'
                    : 'border-[#C5A059]/45 bg-[#FAF6EC] dark:bg-[#06132B] text-[#0A1F44] dark:text-[#DBEAFE] hover:border-[#D96B08]'
                }`}
              >
                हिन्दी
              </button>
            </div>
          </div>

          <div className="space-y-2">
            <label className="block text-xs font-semibold text-[#7A633C] dark:text-[#93C5FD]">
              {copy.themeLabel}
            </label>
            <div className="grid grid-cols-2 gap-2">
              <button
                type="button"
                onClick={() => void updateSettings({ theme: 'light' })}
                className={`min-h-[40px] py-2 px-3 rounded-full border text-xs font-semibold transition-colors cursor-pointer ${
                  settings.theme === 'light'
                    ? 'bg-gradient-to-r from-[#D96B08] to-[#B84E00] border-[#F5D08A]/80 text-white shadow-xs'
                    : 'border-[#C5A059]/45 bg-[#FAF6EC] dark:bg-[#06132B] text-[#0A1F44] dark:text-[#DBEAFE] hover:border-[#D96B08]'
                }`}
              >
                {copy.themeLight}
              </button>
              <button
                type="button"
                onClick={() => void updateSettings({ theme: 'dark' })}
                className={`min-h-[40px] py-2 px-3 rounded-full border text-xs font-semibold transition-colors cursor-pointer ${
                  settings.theme === 'dark'
                    ? 'bg-gradient-to-r from-[#D96B08] to-[#B84E00] border-[#F5D08A]/80 text-white shadow-xs'
                    : 'border-[#C5A059]/45 bg-[#FAF6EC] dark:bg-[#06132B] text-[#0A1F44] dark:text-[#DBEAFE] hover:border-[#D96B08]'
                }`}
              >
                {copy.themeDark}
              </button>
            </div>
          </div>
        </div>

        {/* Simple Toggles */}
        <div className="pt-4 border-t border-[#C5A059]/25 dark:border-[#1B3154] space-y-3.5">
          <label className="flex items-center justify-between gap-4 py-1 cursor-pointer">
            <div>
              <p className="text-sm font-medium text-[#0A1F44] dark:text-white">{copy.trustedAutoLabel}</p>
              <p className="text-xs text-[#6B5A3E] dark:text-[#93C5FD]">{copy.trustedAutoDesc}</p>
            </div>
            <input
              type="checkbox"
              checked={settings.requireApprovalForKnown}
              onChange={(e) => void updateSettings({ requireApprovalForKnown: e.target.checked })}
              className="w-5 h-5 accent-[#D96B08] shrink-0"
            />
          </label>

          <label className="flex items-center justify-between gap-4 py-1 cursor-pointer">
            <div>
              <p className="text-sm font-medium text-[#0A1F44] dark:text-white">{copy.notifLabel}</p>
              <p className="text-xs text-[#6B5A3E] dark:text-[#93C5FD]">{copy.notifDesc}</p>
            </div>
            <input
              type="checkbox"
              checked={settings.enableNotifications}
              onChange={(e) => void updateSettings({ enableNotifications: e.target.checked })}
              className="w-5 h-5 accent-[#D96B08] shrink-0"
            />
          </label>
        </div>
      </div>
    </HeritageScreenCard>
  );
}
