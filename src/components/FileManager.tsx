import React, { useMemo, useRef, useState } from 'react';
import {
  Check,
  CheckSquare,
  Download,
  Search,
  Send,
  Square,
  Trash2,
  Upload,
} from 'lucide-react';
import { useVega } from '../context/VegaContext.tsx';
import { formatBytes } from '../lib/formatters.ts';
import { offlineDb } from '../lib/offlineDb.ts';
import type { FileCategory } from '../types/vega.ts';
import { CategoryVectorIcon, EmptyVaultIllustration } from './graphics/VegaGraphics.tsx';
import { HeritageScreenCard } from './HeritageScreenCard.tsx';

const FILE_CATEGORIES: Array<{ id: 'all' | FileCategory; labelEn: string; labelHi: string }> = [
  { id: 'all', labelEn: 'All', labelHi: 'सभी' },
  { id: 'images', labelEn: 'Photos', labelHi: 'फ़ोटो' },
  { id: 'videos', labelEn: 'Videos', labelHi: 'वीडियो' },
  { id: 'documents', labelEn: 'Documents', labelHi: 'दस्तावेज़' },
  { id: 'audio', labelEn: 'Audio', labelHi: 'ऑडियो' },
  { id: 'other', labelEn: 'Other', labelHi: 'अन्य' },
];

export function FileManager() {
  const {
    localFiles,
    addFilesToVault,
    deleteLocalFile,
    downloadLocalFile,
    peers,
    startFileTransfer,
    queuePreselectedSendFiles,
    setScreen,
    settings,
    fileManagerCategory: category,
    setFileManagerCategory: setCategory,
  } = useVega();

  const [search, setSearch] = useState('');
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [confirmDelete, setConfirmDelete] = useState(false);

  const uploadRef = useRef<HTMLInputElement | null>(null);
  const isHi = settings.language === 'hi';

  const filteredFiles = useMemo(() => {
    const q = search.trim().toLowerCase();
    return localFiles
      .filter((f) => {
        if (category === 'all') return true;
        if (category === 'other') {
          return !['images', 'videos', 'documents', 'audio'].includes(f.category);
        }
        return f.category === category;
      })
      .filter((f) =>
        !q ? true : f.name.toLowerCase().includes(q) || f.category.toLowerCase().includes(q)
      )
      .sort((a, b) => new Date(b.modifiedAt).getTime() - new Date(a.modifiedAt).getTime());
  }, [category, localFiles, search]);

  const categoryCounts = useMemo(() => {
    const counts: Record<string, number> = { all: localFiles.length, other: 0 };
    for (const f of localFiles) {
      if (['images', 'videos', 'documents', 'audio'].includes(f.category)) {
        counts[f.category] = (counts[f.category] || 0) + 1;
      } else {
        counts.other = (counts.other || 0) + 1;
      }
    }
    return counts;
  }, [localFiles]);

  const allSelected =
    filteredFiles.length > 0 && filteredFiles.every((f) => selectedIds.has(f.id));

  const toggleSelectAll = () => {
    if (allSelected) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(filteredFiles.map((f) => f.id)));
    }
  };

  const toggleSelect = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const handleShareSelected = async () => {
    const itemsToSend: Array<{ file: File; relativePath: string }> = [];
    for (const id of selectedIds) {
      const meta = localFiles.find((f) => f.id === id);
      const blob = await offlineDb.getFileBlob(id);
      if (meta && blob) {
        const fileObj = new File([blob], meta.name, { type: meta.mimeType });
        itemsToSend.push({ file: fileObj, relativePath: meta.relativePath });
      }
    }
    if (itemsToSend.length === 0) return;

    const targetPeer = peers[0];
    if (!targetPeer) {
      queuePreselectedSendFiles(itemsToSend);
      setScreen('receive');
      return;
    }
    await startFileTransfer(itemsToSend, targetPeer);
  };

  const handleDeleteSelected = async () => {
    for (const id of selectedIds) {
      await deleteLocalFile(id);
    }
    setSelectedIds(new Set());
    setConfirmDelete(false);
  };

  return (
    <HeritageScreenCard
      title={isHi ? 'फ़ाइलें' : 'Files'}
      subtitle={isHi ? 'सहेजी और प्राप्त फ़ाइलें' : 'Saved & received files'}
      onBack={() => setScreen('dashboard')}
      backLabel={isHi ? 'वापस जाएं' : 'Back'}
      rightAction={
        <>
          <button
            type="button"
            onClick={() => uploadRef.current?.click()}
            className="min-h-[40px] px-4 py-2 rounded-full bg-gradient-to-r from-[#C85A00] via-[#D96B08] to-[#B84E00] border border-[#F5D08A]/75 text-white text-xs font-semibold inline-flex items-center gap-1.5 whitespace-nowrap shadow-xs cursor-pointer"
          >
            <Upload className="w-3.5 h-3.5" />
            <span>{isHi ? 'जोड़ें' : 'Add'}</span>
          </button>
          <input
            ref={uploadRef}
            type="file"
            multiple
            className="hidden"
            onChange={(e) => {
              if (e.target.files?.length) {
                void addFilesToVault(Array.from(e.target.files), 'local-vault');
              }
              e.target.value = '';
            }}
          />
        </>
      }
    >
      {/* Category Pills */}
      <div className="flex items-center gap-2 overflow-x-auto pb-1">
        {FILE_CATEGORIES.map((cat) => {
          const count = categoryCounts[cat.id] || 0;
          const active = category === cat.id;
          return (
            <button
              key={cat.id}
              type="button"
              onClick={() => setCategory(cat.id)}
              className={`min-h-[36px] px-3.5 py-1.5 rounded-full text-xs font-semibold whitespace-nowrap shrink-0 border transition-colors cursor-pointer inline-flex items-center gap-1.5 ${
                active
                  ? 'bg-gradient-to-r from-[#D96B08] to-[#B84E00] border-[#F5D08A]/80 text-white shadow-xs'
                  : 'bg-white/85 dark:bg-[#0D2148]/85 border-[#C5A059]/45 dark:border-[#C5A059]/30 text-[#5B4D38] dark:text-[#DBEAFE] hover:border-[#C85A00]'
              }`}
            >
              <span>{isHi ? cat.labelHi : cat.labelEn}</span>
              <span className={`font-mono tabular-nums text-[11px] ${active ? 'text-[#FFE7BA]' : 'opacity-75'}`}>
                {count}
              </span>
            </button>
          );
        })}
      </div>

      {/* Search & Select All */}
      <div className="rounded-2xl border border-[#C5A059]/45 dark:border-[#C5A059]/30 bg-white/90 dark:bg-[#0D2148]/90 p-3 flex flex-col sm:flex-row sm:items-center justify-between gap-2.5">
        <div className="relative flex-1">
          <Search className="w-4 h-4 text-[#7A633C] dark:text-[#93C5FD] absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder={isHi ? 'फ़ाइल का नाम खोजें...' : 'Search files...'}
            className="w-full min-h-[38px] pl-9 pr-3 py-1.5 rounded-xl border border-[#C5A059]/40 bg-[#FAF6EC] dark:bg-[#06132B] text-sm text-[#0A1F44] dark:text-white focus:outline-none focus:border-[#D96B08]"
          />
        </div>

        {filteredFiles.length > 0 && (
          <button
            type="button"
            onClick={toggleSelectAll}
            className="min-h-[38px] px-3.5 py-1.5 rounded-xl border border-[#C5A059]/45 bg-[#FAF6EC] dark:bg-[#091836] text-xs font-semibold text-[#0A1F44] dark:text-[#E4C788] hover:border-[#D96B08] inline-flex items-center justify-center gap-1.5 whitespace-nowrap cursor-pointer"
          >
            {allSelected ? (
              <CheckSquare className="w-4 h-4 text-[#D96B08] dark:text-[#E4C788]" />
            ) : (
              <Square className="w-4 h-4" />
            )}
            <span>
              {allSelected
                ? isHi
                  ? 'चयन हटाएं'
                  : 'Deselect'
                : isHi
                  ? 'सभी चुनें'
                  : 'Select All'}
            </span>
          </button>
        )}
      </div>

      {/* File List */}
      <div className="flex-1 rounded-[24px] border border-[#C5A059]/45 dark:border-[#C5A059]/30 bg-white/90 dark:bg-[#0D2148]/90 overflow-hidden">
        {filteredFiles.length === 0 ? (
          <div className="py-12 flex flex-col items-center text-center px-6">
            <EmptyVaultIllustration />
            <p className="mt-3 text-sm font-semibold text-[#0A1F44] dark:text-white">
              {isHi ? 'कोई फ़ाइल नहीं मिली' : 'No files found'}
            </p>
            <p className="mt-1 text-xs text-[#6B5A3E] dark:text-[#93C5FD] max-w-sm">
              {isHi
                ? 'प्राप्त की गई या जोड़ी गई फ़ाइलें यहां दिखेंगी।'
                : 'Files you receive or add appear here.'}
            </p>
          </div>
        ) : (
          <div className="divide-y divide-[#C5A059]/25 dark:divide-[#1B3154]">
            {filteredFiles.map((file) => {
              const checked = selectedIds.has(file.id);
              return (
                <div
                  key={file.id}
                  className={`px-4 py-3 flex items-center justify-between gap-3 transition-colors ${
                    checked
                      ? 'bg-[#FFF5E6] dark:bg-[#1E1B24]/95'
                      : 'hover:bg-[#FAF6EC]/70 dark:hover:bg-[#091836]/60'
                  }`}
                >
                  <div
                    onClick={() => toggleSelect(file.id)}
                    className="flex items-center gap-3 min-w-0 flex-1 cursor-pointer"
                  >
                    <CategoryVectorIcon category={file.category} size={34} />
                    <div className="min-w-0">
                      <p className="text-sm font-semibold text-[#0A1F44] dark:text-white truncate">
                        {file.name}
                      </p>
                      <p className="text-xs font-mono tabular-nums text-[#6B5A3E] dark:text-[#93C5FD] truncate">
                        {formatBytes(file.size)} · {new Date(file.modifiedAt).toLocaleDateString()}
                      </p>
                    </div>
                  </div>

                  <div className="flex items-center gap-2 shrink-0">
                    <button
                      type="button"
                      onClick={() => void downloadLocalFile(file)}
                      aria-label="Save file"
                      title={isHi ? 'सेव करें' : 'Save'}
                      className="min-h-[36px] px-3 rounded-full border border-[#C5A059]/45 bg-[#FAF6EC] dark:bg-[#091836] text-xs font-semibold text-[#0A1F44] dark:text-[#E4C788] hover:border-[#D96B08] inline-flex items-center gap-1.5 cursor-pointer"
                    >
                      <Download className="w-3.5 h-3.5 text-[#D96B08] dark:text-[#E4C788]" />
                      <span className="hidden sm:inline">{isHi ? 'सेव' : 'Save'}</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => toggleSelect(file.id)}
                      aria-label={`Select ${file.name}`}
                      className={`w-7 h-7 rounded-full border flex items-center justify-center transition-colors cursor-pointer ${
                        checked
                          ? 'bg-[#D96B08] border-[#F5D08A] text-white'
                          : 'border-[#C5A059]/55 dark:border-[#4A689A]'
                      }`}
                    >
                      {checked && <Check className="w-3.5 h-3.5 stroke-[3]" />}
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Inline Selection Action Bar */}
      {selectedIds.size > 0 && (
        <div className="rounded-2xl bg-[#0A1F44] dark:bg-[#06132B] border border-[#C5A059]/75 text-white p-3.5 shadow-lg flex flex-wrap items-center justify-between gap-2.5">
          <span className="text-xs font-semibold font-mono tabular-nums px-1 text-[#FFE7BA]">
            {isHi ? `${selectedIds.size} फ़ाइलें चुनी गईं` : `${selectedIds.size} Selected`}
          </span>
          <div className="flex flex-wrap items-center gap-2">
            <button
              type="button"
              onClick={() => void handleShareSelected()}
              className="min-h-[36px] px-4 py-1.5 rounded-full bg-gradient-to-r from-[#C85A00] to-[#D96B08] border border-[#F5D08A]/75 text-white text-xs font-bold inline-flex items-center gap-1.5 whitespace-nowrap cursor-pointer"
            >
              <Send className="w-3.5 h-3.5" />
              <span>{isHi ? 'भेजें' : 'Send'}</span>
            </button>
            {confirmDelete ? (
              <button
                type="button"
                onClick={() => void handleDeleteSelected()}
                className="min-h-[36px] px-3.5 py-1.5 rounded-full bg-red-600 text-white text-xs font-semibold whitespace-nowrap cursor-pointer"
              >
                {isHi ? 'पुष्टि करें' : 'Confirm'}
              </button>
            ) : (
              <button
                type="button"
                onClick={() => setConfirmDelete(true)}
                className="min-h-[36px] px-3 py-1.5 rounded-full border border-white/30 text-white text-xs font-medium inline-flex items-center gap-1 whitespace-nowrap cursor-pointer"
              >
                <Trash2 className="w-3.5 h-3.5" />
                <span>{isHi ? 'हटाएं' : 'Delete'}</span>
              </button>
            )}
          </div>
        </div>
      )}
    </HeritageScreenCard>
  );
}
