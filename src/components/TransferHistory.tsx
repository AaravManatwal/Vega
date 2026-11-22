import React, { useEffect, useMemo, useState } from 'react';
import { RotateCcw, Search, ShieldCheck, Trash2 } from 'lucide-react';
import { useVega } from '../context/VegaContext.tsx';
import { formatBytes, formatDuration } from '../lib/formatters.ts';
import { offlineDb } from '../lib/offlineDb.ts';
import type { TransferHistoryRecord } from '../types/vega.ts';
import { CategoryVectorIcon } from './graphics/VegaGraphics.tsx';
import { HeritageScreenCard } from './HeritageScreenCard.tsx';

const LOCAL_STORAGE_HISTORY_KEY = 'vega_transfer_history';

export function TransferHistory() {
  const {
    history: contextHistory,
    localFiles,
    queuePreselectedSendFiles,
    showToast,
    deleteHistoryRecords,
    clearAllHistory,
    setScreen,
    settings,
  } = useVega();

  const [localHistory, setLocalHistory] = useState<TransferHistoryRecord[]>([]);
  const [search, setSearch] = useState('');
  const [directionFilter, setDirectionFilter] = useState<'all' | 'send' | 'receive'>('all');
  const [confirmClearAll, setConfirmClearAll] = useState(false);

  const isHi = settings.language === 'hi';

  useEffect(() => {
    try {
      const raw = localStorage.getItem(LOCAL_STORAGE_HISTORY_KEY);
      const parsed = raw ? (JSON.parse(raw) as TransferHistoryRecord[]) : [];
      const merged = new Map<string, TransferHistoryRecord>();
      for (const item of [...(Array.isArray(parsed) ? parsed : []), ...contextHistory]) {
        merged.set(item.id, item);
      }
      const next = Array.from(merged.values());
      setLocalHistory(next);
      localStorage.setItem(LOCAL_STORAGE_HISTORY_KEY, JSON.stringify(next));
    } catch {
      setLocalHistory(contextHistory);
    }
  }, [contextHistory]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return localHistory
      .filter((h) => (directionFilter === 'all' ? true : h.direction === directionFilter))
      .filter((h) =>
        !q
          ? true
          : h.fileName.toLowerCase().includes(q) ||
            h.senderName.toLowerCase().includes(q) ||
            h.receiverName.toLowerCase().includes(q)
      )
      .sort((a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime());
  }, [directionFilter, localHistory, search]);

  const handleDeleteRecord = async (id: string) => {
    await deleteHistoryRecords([id]);
    setLocalHistory((prev) => {
      const next = prev.filter((item) => item.id !== id);
      try {
        localStorage.setItem(LOCAL_STORAGE_HISTORY_KEY, JSON.stringify(next));
      } catch {
        // ignore
      }
      return next;
    });
  };

  const handleClearAll = async () => {
    await clearAllHistory();
    setLocalHistory([]);
    try {
      localStorage.removeItem(LOCAL_STORAGE_HISTORY_KEY);
    } catch {
      // ignore
    }
    setConfirmClearAll(false);
  };

  const handleSendAgain = async (item: TransferHistoryRecord) => {
    const match =
      localFiles.find((f) => f.name === item.fileName && f.size === item.fileSize) ||
      localFiles.find((f) => f.name === item.fileName);
    if (!match) {
      showToast({
        variant: 'warning',
        title: isHi ? 'फ़ाइल उपलब्ध नहीं' : 'File not available',
        message: isHi
          ? `"${item.fileName}" डिवाइस पर नहीं मिली। भेजने के लिए फ़ाइल दोबारा चुनें।`
          : `"${item.fileName}" is no longer saved here. Please select it again to send.`,
      });
      return;
    }

    const blob = await offlineDb.getFileBlob(match.id);
    if (!blob) {
      showToast({
        variant: 'warning',
        title: isHi ? 'फ़ाइल उपलब्ध नहीं' : 'File unavailable',
        message: isHi
          ? `"${item.fileName}" अब उपलब्ध नहीं है।`
          : `"${item.fileName}" is no longer available.`,
      });
      return;
    }

    const file = new File([blob], match.name, {
      type: match.mimeType || 'application/octet-stream',
      lastModified: new Date(match.modifiedAt).getTime() || Date.now(),
    });
    queuePreselectedSendFiles([{ file, relativePath: match.relativePath || match.name }]);
    showToast({
      variant: 'info',
      title: isHi ? 'भेजने के लिए तैयार' : 'Ready to Send',
      message: isHi
        ? `"${match.name}" भेजने के लिए चुन ली गई है।`
        : `"${match.name}" is ready to send.`,
    });
    setScreen('send');
  };

  const directionTabs: Array<{ id: 'all' | 'send' | 'receive'; label: string }> = [
    { id: 'all', label: isHi ? 'सभी' : 'All' },
    { id: 'send', label: isHi ? 'भेजी गई' : 'Sent' },
    { id: 'receive', label: isHi ? 'प्राप्त' : 'Received' },
  ];

  return (
    <HeritageScreenCard
      title={isHi ? 'इतिहास' : 'History'}
      subtitle={isHi ? 'भेजे और प्राप्त किए गए ट्रांसफ़र' : 'Sent & received transfers'}
      onBack={() => setScreen('dashboard')}
      backLabel={isHi ? 'वापस जाएं' : 'Back'}
      rightAction={
        localHistory.length > 0 ? (
          confirmClearAll ? (
            <div className="flex items-center gap-1.5">
              <button
                type="button"
                onClick={() => void handleClearAll()}
                className="min-h-[36px] px-3 py-1.5 rounded-full bg-red-600 text-white text-xs font-semibold whitespace-nowrap cursor-pointer"
              >
                {isHi ? 'पुष्टि करें' : 'Confirm'}
              </button>
              <button
                type="button"
                onClick={() => setConfirmClearAll(false)}
                className="min-h-[36px] px-3 py-1.5 rounded-full border border-[#C5A059]/55 text-xs text-[#0A1F44] dark:text-[#DBEAFE] whitespace-nowrap cursor-pointer"
              >
                {isHi ? 'रद्द' : 'Cancel'}
              </button>
            </div>
          ) : (
            <button
              type="button"
              onClick={() => setConfirmClearAll(true)}
              className="min-h-[38px] px-3.5 py-1.5 rounded-full border border-red-300 dark:border-red-900/60 bg-white/90 dark:bg-[#0D2148] text-red-600 dark:text-red-400 text-xs font-semibold inline-flex items-center gap-1.5 whitespace-nowrap cursor-pointer"
            >
              <Trash2 className="w-3.5 h-3.5" />
              <span>{isHi ? 'साफ़ करें' : 'Clear'}</span>
            </button>
          )
        ) : undefined
      }
    >
      {/* Search & Filter */}
      <div className="rounded-2xl border border-[#C5A059]/45 dark:border-[#C5A059]/30 bg-white/90 dark:bg-[#0D2148]/90 p-3 flex flex-col sm:flex-row sm:items-center justify-between gap-2.5">
        <div className="relative flex-1">
          <Search className="w-4 h-4 text-[#7A633C] dark:text-[#93C5FD] absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder={isHi ? 'फ़ाइल या डिवाइस खोजें...' : 'Search file or device...'}
            className="w-full min-h-[38px] pl-9 pr-3 py-1.5 rounded-xl border border-[#C5A059]/40 bg-[#FAF6EC] dark:bg-[#06132B] text-sm text-[#0A1F44] dark:text-white focus:outline-none focus:border-[#D96B08]"
          />
        </div>

        <div className="flex items-center gap-1.5">
          {directionTabs.map((tab) => (
            <button
              key={tab.id}
              type="button"
              onClick={() => setDirectionFilter(tab.id)}
              className={`min-h-[36px] px-3.5 py-1.5 rounded-full text-xs font-semibold cursor-pointer whitespace-nowrap border transition-colors ${
                directionFilter === tab.id
                  ? 'bg-gradient-to-r from-[#D96B08] to-[#B84E00] border-[#F5D08A]/80 text-white'
                  : 'border-[#C5A059]/45 bg-[#FAF6EC] dark:bg-[#091836] text-[#5B4D38] dark:text-[#DBEAFE] hover:border-[#D96B08]'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {/* History List */}
      <div className="flex-1 rounded-[24px] border border-[#C5A059]/45 dark:border-[#C5A059]/30 bg-white/90 dark:bg-[#0D2148]/90 overflow-hidden">
        {filtered.length === 0 ? (
          <div className="py-14 text-center space-y-2 px-6">
            <ShieldCheck className="w-9 h-9 text-[#D96B08] dark:text-[#E4C788] mx-auto" />
            <p className="text-sm font-semibold text-[#0A1F44] dark:text-white">
              {isHi ? 'कोई ट्रांसफ़र रिकॉर्ड नहीं मिला' : 'No transfer records yet'}
            </p>
            <p className="text-xs text-[#6B5A3E] dark:text-[#93C5FD]">
              {isHi
                ? 'फ़ाइल भेजने या प्राप्त करने के बाद सभी रिकॉर्ड यहां दिखेंगे।'
                : 'Sent and received files appear here automatically.'}
            </p>
          </div>
        ) : (
          <div className="divide-y divide-[#C5A059]/25 dark:divide-[#1B3154]">
            {filtered.map((item) => (
              <div
                key={item.id}
                className="p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3 hover:bg-[#FAF6EC]/70 dark:hover:bg-[#091836]/60 transition-colors"
              >
                <div className="flex items-center gap-3 min-w-0">
                  <CategoryVectorIcon category={item.fileCategory} size={36} />
                  <div className="min-w-0">
                    <p className="text-sm font-semibold text-[#0A1F44] dark:text-white truncate">
                      {item.fileName}
                    </p>
                    <p className="text-xs text-[#6B5A3E] dark:text-[#93C5FD] truncate">
                      {item.senderName} → {item.receiverName} · {formatBytes(item.fileSize)} ·{' '}
                      {formatDuration(item.durationMs)}
                    </p>
                  </div>
                </div>

                <div className="flex items-center justify-between sm:justify-end gap-3 shrink-0">
                  <div className="text-left sm:text-right">
                    <span
                      className={`text-xs font-semibold ${
                        item.status === 'completed'
                          ? 'text-emerald-600 dark:text-emerald-400'
                          : 'text-amber-700 dark:text-[#F59E0B] capitalize'
                      }`}
                    >
                      {item.status === 'completed'
                        ? isHi
                          ? 'पूर्ण'
                          : 'Completed'
                        : item.status}
                    </span>
                    <p className="text-[11px] font-mono tabular-nums text-[#6B5A3E] dark:text-[#93C5FD]">
                      {new Date(item.startedAt).toLocaleDateString()}
                    </p>
                  </div>

                  <div className="flex items-center gap-1.5">
                    <button
                      type="button"
                      onClick={() => void handleSendAgain(item)}
                      className="min-h-[34px] px-3 py-1 rounded-full border border-[#C5A059]/50 bg-[#FAF6EC] dark:bg-[#091836] text-xs font-semibold text-[#B84E00] dark:text-[#E4C788] hover:border-[#D96B08] inline-flex items-center gap-1 whitespace-nowrap cursor-pointer"
                    >
                      <RotateCcw className="w-3 h-3" />
                      <span>{isHi ? 'पुनः भेजें' : 'Send Again'}</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => void handleDeleteRecord(item.id)}
                      aria-label={`Delete ${item.fileName}`}
                      className="min-h-[34px] min-w-[34px] flex items-center justify-center rounded-full text-[#6B5A3E] dark:text-[#93C5FD] hover:text-red-500 cursor-pointer"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </HeritageScreenCard>
  );
}
