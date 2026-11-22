import React, { useEffect, useMemo, useRef, useState } from 'react';
import { motion, useReducedMotion } from 'motion/react';
import jsQR from 'jsqr';
import { QRCodeSVG } from 'qrcode.react';
import {
  ArrowDown,
  ArrowLeft,
  ArrowUp,
  Camera,
  Check,
  CheckCircle2,
  Copy,
  FilePlus2,
  FileText,
  Film,
  Folder,
  FolderUp,
  Grid,
  Image as ImageIcon,
  KeyRound,
  Laptop,
  Music,
  QrCode,
  Radar,
  Radio,
  RefreshCw,
  ScanLine,
  ShieldAlert,
  Smartphone,
  Tablet,
  Upload,
  XCircle,
} from 'lucide-react';
import { useVega } from '../../context/VegaContext.tsx';
import { categorizeFile, formatBytes, platformLabel } from '../../lib/formatters.ts';
import { offlineDb } from '../../lib/offlineDb.ts';
import type { LocalFileItem, PeerDevice, SelectedTransferFile } from '../../types/vega.ts';
import { TransferStatus } from '../TransferStatus.tsx';

export interface SendReceiveScreenProps {
  onOpenMenu?: () => void;
}

type SendFilterKey = 'all' | 'photos' | 'videos' | 'documents' | 'apps' | 'audio';

const SEND_FILTERS: Array<{ key: SendFilterKey; labelEn: string; labelHi: string }> = [
  { key: 'all', labelEn: 'All', labelHi: 'सभी' },
  { key: 'photos', labelEn: 'Photos', labelHi: 'फ़ोटो' },
  { key: 'videos', labelEn: 'Videos', labelHi: 'वीडियो' },
  { key: 'documents', labelEn: 'Docs', labelHi: 'दस्तावेज़' },
  { key: 'apps', labelEn: 'Apps', labelHi: 'ऐप्स' },
  { key: 'audio', labelEn: 'Audio', labelHi: 'ऑडियो' },
];

function matchesSendCategory(name: string, mimeType: string, catKey: SendFilterKey): boolean {
  if (catKey === 'all') return true;
  const cat = categorizeFile(name, mimeType);
  const ext = name.toLowerCase();
  if (catKey === 'photos') return cat === 'images';
  if (catKey === 'videos') return cat === 'videos';
  if (catKey === 'audio') {
    return (
      mimeType.startsWith('audio/') ||
      ext.endsWith('.mp3') ||
      ext.endsWith('.wav') ||
      ext.endsWith('.m4a') ||
      ext.endsWith('.flac') ||
      ext.endsWith('.aac') ||
      ext.endsWith('.ogg')
    );
  }
  if (catKey === 'documents') return cat === 'documents';
  if (catKey === 'apps') {
    return (
      cat === 'applications' ||
      cat === 'archives' ||
      ext.endsWith('.apk') ||
      ext.endsWith('.exe') ||
      ext.endsWith('.msi') ||
      ext.endsWith('.dmg')
    );
  }
  return true;
}

interface AvailableEntry {
  uid: string;
  name: string;
  relativePath: string;
  size: number;
  mimeType: string;
  sourceKind: 'picked' | 'saved';
  file?: File;
  localItem?: LocalFileItem;
}

export function SendFilesScreen(_props: SendReceiveScreenProps) {
  const {
    preselectedSendFiles,
    queuePreselectedSendFiles,
    clearPreselectedSendFiles,
    addFilesToVault,
    localFiles,
    settings,
    setScreen,
  } = useVega();

  const [sourceMode, setSourceMode] = useState<'all' | 'saved' | 'note'>('all');
  const [filterType, setFilterType] = useState<SendFilterKey>('all');
  const [pickedFiles, setPickedFiles] = useState<Array<{ uid: string; item: SelectedTransferFile }>>([]);
  const [selectedUids, setSelectedUids] = useState<Set<string>>(() => new Set());
  const [noteTitle, setNoteTitle] = useState('');
  const [noteBody, setNoteBody] = useState('');
  const [isDragging, setIsDragging] = useState(false);
  const [launching, setLaunching] = useState(false);

  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const folderInputRef = useRef<HTMLInputElement | null>(null);
  const isHi = settings.language === 'hi';

  React.useEffect(() => {
    if (preselectedSendFiles.length > 0) {
      const additions = preselectedSendFiles.map((entry, idx) => ({
        uid: `picked-${entry.file.name}-${entry.file.size}-${Date.now()}-${idx}`,
        item: entry,
      }));
      setPickedFiles((prev) => [...additions, ...prev]);
      setSelectedUids((prev) => {
        const next = new Set(prev);
        additions.forEach((a) => next.add(a.uid));
        return next;
      });
      setSourceMode('all');
      clearPreselectedSendFiles();
    }
  }, [clearPreselectedSendFiles, preselectedSendFiles]);

  const availableEntries = useMemo<AvailableEntry[]>(() => {
    const map = new Map<string, AvailableEntry>();
    for (const p of pickedFiles) {
      const key = `${p.item.relativePath}::${p.item.file.size}`;
      if (!map.has(key)) {
        map.set(key, {
          uid: p.uid,
          name: p.item.file.name,
          relativePath: p.item.relativePath,
          size: p.item.file.size,
          mimeType: p.item.file.type || 'application/octet-stream',
          sourceKind: 'picked',
          file: p.item.file,
        });
      }
    }
    for (const lf of localFiles) {
      const key = `${lf.relativePath || lf.name}::${lf.size}`;
      if (!map.has(key)) {
        map.set(key, {
          uid: `local-${lf.id}`,
          name: lf.name,
          relativePath: lf.relativePath || lf.name,
          size: lf.size,
          mimeType: lf.mimeType || 'application/octet-stream',
          sourceKind: 'saved',
          localItem: lf,
        });
      }
    }
    return Array.from(map.values());
  }, [localFiles, pickedFiles]);

  const scopedEntries = useMemo(
    () =>
      sourceMode === 'saved'
        ? availableEntries.filter((e) => e.sourceKind === 'saved')
        : availableEntries,
    [availableEntries, sourceMode]
  );

  const visibleEntries = useMemo(
    () =>
      scopedEntries.filter((e) =>
        matchesSendCategory(e.name, e.mimeType, filterType)
      ),
    [filterType, scopedEntries]
  );

  const selectedCount = useMemo(
    () => availableEntries.filter((e) => selectedUids.has(e.uid)).length,
    [availableEntries, selectedUids]
  );

  const handleFilesAdded = (fileList: FileList | null) => {
    if (!fileList || fileList.length === 0) return;
    const rawFiles = Array.from(fileList);
    const additions = rawFiles.map((f, idx) => ({
      uid: `picked-${f.name}-${f.size}-${Date.now()}-${idx}`,
      item: {
        file: f,
        relativePath: (f as File & { webkitRelativePath?: string }).webkitRelativePath || f.name,
      },
    }));
    setPickedFiles((prev) => [...additions, ...prev]);
    setSelectedUids((prev) => {
      const next = new Set(prev);
      additions.forEach((a) => next.add(a.uid));
      return next;
    });
    setSourceMode('all');
    setFilterType('all');
    void addFilesToVault(rawFiles, 'local-vault');
  };

  const handleAttachNote = () => {
    const trimmedBody = noteBody.trim();
    if (!trimmedBody) return;
    const cleanTitle = noteTitle
      .trim()
      .replace(/[^a-zA-Z0-9_\-\u0900-\u097F ]+/g, '')
      .replace(/\s+/g, '_');
    const fileName = `${cleanTitle || `Note_${new Date().toISOString().slice(11, 19).replace(/:/g, '-')}`}.txt`;
    const noteFile = new File([trimmedBody], fileName, { type: 'text/plain' });
    const uid = `picked-${fileName}-${noteFile.size}-${Date.now()}`;
    setPickedFiles((prev) => [{ uid, item: { file: noteFile, relativePath: fileName } }, ...prev]);
    setSelectedUids((prev) => {
      const next = new Set(prev);
      next.add(uid);
      return next;
    });
    setNoteTitle('');
    setNoteBody('');
    setSourceMode('all');
    setFilterType('all');
    void addFilesToVault([noteFile], 'local-vault');
  };

  const toggleEntry = (uid: string) => {
    setSelectedUids((prev) => {
      const next = new Set(prev);
      if (next.has(uid)) next.delete(uid);
      else next.add(uid);
      return next;
    });
  };

  const handleScanForReceivers = async () => {
    setLaunching(true);
    try {
      const selectedEntries = availableEntries.filter((e) => selectedUids.has(e.uid));
      const resolved: SelectedTransferFile[] = [];
      for (const entry of selectedEntries) {
        if (entry.file) {
          resolved.push({ file: entry.file, relativePath: entry.relativePath });
        } else if (entry.localItem) {
          const blob = await offlineDb.getFileBlob(entry.localItem.id);
          if (blob) {
            const file = new File([blob], entry.localItem.name, {
              type: entry.localItem.mimeType || 'application/octet-stream',
            });
            resolved.push({ file, relativePath: entry.relativePath });
          }
        }
      }
      if (resolved.length > 0) {
        queuePreselectedSendFiles(resolved);
      } else {
        clearPreselectedSendFiles();
      }
      setScreen('receive');
    } finally {
      setLaunching(false);
    }
  };

  const renderCategoryIcon = (name: string, mimeType: string) => {
    if (matchesSendCategory(name, mimeType, 'videos')) return <Film className="w-5 h-5" />;
    if (matchesSendCategory(name, mimeType, 'audio')) return <Music className="w-5 h-5" />;
    if (matchesSendCategory(name, mimeType, 'documents')) return <FileText className="w-5 h-5" />;
    if (matchesSendCategory(name, mimeType, 'apps')) return <Grid className="w-5 h-5" />;
    if (matchesSendCategory(name, mimeType, 'photos')) return <ImageIcon className="w-5 h-5" />;
    return <Folder className="w-5 h-5" />;
  };

  return (
    <div
      className="max-w-2xl mx-auto"
      onDragEnter={(e) => {
        e.preventDefault();
        setIsDragging(true);
      }}
      onDragOver={(e) => {
        e.preventDefault();
        if (!isDragging) setIsDragging(true);
      }}
      onDragLeave={(e) => {
        e.preventDefault();
        if (e.currentTarget === e.target) setIsDragging(false);
      }}
      onDrop={(e) => {
        e.preventDefault();
        setIsDragging(false);
        handleFilesAdded(e.dataTransfer.files);
      }}
    >
      <input
        ref={fileInputRef}
        type="file"
        accept="*/*"
        multiple
        className="hidden"
        onChange={(e) => {
          handleFilesAdded(e.target.files);
          e.target.value = '';
        }}
      />
      <input
        ref={folderInputRef}
        type="file"
        multiple
        {...({ webkitdirectory: '', directory: '' } as Record<string, string>)}
        className="hidden"
        onChange={(e) => {
          handleFilesAdded(e.target.files);
          e.target.value = '';
        }}
      />

      {/* Minimalist Rajasthani Heritage Send Card */}
      <section
        aria-label="Send Files"
        className={`relative overflow-hidden rounded-none sm:rounded-[34px] bg-[#FFFDF8] dark:bg-[#0A1F44] bg-gradient-to-b from-[#FFFDF8] via-[#F7F1E2] to-[#EDE2C8] dark:from-[#0A1F44] dark:via-[#07193B] dark:to-[#04122B] text-[#0A1F44] dark:text-white min-h-[100svh] sm:min-h-[640px] shadow-[0_20px_54px_rgba(10,31,68,0.14)] dark:shadow-[0_24px_64px_rgba(6,17,41,0.58)] sm:border sm:border-[#C5A059]/70 dark:sm:border-[#C5A059]/55 flex flex-col justify-between px-5 pt-5 pb-6 sm:px-7 sm:pt-7 sm:pb-7 gap-5 bg-rajasthani-jali-light transition-shadow ${
          isDragging ? 'ring-2 ring-[#C85A00]' : ''
        }`}
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

        {/* Top Bar: Back Button + Title + Selected Count */}
        <div className="relative z-10 flex items-center gap-3.5">
          <button
            type="button"
            onClick={() => setScreen('dashboard')}
            aria-label={isHi ? 'वापस जाएं' : 'Back'}
            className="w-11 h-11 rounded-full bg-white/95 dark:bg-[#0F2752] border border-[#C5A059]/70 text-[#0A1F44] dark:text-[#E4C788] hover:bg-[#0A1F44] hover:text-white dark:hover:bg-[#C85A00] dark:hover:text-white flex items-center justify-center shrink-0 shadow-xs transition-colors cursor-pointer"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>

          <div className="min-w-0">
            <h1 className="font-heritage text-xl sm:text-2xl tracking-wide text-[#0A1F44] dark:text-white leading-tight">
              {isHi ? 'फ़ाइलें भेजें' : 'Send Files'}
            </h1>
            <p className="text-xs sm:text-sm font-medium text-[#7A633C] dark:text-[#93C5FD] tabular-nums">
              {isHi
                ? `${selectedCount} फ़ाइलें चुनी गईं`
                : `${selectedCount} ${selectedCount === 1 ? 'item' : 'items'} selected`}
            </p>
          </div>
        </div>

        {/* 2x2 Distinct Functional Send Cards */}
        <div className="relative z-10 grid grid-cols-2 gap-3">
          {/* Card 1: Choose Files */}
          <button
            type="button"
            onClick={() => fileInputRef.current?.click()}
            className="group rounded-2xl py-3.5 px-3 flex items-center gap-3 text-left bg-gradient-to-br from-[#D96B08] via-[#C85A00] to-[#9E4100] border border-[#F5D08A] text-white shadow-[0_10px_24px_rgba(200,90,0,0.3)] hover:brightness-105 transition-all cursor-pointer"
          >
            <span className="w-10 h-10 rounded-xl bg-white/15 border border-[#F5D08A]/50 flex items-center justify-center shrink-0">
              <FilePlus2 className="w-5 h-5 text-white" />
            </span>
            <span className="min-w-0">
              <span className="block text-sm font-bold leading-tight">
                {isHi ? 'फ़ाइलें चुनें' : 'Pick Files'}
              </span>
              <span className="block text-[11px] text-[#FFE7BA] mt-0.5 truncate">
                {isHi ? 'फ़ोटो, वीडियो, PDF' : 'Photos, video, docs'}
              </span>
            </span>
          </button>

          {/* Card 2: Choose Entire Folder */}
          <button
            type="button"
            onClick={() => folderInputRef.current?.click()}
            className="group rounded-2xl py-3.5 px-3 flex items-center gap-3 text-left bg-white/90 dark:bg-[#0E2550]/90 border border-[#C5A059]/45 dark:border-[#C5A059]/30 text-[#0A1F44] dark:text-white hover:border-[#C85A00] dark:hover:border-[#E4C788] transition-all cursor-pointer"
          >
            <span className="w-10 h-10 rounded-xl bg-[#FAF6EC] dark:bg-[#06132B] border border-[#C5A059]/45 flex items-center justify-center shrink-0">
              <FolderUp className="w-5 h-5 text-[#D96B08] dark:text-[#E4C788]" />
            </span>
            <span className="min-w-0">
              <span className="block text-sm font-bold leading-tight">
                {isHi ? 'फ़ोल्डर चुनें' : 'Pick Folder'}
              </span>
              <span className="block text-[11px] text-[#6B5A3E] dark:text-[#93C5FD] mt-0.5 truncate">
                {isHi ? 'पूरा फ़ोल्डर भेजें' : 'Entire directory'}
              </span>
            </span>
          </button>

          {/* Card 3: Quick Text / Link Note */}
          <button
            type="button"
            onClick={() => setSourceMode((m) => (m === 'note' ? 'all' : 'note'))}
            className={`group rounded-2xl py-3.5 px-3 flex items-center gap-3 text-left border transition-all cursor-pointer ${
              sourceMode === 'note'
                ? 'bg-[#FFF5E6] dark:bg-[#1E1B24]/95 border-[#C85A00] dark:border-[#E4C788]'
                : 'bg-white/90 dark:bg-[#0E2550]/90 border-[#C5A059]/45 dark:border-[#C5A059]/30 hover:border-[#C85A00] dark:hover:border-[#E4C788]'
            }`}
          >
            <span className="w-10 h-10 rounded-xl bg-[#FAF6EC] dark:bg-[#06132B] border border-[#C5A059]/45 flex items-center justify-center shrink-0">
              <FileText className="w-5 h-5 text-[#D96B08] dark:text-[#E4C788]" />
            </span>
            <span className="min-w-0">
              <span className="block text-sm font-bold leading-tight text-[#0A1F44] dark:text-white">
                {isHi ? 'टेक्स्ट / नोट' : 'Text Note'}
              </span>
              <span className="block text-[11px] text-[#6B5A3E] dark:text-[#93C5FD] mt-0.5 truncate">
                {isHi ? 'लिंक या संदेश लिखें' : 'Type text or link'}
              </span>
            </span>
          </button>

          {/* Card 4: Saved Files in App */}
          <button
            type="button"
            onClick={() => {
              setFilterType('all');
              setSourceMode((m) => (m === 'saved' ? 'all' : 'saved'));
            }}
            className={`group rounded-2xl py-3.5 px-3 flex items-center gap-3 text-left border transition-all cursor-pointer ${
              sourceMode === 'saved'
                ? 'bg-[#FFF5E6] dark:bg-[#1E1B24]/95 border-[#C85A00] dark:border-[#E4C788]'
                : 'bg-white/90 dark:bg-[#0E2550]/90 border-[#C5A059]/45 dark:border-[#C5A059]/30 hover:border-[#C85A00] dark:hover:border-[#E4C788]'
            }`}
          >
            <span className="w-10 h-10 rounded-xl bg-[#FAF6EC] dark:bg-[#06132B] border border-[#C5A059]/45 flex items-center justify-center shrink-0">
              <Folder className="w-5 h-5 text-[#D96B08] dark:text-[#E4C788]" />
            </span>
            <span className="min-w-0">
              <span className="block text-sm font-bold leading-tight text-[#0A1F44] dark:text-white">
                {isHi ? `ऐप फ़ाइलें (${localFiles.length})` : `Saved (${localFiles.length})`}
              </span>
              <span className="block text-[11px] text-[#6B5A3E] dark:text-[#93C5FD] mt-0.5 truncate">
                {isHi ? 'पहले से सहेजी गई' : 'Saved on device'}
              </span>
            </span>
          </button>
        </div>

        {/* Inline Quick Text Note Editor OR Filterable Item List */}
        {sourceMode === 'note' ? (
          <div className="relative z-10 flex-1 flex flex-col rounded-[24px] border border-[#C5A059]/60 dark:border-[#C5A059]/40 bg-white/95 dark:bg-[#0D2148]/95 p-4 space-y-3 shadow-xs">
            <div className="flex items-center justify-between gap-2">
              <h2 className="text-sm font-bold text-[#0A1F44] dark:text-white font-heritage">
                {isHi ? 'भेजने के लिए टेक्स्ट या लिंक लिखें' : 'Write Text or Link to Send'}
              </h2>
              <button
                type="button"
                onClick={() => setSourceMode('all')}
                className="text-xs font-medium text-[#7A633C] dark:text-[#93C5FD] hover:underline cursor-pointer"
              >
                {isHi ? 'सूची देखें' : 'View List'}
              </button>
            </div>
            <input
              type="text"
              value={noteTitle}
              onChange={(e) => setNoteTitle(e.target.value)}
              placeholder={isHi ? 'शीर्षक (वैकल्पिक)' : 'Title (optional)'}
              className="w-full min-h-[38px] px-3.5 py-2 rounded-xl border border-[#C5A059]/45 bg-[#FAF6EC] dark:bg-[#06132B] text-sm text-[#0A1F44] dark:text-white focus:outline-none focus:border-[#D96B08]"
            />
            <textarea
              rows={4}
              value={noteBody}
              onChange={(e) => setNoteBody(e.target.value)}
              placeholder={
                isHi
                  ? 'यहाँ कोई भी संदेश, Wi-Fi पासवर्ड या लिंक पेस्ट करें...'
                  : 'Type or paste a message, password, or link here...'
              }
              className="w-full flex-1 min-h-[110px] px-3.5 py-2.5 rounded-xl border border-[#C5A059]/45 bg-[#FAF6EC] dark:bg-[#06132B] text-sm text-[#0A1F44] dark:text-white focus:outline-none focus:border-[#D96B08] resize-none"
            />
            <div className="flex justify-end gap-2">
              <button
                type="button"
                onClick={() => setSourceMode('all')}
                className="min-h-[38px] px-4 py-1.5 rounded-full border border-[#C5A059]/50 text-xs font-medium text-[#0A1F44] dark:text-[#DBEAFE] cursor-pointer"
              >
                {isHi ? 'रद्द' : 'Cancel'}
              </button>
              <button
                type="button"
                disabled={!noteBody.trim()}
                onClick={handleAttachNote}
                className="min-h-[38px] px-4 py-1.5 rounded-full bg-gradient-to-r from-[#D96B08] to-[#B84E00] disabled:opacity-50 border border-[#F5D08A]/75 text-white text-xs font-semibold cursor-pointer"
              >
                {isHi ? 'सूची में जोड़ें' : 'Add to Send List'}
              </button>
            </div>
          </div>
        ) : (
          <div className="relative z-10 flex-1 flex flex-col min-h-0 space-y-2.5">
            <div className="flex items-center justify-between px-0.5">
              <h2 className="text-sm font-semibold text-[#5B4D38] dark:text-[#93C5FD]">
                {sourceMode === 'saved'
                  ? isHi
                    ? 'ऐप में सहेजी फ़ाइलें'
                    : 'Saved App Files'
                  : isHi
                    ? 'भेजने के लिए तैयार'
                    : 'Ready to Send'}
              </h2>
              {selectedCount > 0 && (
                <button
                  type="button"
                  onClick={() => setSelectedUids(new Set())}
                  className="text-xs font-semibold text-[#B84E00] dark:text-[#E4C788] hover:underline cursor-pointer"
                >
                  {isHi ? 'चयन हटाएं' : 'Clear Selection'}
                </button>
              )}
            </div>

            {/* Type Filter Pills (Purely filters existing items) */}
            {scopedEntries.length > 0 && (
              <div className="flex items-center gap-1.5 overflow-x-auto pb-0.5">
                {SEND_FILTERS.map((f) => {
                  const active = filterType === f.key;
                  return (
                    <button
                      key={f.key}
                      type="button"
                      onClick={() => setFilterType(f.key)}
                      className={`min-h-[30px] px-3 py-1 rounded-full text-xs font-semibold whitespace-nowrap shrink-0 border transition-colors cursor-pointer ${
                        active
                          ? 'bg-gradient-to-r from-[#D96B08] to-[#B84E00] border-[#F5D08A]/80 text-white'
                          : 'bg-white/85 dark:bg-[#0D2148]/85 border-[#C5A059]/45 dark:border-[#C5A059]/30 text-[#5B4D38] dark:text-[#DBEAFE] hover:border-[#D96B08]'
                      }`}
                    >
                      {isHi ? f.labelHi : f.labelEn}
                    </button>
                  );
                })}
              </div>
            )}

            {visibleEntries.length === 0 ? (
              <div className="flex-1 min-h-[170px] rounded-2xl border border-dashed border-[#C5A059]/65 dark:border-[#C5A059]/40 bg-white/75 dark:bg-[#0D224A]/70 px-5 py-8 flex flex-col items-center justify-center text-center gap-2">
                <p className="text-sm font-semibold text-[#0A1F44] dark:text-white">
                  {sourceMode === 'saved'
                    ? isHi
                      ? 'ऐप में अभी कोई सहेजी फ़ाइल नहीं है'
                      : 'No saved files in app yet'
                    : scopedEntries.length > 0
                      ? isHi
                        ? 'इस श्रेणी में कोई फ़ाइल नहीं है'
                        : 'No files match this filter'
                      : isHi
                        ? 'ऊपर से फ़ाइल, फ़ोल्डर या टेक्स्ट चुनें — या यहाँ ड्रॉप करें'
                        : 'Choose Files, Folder, or Note above — or drop files here'}
                </p>
              </div>
            ) : (
              <div className="space-y-2.5 max-h-[260px] overflow-y-auto pr-0.5">
                {visibleEntries.map((entry) => {
                  const checked = selectedUids.has(entry.uid);
                  return (
                    <button
                      key={entry.uid}
                      type="button"
                      onClick={() => toggleEntry(entry.uid)}
                      className={`w-full rounded-2xl border px-3.5 py-3 flex items-center justify-between gap-3 text-left transition-all duration-150 cursor-pointer ${
                        checked
                          ? 'border-[#C85A00] dark:border-[#E07A1F] bg-[#FFF5E6] dark:bg-[#1E1B24]/95 shadow-xs'
                          : 'border-[#C5A059]/40 dark:border-[#1F3A6B] bg-white/90 dark:bg-[#0E2550]/85 hover:border-[#C5A059]'
                      }`}
                    >
                      <div className="flex items-center gap-3 min-w-0">
                        <div
                          className={`w-10 h-10 rounded-xl flex items-center justify-center shrink-0 border transition-colors ${
                            checked
                              ? 'bg-gradient-to-b from-[#E06D06] to-[#B84E00] border-[#F5D08A]/75 text-white'
                              : 'bg-[#F0E9D8] dark:bg-[#193366] border-[#C5A059]/35 text-[#6B5A3E] dark:text-[#93C5FD]'
                          }`}
                        >
                          {renderCategoryIcon(entry.name, entry.mimeType)}
                        </div>
                        <div className="min-w-0">
                          <p className="text-sm font-semibold text-[#0A1F44] dark:text-white truncate">
                            {entry.relativePath || entry.name}
                          </p>
                          <p className="text-xs font-mono tabular-nums text-[#6B5A3E] dark:text-[#93C5FD]">
                            {formatBytes(entry.size)}
                          </p>
                        </div>
                      </div>

                      <span
                        aria-hidden="true"
                        className={`w-6 h-6 rounded-full flex items-center justify-center shrink-0 border transition-colors ${
                          checked
                            ? 'bg-[#D96B08] border-[#F5D08A] text-white'
                            : 'border-[#C5A059]/55 dark:border-[#4A689A] bg-transparent'
                        }`}
                      >
                        {checked && <Check className="w-3.5 h-3.5 stroke-[3]" />}
                      </span>
                    </button>
                  );
                })}
              </div>
            )}
          </div>
        )}

        {/* Single Bottom Pill Button: Scan for Receivers */}
        <div className="relative z-10 pt-1">
          <button
            type="button"
            disabled={launching}
            onClick={() => void handleScanForReceivers()}
            className="w-full h-13 rounded-full bg-gradient-to-r from-[#C85A00] via-[#D96B08] to-[#B84E00] hover:from-[#B55000] hover:to-[#9E4100] active:scale-[0.99] disabled:opacity-60 text-white text-base font-bold inline-flex items-center justify-center gap-2.5 border border-[#F5D08A]/80 shadow-[0_10px_26px_rgba(200,90,0,0.38)] transition-[transform,background-color] duration-150 cursor-pointer"
          >
            <span>{isHi ? 'रिसीवर खोजें' : 'Scan for Receivers'}</span>
            <Radio className="w-4 h-4 text-[#FFE7BA]" />
          </button>
        </div>
      </section>
    </div>
  );
}

function ReceiveDeviceGlyph({
  platform,
  className = 'w-5 h-5',
}: {
  platform: PeerDevice['platform'];
  className?: string;
}) {
  if (platform === 'windows') return <Laptop className={className} />;
  if (platform === 'android') return <Smartphone className={className} />;
  return <Tablet className={className} />;
}

export function ReceiveFilesScreen(_props: SendReceiveScreenProps) {
  const {
    peers,
    discoveryActive,
    refreshDiscovery,
    requestPairingWithPeer,
    requestPairingWithToken,
    isPeerTrusted,
    pendingIncomingTransfer,
    respondToIncomingTransfer,
    activePairingSession,
    generateQrPairing,
    preselectedSendFiles,
    clearPreselectedSendFiles,
    startFileTransfer,
    showToast,
    identity,
    platform,
    transfers,
    settings,
    setScreen,
    t,
  } = useVega();

  const prefersReducedMotion = useReducedMotion() || settings.reducedMotion || !settings.enableAnimations;
  const animateRadar = discoveryActive && !prefersReducedMotion;
  const isHi = settings.language === 'hi';
  const isDark = settings.theme === 'dark';
  const isSendTargetMode = preselectedSendFiles.length > 0;

  const [connectingPeerId, setConnectingPeerId] = useState<string | null>(null);
  const [panelMode, setPanelMode] = useState<'radar' | 'show-qr' | 'scan-qr'>('radar');
  const [secondsLeft, setSecondsLeft] = useState(0);
  const [copied, setCopied] = useState(false);

  // Inline QR Scanner & Short Code State
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const qrImageRef = useRef<HTMLInputElement | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const rafRef = useRef<number | null>(null);
  const [cameraActive, setCameraActive] = useState(false);
  const [cameraError, setCameraError] = useState<string | null>(null);
  const [manualToken, setManualToken] = useState('');
  const [scanResult, setScanResult] = useState<{ ok: boolean; message: string } | null>(null);

  const activeReceives = transfers.filter(
    (tr) => tr.direction === 'receive' && (tr.status === 'transferring' || tr.status === 'verifying')
  );

  const stopCamera = () => {
    if (rafRef.current) cancelAnimationFrame(rafRef.current);
    rafRef.current = null;
    if (streamRef.current) {
      streamRef.current.getTracks().forEach((tr) => tr.stop());
      streamRef.current = null;
    }
    setCameraActive(false);
  };

  useEffect(() => {
    if (panelMode !== 'scan-qr') {
      stopCamera();
    }
    return () => stopCamera();
  }, [panelMode]);

  useEffect(() => {
    if (panelMode !== 'show-qr' || !activePairingSession) {
      setSecondsLeft(0);
      return;
    }
    const updateTimer = () => {
      const diff = Math.max(
        0,
        Math.ceil((new Date(activePairingSession.expiresAt).getTime() - Date.now()) / 1000)
      );
      setSecondsLeft(diff);
    };
    updateTimer();
    const id = setInterval(updateTimer, 1000);
    return () => clearInterval(id);
  }, [activePairingSession, panelMode]);

  const qrPayload = useMemo(() => {
    if (!activePairingSession) return '';
    return JSON.stringify({
      type: 'vega-pair',
      version: '1.0.0',
      token: activePairingSession.token,
      hostPeerId: activePairingSession.hostPeerId,
      deviceName: activePairingSession.hostDeviceName || settings.deviceName,
      platform: activePairingSession.hostPlatform || platform,
      fingerprint: activePairingSession.hostFingerprint || identity?.fingerprint || '',
      expiresAt: activePairingSession.expiresAt,
    });
  }, [activePairingSession, identity?.fingerprint, platform, settings.deviceName]);

  const handleOpenQr = () => {
    setPanelMode('show-qr');
    const isExpired =
      !activePairingSession || new Date(activePairingSession.expiresAt).getTime() <= Date.now();
    if (isExpired) {
      void generateQrPairing();
    }
  };

  const handleDecodedPayload = async (raw: string) => {
    const res = await requestPairingWithToken(raw);
    if (res.ok) {
      stopCamera();
      setScanResult({
        ok: true,
        message: isHi
          ? 'कनेक्शन अनुरोध भेजा गया। दूसरे डिवाइस पर स्वीकार करें।'
          : 'Connection request sent. Approve on the other device.',
      });
      setPanelMode('radar');
      showToast({
        variant: 'success',
        title: isHi ? 'कनेक्शन अनुरोध भेजा गया' : 'Connection Request Sent',
        message: isHi ? 'दूसरे डिवाइस पर स्वीकार करें।' : 'Accept on the other device.',
      });
    } else {
      setScanResult({
        ok: false,
        message: res.error || (isHi ? 'कोड मान्य नहीं है।' : 'Could not verify code.'),
      });
    }
  };

  const startCamera = async () => {
    setCameraError(null);
    setScanResult(null);
    if (!navigator.mediaDevices?.getUserMedia) {
      setCameraError(
        isHi ? 'कैमरा उपलब्ध नहीं है। नीचे कोड टाइप करें।' : 'Camera unavailable. Enter code below.'
      );
      return;
    }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'environment' },
      });
      streamRef.current = stream;
      setCameraActive(true);
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        await videoRef.current.play();
      }
      const tick = () => {
        const video = videoRef.current;
        const canvas = canvasRef.current;
        if (video && canvas && video.readyState === video.HAVE_ENOUGH_DATA) {
          canvas.width = video.videoWidth;
          canvas.height = video.videoHeight;
          const ctx = canvas.getContext('2d');
          if (ctx) {
            ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
            const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
            const code = jsQR(imageData.data, imageData.width, imageData.height);
            if (code?.data) {
              void handleDecodedPayload(code.data);
              return;
            }
          }
        }
        rafRef.current = requestAnimationFrame(tick);
      };
      rafRef.current = requestAnimationFrame(tick);
    } catch {
      setCameraError(
        isHi
          ? 'कैमरा अनुमति नहीं मिली। नीचे कोड टाइप करें।'
          : 'Camera permission denied. Enter the code below.'
      );
      setCameraActive(false);
    }
  };

  const handleQrImageUpload = (file?: File) => {
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      const img = new Image();
      img.onload = () => {
        const canvas = document.createElement('canvas');
        canvas.width = img.width;
        canvas.height = img.height;
        const ctx = canvas.getContext('2d');
        if (!ctx) return;
        ctx.drawImage(img, 0, 0);
        const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
        const decoded = jsQR(imageData.data, imageData.width, imageData.height);
        if (decoded?.data) {
          void handleDecodedPayload(decoded.data);
        } else {
          setScanResult({
            ok: false,
            message: isHi ? 'तस्वीर में QR कोड नहीं मिला।' : 'No QR code found in that image.',
          });
        }
      };
      img.src = String(reader.result);
    };
    reader.readAsDataURL(file);
  };

  const handleCopyToken = async () => {
    if (!activePairingSession?.token) return;
    try {
      await navigator.clipboard.writeText(activePairingSession.token);
      setCopied(true);
      setTimeout(() => setCopied(false), 1800);
    } catch {
      // clipboard blocked in restricted context
    }
  };

  const handleSelectPeer = async (peer: PeerDevice) => {
    setConnectingPeerId(peer.peerId);
    try {
      if (isSendTargetMode) {
        const filesToSend = [...preselectedSendFiles];
        clearPreselectedSendFiles();
        await startFileTransfer(filesToSend, peer);
        return;
      }
      if (!isPeerTrusted(peer.peerId)) {
        requestPairingWithPeer(peer);
      } else {
        refreshDiscovery();
      }
      setTimeout(() => setConnectingPeerId(null), 1500);
    } catch {
      setConnectingPeerId(null);
    }
  };

  const qrTimerPct = Math.min(100, Math.max(0, Math.round((secondsLeft / 120) * 100)));

  const headerTitle =
    panelMode === 'show-qr'
      ? isHi
        ? 'मेरा QR कोड'
        : 'My QR Code'
      : panelMode === 'scan-qr'
        ? isHi
          ? 'QR स्कैन करें'
          : 'Scan QR Code'
        : isSendTargetMode
          ? isHi
            ? 'रिसीवर खोजें'
            : 'Scan for Receivers'
          : isHi
            ? 'नज़दीकी खोज'
            : 'Searching Nearby';

  const headerSubtitle =
    panelMode === 'show-qr'
      ? isHi
        ? 'जुड़ने के लिए दूसरे डिवाइस से यह QR कोड स्कैन करें'
        : 'Scan this QR code from the other device to connect'
      : panelMode === 'scan-qr'
        ? isHi
          ? 'रिसीवर का QR कोड स्कैन करें या कोड दर्ज करें'
          : "Scan the receiver's QR code or enter its short code"
        : isSendTargetMode
          ? isHi
            ? `${preselectedSendFiles.length} फ़ाइलें भेजने के लिए डिवाइस चुनें`
            : `Tap a device to send ${preselectedSendFiles.length} ${
                preselectedSendFiles.length === 1 ? 'file' : 'files'
              }`
          : isHi
            ? 'सुनिश्चित करें कि दूसरा डिवाइस तैयार है'
            : "Make sure sender's visibility is turned on";

  return (
    <div className="max-w-2xl mx-auto">
      {/* Minimalist Rajasthani Heritage Receive / Radar Card (No Extra Top Header) */}
      <section
        aria-label={headerTitle}
        className="relative overflow-hidden rounded-none sm:rounded-[34px] bg-[#FFFDF8] dark:bg-[#0A1F44] bg-gradient-to-b from-[#FFFDF8] via-[#F7F1E2] to-[#EDE2C8] dark:from-[#0A1F44] dark:via-[#07193B] dark:to-[#04122B] text-[#0A1F44] dark:text-white min-h-[100svh] sm:min-h-[640px] shadow-[0_20px_54px_rgba(10,31,68,0.14)] dark:shadow-[0_24px_64px_rgba(6,17,41,0.58)] sm:border sm:border-[#C5A059]/70 dark:sm:border-[#C5A059]/55 flex flex-col justify-between px-5 pt-5 pb-6 sm:px-7 sm:pt-7 sm:pb-7 gap-5 bg-rajasthani-jali-light"
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

        {/* Top Bar: ONLY Back Button + Title + 1-line Subtitle */}
        <div className="relative z-10 flex items-center gap-3.5">
          <button
            type="button"
            onClick={() => {
              if (panelMode !== 'radar') setPanelMode('radar');
              else if (isSendTargetMode) setScreen('send');
              else setScreen('dashboard');
            }}
            aria-label={isHi ? 'वापस जाएं' : 'Back'}
            className="w-11 h-11 rounded-full bg-white/95 dark:bg-[#0F2752] border border-[#C5A059]/70 text-[#0A1F44] dark:text-[#E4C788] hover:bg-[#0A1F44] hover:text-white dark:hover:bg-[#C85A00] dark:hover:text-white flex items-center justify-center shrink-0 shadow-xs transition-colors cursor-pointer"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>

          <div className="min-w-0">
            <h1 className="font-heritage text-xl sm:text-2xl tracking-wide text-[#0A1F44] dark:text-white leading-tight">
              {headerTitle}
            </h1>
            <p className="text-xs sm:text-sm font-medium text-[#7A633C] dark:text-[#93C5FD]">
              {headerSubtitle}
            </p>
          </div>
        </div>

        {panelMode === 'show-qr' ? (
          /* Inline Rajasthani Heritage QR Code View on Same Receive Screen */
          <div className="relative z-10 my-auto flex flex-col items-center gap-4 py-2">
            <div className="relative rounded-[28px] border-2 border-[#C5A059] bg-white p-4 shadow-[0_14px_38px_rgba(10,31,68,0.16)] dark:shadow-[0_18px_46px_rgba(4,12,30,0.55)]">
              <span
                aria-hidden="true"
                className="absolute -top-1.5 -left-1.5 w-3 h-3 rotate-45 bg-[#D96B08] border border-[#F5D08A]"
              />
              <span
                aria-hidden="true"
                className="absolute -top-1.5 -right-1.5 w-3 h-3 rotate-45 bg-[#D96B08] border border-[#F5D08A]"
              />
              <span
                aria-hidden="true"
                className="absolute -bottom-1.5 -left-1.5 w-3 h-3 rotate-45 bg-[#D96B08] border border-[#F5D08A]"
              />
              <span
                aria-hidden="true"
                className="absolute -bottom-1.5 -right-1.5 w-3 h-3 rotate-45 bg-[#D96B08] border border-[#F5D08A]"
              />
              <div className="w-[200px] h-[200px] sm:w-[216px] sm:h-[216px] flex items-center justify-center">
                {qrPayload ? (
                  <QRCodeSVG
                    value={qrPayload}
                    size={200}
                    bgColor="#FFFFFF"
                    fgColor="#0A1F44"
                    level="M"
                    title={`Vega Pairing QR (${activePairingSession?.token})`}
                  />
                ) : (
                  <span className="text-xs font-medium text-[#0A1F44]">
                    {isHi ? 'QR तैयार हो रहा है...' : 'Generating QR...'}
                  </span>
                )}
              </div>
            </div>

            {/* Code + Copy + Refresh */}
            <div className="w-full rounded-[22px] border border-[#C5A059]/60 dark:border-[#C5A059]/45 bg-white/95 dark:bg-[#0D2148]/95 px-4 py-3.5 space-y-3 shadow-xs">
              <div className="flex items-center justify-between gap-2.5">
                <div className="min-w-0">
                  <p className="text-[11px] font-semibold text-[#7A633C] dark:text-[#93C5FD]">
                    {isHi ? 'कनेक्शन कोड' : 'Connection Code'}
                  </p>
                  <p className="text-base font-mono font-bold tabular-nums tracking-wider text-[#0A1F44] dark:text-[#E4C788] truncate">
                    {activePairingSession?.token || '—'}
                  </p>
                </div>

                <div className="flex items-center gap-2 shrink-0">
                  {activePairingSession?.token && (
                    <button
                      type="button"
                      onClick={() => void handleCopyToken()}
                      className="min-h-[38px] px-3.5 py-1.5 rounded-full bg-gradient-to-r from-[#D96B08] to-[#B84E00] border border-[#F5D08A]/75 text-white text-xs font-semibold inline-flex items-center gap-1.5 cursor-pointer"
                    >
                      {copied ? (
                        <>
                          <Check className="w-3.5 h-3.5" />
                          <span>{isHi ? 'कॉपी हुआ' : 'Copied'}</span>
                        </>
                      ) : (
                        <>
                          <Copy className="w-3.5 h-3.5" />
                          <span>{isHi ? 'कॉपी' : 'Copy'}</span>
                        </>
                      )}
                    </button>
                  )}
                  <button
                    type="button"
                    onClick={() => void generateQrPairing()}
                    aria-label={isHi ? 'नया QR बनाएं' : 'Refresh QR'}
                    title={isHi ? 'नया QR बनाएं' : 'Refresh QR'}
                    className="min-h-[38px] min-w-[38px] rounded-full border border-[#C5A059]/65 bg-[#FFFDF8] dark:bg-[#091836] text-[#B84E00] dark:text-[#E4C788] hover:bg-[#FFF5E6] dark:hover:bg-[#152D59] flex items-center justify-center transition-colors cursor-pointer"
                  >
                    <RefreshCw className="w-4 h-4" />
                  </button>
                </div>
              </div>

              <div className="space-y-1.5">
                <div className="h-1.5 w-full rounded-full bg-[#EFE6D2] dark:bg-[#06132B] overflow-hidden">
                  <div
                    className="h-full bg-gradient-to-r from-[#D96B08] to-[#C5A059] transition-all duration-300"
                    style={{ width: `${qrTimerPct}%` }}
                  />
                </div>
                <div className="flex items-center justify-between text-[11px] font-mono tabular-nums text-[#6B5A3E] dark:text-[#93C5FD]">
                  <span className="truncate">
                    {settings.deviceName} · {platformLabel(platform)}
                  </span>
                  <span
                    className={
                      secondsLeft > 0
                        ? 'text-[#B84E00] dark:text-[#E4C788] font-semibold shrink-0'
                        : 'text-amber-600 dark:text-amber-400 font-semibold shrink-0'
                    }
                  >
                    {secondsLeft > 0
                      ? isHi
                        ? `${secondsLeft}s तक मान्य`
                        : `Valid ${secondsLeft}s`
                      : isHi
                        ? 'समय समाप्त · रीफ़्रेश करें'
                        : 'Expired · Refresh'}
                  </span>
                </div>
              </div>
            </div>
          </div>
        ) : panelMode === 'scan-qr' ? (
          /* Inline Rajasthani Heritage QR Scanner + Short Code View */
          <div className="relative z-10 my-auto flex flex-col gap-4 py-1">
            <div className="rounded-[24px] border border-[#C5A059]/60 dark:border-[#C5A059]/45 bg-white/95 dark:bg-[#0D2148]/95 p-4 space-y-3.5 shadow-xs">
              <div className="relative aspect-[4/3] max-h-[210px] w-full rounded-2xl bg-[#FAF6EC] dark:bg-[#06132B] border border-[#C5A059]/45 overflow-hidden flex items-center justify-center">
                <video
                  ref={videoRef}
                  muted
                  playsInline
                  className={`w-full h-full object-cover ${cameraActive ? 'block' : 'hidden'}`}
                />
                <canvas ref={canvasRef} className="hidden" />
                {!cameraActive && (
                  <div className="text-center p-4 space-y-1.5">
                    <ScanLine className="w-8 h-8 text-[#D96B08] dark:text-[#E4C788] mx-auto" />
                    <p className="text-xs font-medium text-[#6B5A3E] dark:text-[#93C5FD]">
                      {cameraError ||
                        (isHi ? 'QR स्कैन करने के लिए कैमरा खोलें' : 'Start camera to scan QR code')}
                    </p>
                  </div>
                )}
              </div>

              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
                  onClick={() => (cameraActive ? stopCamera() : void startCamera())}
                  className="flex-1 min-h-[40px] px-3.5 py-2 rounded-full bg-gradient-to-r from-[#D96B08] to-[#B84E00] border border-[#F5D08A]/75 text-white text-xs font-semibold inline-flex items-center justify-center gap-1.5 cursor-pointer"
                >
                  <Camera className="w-3.5 h-3.5" />
                  <span>
                    {cameraActive
                      ? isHi
                        ? 'कैमरा बंद करें'
                        : 'Stop Camera'
                      : isHi
                        ? 'कैमरा खोलें'
                        : 'Start Camera'}
                  </span>
                </button>
                <button
                  type="button"
                  onClick={() => qrImageRef.current?.click()}
                  className="min-h-[40px] px-3.5 py-2 rounded-full border border-[#C5A059]/60 text-xs font-semibold text-[#0A1F44] dark:text-[#E4C788] inline-flex items-center gap-1.5 cursor-pointer"
                >
                  <Upload className="w-3.5 h-3.5" />
                  <span>{isHi ? 'फ़ोटो चुनें' : 'QR Image'}</span>
                </button>
                <input
                  ref={qrImageRef}
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={(e) => {
                    handleQrImageUpload(e.target.files?.[0]);
                    e.target.value = '';
                  }}
                />
              </div>
            </div>

            {/* Enter Short Code */}
            <div className="rounded-[22px] border border-[#C5A059]/60 dark:border-[#C5A059]/45 bg-white/95 dark:bg-[#0D2148]/95 p-4 space-y-2.5 shadow-xs">
              <p className="text-xs font-semibold text-[#7A633C] dark:text-[#93C5FD]">
                {isHi ? 'या रिसीवर का कोड दर्ज करें' : 'Or enter code shown on receiver'}
              </p>
              <div className="flex gap-2">
                <input
                  type="text"
                  value={manualToken}
                  onChange={(e) => setManualToken(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' && manualToken.trim()) {
                      void handleDecodedPayload(manualToken);
                    }
                  }}
                  placeholder="VEG-XXXXXXXX"
                  className="flex-1 min-h-[40px] px-3.5 py-2 rounded-full border border-[#C5A059]/55 bg-[#FAF6EC] dark:bg-[#06132B] text-sm font-mono uppercase text-[#0A1F44] dark:text-white placeholder:text-[#6B5A3E]/60 focus:outline-none focus:border-[#D96B08]"
                />
                <button
                  type="button"
                  disabled={!manualToken.trim()}
                  onClick={() => void handleDecodedPayload(manualToken)}
                  className="min-h-[40px] px-4 rounded-full bg-gradient-to-r from-[#D96B08] to-[#B84E00] disabled:opacity-50 border border-[#F5D08A]/75 text-white text-xs font-semibold inline-flex items-center gap-1.5 cursor-pointer"
                >
                  <KeyRound className="w-3.5 h-3.5" />
                  <span>{isHi ? 'जुड़ें' : 'Connect'}</span>
                </button>
              </div>
              {scanResult && (
                <p
                  className={`text-xs font-medium ${
                    scanResult.ok
                      ? 'text-emerald-700 dark:text-emerald-400'
                      : 'text-amber-700 dark:text-amber-400'
                  }`}
                >
                  {scanResult.message}
                </p>
              )}
            </div>
          </div>
        ) : (
          /* Center Concentric Rajasthani Heritage Radar */
          <div className="relative z-10 my-auto flex items-center justify-center py-2">
            <div className="relative w-[272px] h-[272px] sm:w-[300px] sm:h-[300px] rounded-full overflow-hidden flex items-center justify-center select-none">
              {/* Concentric Mandana Radar Rings + Crosshairs */}
              <svg
                viewBox="0 0 300 300"
                aria-hidden="true"
                className="absolute inset-0 w-full h-full pointer-events-none"
              >
                <circle
                  cx="150"
                  cy="150"
                  r="142"
                  fill={isDark ? 'rgba(0, 77, 168, 0.14)' : 'rgba(255, 255, 255, 0.45)'}
                  stroke="#C5A059"
                  strokeOpacity={isDark ? '0.45' : '0.65'}
                  strokeWidth="1.2"
                />
                <circle
                  cx="150"
                  cy="150"
                  r="102"
                  fill="none"
                  stroke={isDark ? '#66B2FF' : '#8A651B'}
                  strokeOpacity="0.32"
                  strokeWidth="1"
                />
                <circle
                  cx="150"
                  cy="150"
                  r="62"
                  fill="none"
                  stroke="#C5A059"
                  strokeOpacity="0.55"
                  strokeWidth="1.2"
                  strokeDasharray="4 4"
                />
                {/* 4 Cardinal Crosshairs */}
                <line x1="150" y1="8" x2="150" y2="292" stroke="#C5A059" strokeOpacity="0.22" strokeWidth="1" />
                <line x1="8" y1="150" x2="292" y2="150" stroke="#C5A059" strokeOpacity="0.22" strokeWidth="1" />
                {/* 4 Rajasthani Kundan Gold Cardinal Dots */}
                <circle cx="150" cy="8" r="2.6" fill="#C5A059" />
                <circle cx="292" cy="150" r="2.6" fill="#C5A059" />
                <circle cx="150" cy="292" r="2.6" fill="#C5A059" />
                <circle cx="8" cy="150" r="2.6" fill="#C5A059" />
              </svg>

              {/* Rotating Saffron-Gold Radar Sweep Cone */}
              {animateRadar && (
                <motion.div
                  aria-hidden="true"
                  className="absolute inset-2 rounded-full pointer-events-none"
                  style={{
                    background:
                      'conic-gradient(from 0deg at 50% 50%, rgba(217, 107, 8, 0.42) 0deg, rgba(197, 160, 89, 0.16) 36deg, rgba(0, 0, 0, 0) 70deg, rgba(0, 0, 0, 0) 360deg)',
                  }}
                  animate={{ rotate: 360 }}
                  transition={{ repeat: Infinity, duration: 3.4, ease: 'linear' }}
                >
                  <div className="absolute left-1/2 top-0 -translate-x-1/2 w-[2px] h-1/2 bg-gradient-to-b from-[#E06D06] via-[#C5A059]/80 to-transparent" />
                </motion.div>
              )}

              {/* Center Saffron-Gold Core Button */}
              <button
                type="button"
                onClick={refreshDiscovery}
                aria-label={isHi ? 'फिर से खोजें' : 'Refresh search'}
                title={isHi ? 'फिर से खोजें' : 'Refresh search'}
                className="relative z-10 w-16 h-16 rounded-full bg-gradient-to-b from-[#E06D06] to-[#B84E00] border-2 border-[#F5D08A] text-white flex items-center justify-center shadow-[0_0_28px_rgba(200,90,0,0.45)] hover:scale-105 active:scale-95 transition-transform cursor-pointer"
              >
                {isSendTargetMode ? (
                  <ArrowUp className="w-7 h-7 stroke-[2.8]" />
                ) : (
                  <ArrowDown className="w-7 h-7 stroke-[2.8]" />
                )}
              </button>

              {/* Nearby Discovered Devices Plotted on Radar */}
              {peers.slice(0, 4).map((peer, idx) => {
                const angles = [-135, 35, -35, 135];
                const rad = ((angles[idx] ?? idx * 90) * Math.PI) / 180;
                const distPct = idx % 2 === 0 ? 31 : 34;
                const leftPct = 50 + Math.cos(rad) * distPct;
                const topPct = 50 + Math.sin(rad) * distPct;
                return (
                  <button
                    key={peer.peerId}
                    type="button"
                    onClick={() => void handleSelectPeer(peer)}
                    title={peer.deviceName}
                    style={{ left: `${leftPct}%`, top: `${topPct}%`, transform: 'translate(-50%, -50%)' }}
                    className="absolute z-20 w-11 h-11 rounded-full bg-[#FFFDF8]/95 dark:bg-[#0A1F44]/90 border-2 border-[#D96B08] dark:border-[#E07A1F] text-[#B84E00] dark:text-[#E4C788] flex items-center justify-center shadow-[0_6px_16px_rgba(200,90,0,0.28)] hover:scale-110 transition-transform cursor-pointer"
                  >
                    <ReceiveDeviceGlyph platform={peer.platform} className="w-5 h-5" />
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {/* Inline Incoming File Approval Card (Shown when sender sends a file) */}
        {pendingIncomingTransfer && (
          <div className="relative z-10 rounded-2xl border-2 border-[#C85A00] dark:border-[#E4C788] bg-white dark:bg-[#0D224A] p-4 space-y-3 shadow-lg">
            <div className="flex items-start gap-2.5">
              <ShieldAlert className="w-5 h-5 text-[#C85A00] dark:text-[#E4C788] shrink-0 mt-0.5" />
              <div className="min-w-0">
                <p className="text-sm font-bold text-[#0A1F44] dark:text-white truncate">
                  {pendingIncomingTransfer.fileName}
                </p>
                <p className="text-xs text-[#6B5A3E] dark:text-[#93C5FD]">
                  {pendingIncomingTransfer.senderName} · {formatBytes(pendingIncomingTransfer.fileSize)}
                </p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => void respondToIncomingTransfer(true)}
                className="flex-1 min-h-[40px] px-4 rounded-xl bg-gradient-to-r from-[#C85A00] to-[#B04A00] text-white text-xs font-semibold inline-flex items-center justify-center gap-1.5 cursor-pointer"
              >
                <CheckCircle2 className="w-4 h-4" />
                <span>{t.actions.approve}</span>
              </button>
              <button
                type="button"
                onClick={() => void respondToIncomingTransfer(false)}
                className="min-h-[40px] px-4 rounded-xl border border-[#C5A059]/55 text-xs font-medium text-[#0A1F44] dark:text-white inline-flex items-center justify-center gap-1.5 cursor-pointer"
              >
                <XCircle className="w-4 h-4" />
                <span>{t.actions.reject}</span>
              </button>
            </div>
          </div>
        )}

        {/* Active Transfer Progress (Shown when actively receiving) */}
        {activeReceives.length > 0 && (
          <div className="relative z-10">
            <TransferStatus jobs={activeReceives} compact />
          </div>
        )}

        {/* Bottom Card: Back to Radar CTA when QR/Scanner is shown, or Discovered Devices Nearby */}
        {panelMode !== 'radar' ? (
          <div className="relative z-10 pt-1">
            <button
              type="button"
              onClick={() => setPanelMode('radar')}
              className="w-full h-12 rounded-full bg-gradient-to-r from-[#C85A00] via-[#D96B08] to-[#B84E00] hover:from-[#B55000] hover:to-[#9E4100] text-white text-sm font-bold inline-flex items-center justify-center gap-2 border border-[#F5D08A]/80 shadow-[0_10px_26px_rgba(200,90,0,0.34)] transition-all cursor-pointer"
            >
              <Radar className="w-4 h-4 text-[#FFE7BA]" />
              <span>{isHi ? 'रडार पर वापस जाएं' : 'Back to Radar'}</span>
            </button>
          </div>
        ) : (
          <div className="relative z-10 rounded-[26px] border border-[#C5A059]/55 dark:border-[#C5A059]/35 bg-white/90 dark:bg-[#0D2148]/90 p-4 sm:p-5 space-y-3 shadow-xs">
            <h2 className="text-center font-heritage text-base sm:text-lg tracking-wide text-[#0A1F44] dark:text-white">
              {isHi ? 'नज़दीकी डिवाइस' : 'Discovered devices nearby'}
            </h2>

            {peers.length === 0 ? (
              <div className="py-3 text-center space-y-3">
                <p className="text-xs text-[#6B5A3E] dark:text-[#93C5FD]">
                  {isHi
                    ? 'समान Wi-Fi या हॉटस्पॉट पर डिवाइस खोजे जा रहे हैं...'
                    : 'Looking for devices on your Wi-Fi or hotspot...'}
                </p>
                <div className="flex items-center justify-center gap-2.5">
                  {isSendTargetMode ? (
                    <button
                      type="button"
                      onClick={() => setPanelMode('scan-qr')}
                      className="min-h-[38px] px-4 py-1.5 rounded-full bg-gradient-to-r from-[#C85A00] to-[#B04A00] border border-[#F5D08A]/75 text-white text-xs font-semibold inline-flex items-center gap-1.5 cursor-pointer"
                    >
                      <ScanLine className="w-3.5 h-3.5" />
                      <span>{isHi ? 'QR स्कैन करें' : 'Scan QR'}</span>
                    </button>
                  ) : (
                    <button
                      type="button"
                      onClick={handleOpenQr}
                      className="min-h-[38px] px-4 py-1.5 rounded-full bg-gradient-to-r from-[#C85A00] to-[#B04A00] border border-[#F5D08A]/75 text-white text-xs font-semibold inline-flex items-center gap-1.5 cursor-pointer"
                    >
                      <QrCode className="w-3.5 h-3.5" />
                      <span>{isHi ? 'मेरा QR कोड' : 'Show QR'}</span>
                    </button>
                  )}
                </div>
              </div>
            ) : (
              <div className="space-y-2.5">
                <div className="space-y-2 max-h-[210px] overflow-y-auto pr-0.5">
                  {peers.map((peer) => {
                    const isConnecting = connectingPeerId === peer.peerId;
                    return (
                      <button
                        key={peer.peerId}
                        type="button"
                        onClick={() => void handleSelectPeer(peer)}
                        className={`w-full rounded-2xl border px-3.5 py-3 flex items-center justify-between gap-3 text-left transition-colors cursor-pointer ${
                          isConnecting
                            ? 'border-[#C85A00] dark:border-[#E07A1F] bg-[#FFF5E6] dark:bg-[#1E1B24]/95'
                            : 'border-[#C5A059]/40 dark:border-[#1E3A6D] bg-[#FAF6EC] dark:bg-[#091836]/85 hover:border-[#C85A00] dark:hover:border-[#E4C788]'
                        }`}
                      >
                        <div className="flex items-center gap-3 min-w-0">
                          <span className="w-8 h-8 rounded-lg bg-[#FFF5E6] dark:bg-[#193366] border border-[#C5A059]/45 text-[#C85A00] dark:text-[#E4C788] flex items-center justify-center shrink-0">
                            <ReceiveDeviceGlyph platform={peer.platform} className="w-4 h-4" />
                          </span>
                          <span className="text-sm font-semibold text-[#0A1F44] dark:text-white truncate">
                            {peer.deviceName}
                          </span>
                        </div>

                        <span className="px-2.5 py-1 rounded-full bg-[#EFE8D6] dark:bg-[#152D59] text-[11px] font-medium text-[#5B4D38] dark:text-[#93C5FD] whitespace-nowrap shrink-0">
                          {isSendTargetMode
                            ? isHi
                              ? 'भेजें'
                              : 'Send'
                            : platformLabel(peer.platform)}
                        </span>
                      </button>
                    );
                  })}
                </div>
                <div className="flex justify-center pt-1">
                  {isSendTargetMode ? (
                    <button
                      type="button"
                      onClick={() => setPanelMode('scan-qr')}
                      className="min-h-[34px] px-3.5 py-1 rounded-full border border-[#C5A059]/55 text-[#B84E00] dark:text-[#E4C788] hover:bg-[#FFF5E6] dark:hover:bg-[#152D59] text-xs font-semibold inline-flex items-center gap-1.5 transition-colors cursor-pointer"
                    >
                      <ScanLine className="w-3.5 h-3.5" />
                      <span>{isHi ? 'QR स्कैन करें' : 'Scan QR'}</span>
                    </button>
                  ) : (
                    <button
                      type="button"
                      onClick={handleOpenQr}
                      className="min-h-[34px] px-3.5 py-1 rounded-full border border-[#C5A059]/55 text-[#B84E00] dark:text-[#E4C788] hover:bg-[#FFF5E6] dark:hover:bg-[#152D59] text-xs font-semibold inline-flex items-center gap-1.5 transition-colors cursor-pointer"
                    >
                      <QrCode className="w-3.5 h-3.5" />
                      <span>{isHi ? 'मेरा QR कोड' : 'Show QR'}</span>
                    </button>
                  )}
                </div>
              </div>
            )}
          </div>
        )}
      </section>
    </div>
  );
}
