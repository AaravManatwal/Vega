import React, { useEffect, useState } from 'react';
import {
  ArrowDownLeft,
  ArrowUpRight,
  CheckCircle2,
  FolderOpen,
  HelpCircle,
  History,
  LayoutDashboard,
  Settings,
  X,
  XCircle,
} from 'lucide-react';
import { useVega } from '../context/VegaContext.tsx';
import { formatBytes, platformLabel } from '../lib/formatters.ts';
import type { ScreenId } from '../types/vega.ts';
import { VegaLogo } from './graphics/VegaGraphics.tsx';
import { TransferDashboard } from './Dashboard.tsx';
import { FileManager } from './FileManager.tsx';
import { TransferHistory } from './TransferHistory.tsx';
import { SendFilesScreen, ReceiveFilesScreen } from './screens/SendReceiveScreens.tsx';
import { HelpAndAuditScreen } from './screens/SettingsAboutHelpScreens.tsx';
import { Settings as SettingsView } from './Settings.tsx';
import { TransferDetailsScreen, TransferProgressScreen } from './screens/TransferScreens.tsx';
import { ToastContainer } from './ToastContainer.tsx';

export function AppShell() {
  const {
    screen,
    setScreen,
    clearPreselectedSendFiles,
    settings,
    t,
    transfers,
    incomingPairingRequest,
    respondToPairingRequest,
    pendingIncomingTransfer,
    respondToIncomingTransfer,
    toasts,
    dismissToast,
  } = useVega();

  const [mobileNavOpen, setMobileNavOpen] = useState(false);

  useEffect(() => {
    window.scrollTo({ top: 0, behavior: 'auto' });
  }, [screen]);

  useEffect(() => {
    if (!mobileNavOpen) return;
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setMobileNavOpen(false);
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [mobileNavOpen]);

  const activeTransferCount = transfers.filter(
    (tr) => tr.status === 'transferring' || tr.status === 'encrypting' || tr.status === 'verifying'
  ).length;

  const isHi = settings.language === 'hi';

  const navGroups: Array<{
    group: string;
    items: Array<{ id: ScreenId; label: string; icon: React.ComponentType<{ className?: string }>; count?: number }>;
  }> = [
    {
      group: isHi ? 'फ़ाइल शेयरिंग' : 'File Sharing',
      items: [
        { id: 'dashboard', label: t.nav.dashboard, icon: LayoutDashboard },
        { id: 'send', label: t.nav.send, icon: ArrowUpRight },
        { id: 'receive', label: t.nav.receive, icon: ArrowDownLeft },
      ],
    },
    {
      group: isHi ? 'फ़ाइलें और सेटिंग्स' : 'Files & Settings',
      items: [
        { id: 'file-manager', label: t.nav.fileManager, icon: FolderOpen },
        { id: 'transfer-history', label: t.nav.history, icon: History, count: activeTransferCount },
        { id: 'settings', label: t.nav.settings, icon: Settings },
        { id: 'help', label: isHi ? 'सहायता' : 'Help & Guide', icon: HelpCircle },
      ],
    },
  ];

  const navigate = (id: ScreenId) => {
    if (id === 'receive') {
      clearPreselectedSendFiles();
    }
    setScreen(id);
    setMobileNavOpen(false);
  };

  const renderScreen = () => {
    switch (screen) {
      case 'dashboard':
        return <TransferDashboard onOpenMenu={() => setMobileNavOpen(true)} />;
      case 'send':
        return <SendFilesScreen onOpenMenu={() => setMobileNavOpen(true)} />;
      case 'receive':
      case 'discovery':
      case 'qr-scanner':
      case 'qr-generator':
      case 'pairing':
        return <ReceiveFilesScreen onOpenMenu={() => setMobileNavOpen(true)} />;
      case 'file-manager':
        return <FileManager />;
      case 'transfer-progress':
        return <TransferProgressScreen />;
      case 'transfer-details':
        return <TransferDetailsScreen />;
      case 'transfer-history':
        return <TransferHistory />;
      case 'settings':
        return <SettingsView />;
      case 'help':
        return <HelpAndAuditScreen />;
      default:
        return <TransferDashboard onOpenMenu={() => setMobileNavOpen(true)} />;
    }
  };

  const sidebarContent = (
    <div className="h-full flex flex-col bg-[#FFFDF8] dark:bg-[#0A1F44] border-r border-[#C5A059]/40 dark:border-[#C5A059]/30 bg-rajasthani-jali-light dark:bg-rajasthani-jali">
      <div className="px-5 py-4 border-b border-[#C5A059]/35 dark:border-[#C5A059]/30 flex items-center justify-between">
        <button
          onClick={() => navigate('dashboard')}
          className="flex items-center gap-3 text-left cursor-pointer rounded-xl p-1 -ml-1 hover:bg-[#EFEAD8]/60 dark:hover:bg-[#003366]/45 transition-colors"
        >
          <VegaLogo size={36} />
          <div>
            <p className="text-base font-bold tracking-wide text-[#0A1F44] dark:text-white leading-none font-heritage">
              {t.appName}
            </p>
            <p className="mt-1 text-[11px] font-medium text-[#6B5A3E] dark:text-[#E4C788]/90 leading-none">
              {t.appNativeName} · {isHi ? 'ऑफ़लाइन शेयरिंग' : 'Offline Sharing'}
            </p>
          </div>
        </button>
        <button
          onClick={() => setMobileNavOpen(false)}
          aria-label="Close menu"
          className="lg:hidden min-h-[44px] min-w-[44px] flex items-center justify-center rounded-xl text-[#5B4D38] hover:text-[#0A1F44] dark:text-[#E4C788] dark:hover:text-white"
        >
          <X className="w-5 h-5" />
        </button>
      </div>

      <nav className="flex-1 overflow-y-auto px-3 py-4 space-y-5">
        {navGroups.map((group) => (
          <div key={group.group} className="space-y-1">
            <p className="px-3 text-[11px] font-semibold tracking-wide text-[#7A633C] dark:text-[#C5A059]">
              {group.group}
            </p>
            {group.items.map((item) => {
              const Icon = item.icon;
              const active =
                screen === item.id ||
                (item.id === 'receive' &&
                  (screen === 'discovery' ||
                    screen === 'qr-scanner' ||
                    screen === 'qr-generator' ||
                    screen === 'pairing')) ||
                (item.id === 'transfer-history' && (screen === 'transfer-progress' || screen === 'transfer-details'));
              return (
                <button
                  key={item.id}
                  onClick={() => navigate(item.id)}
                  className={`relative w-full min-h-[40px] px-3 py-2 rounded-xl text-xs font-medium flex items-center justify-between gap-2 transition-all duration-150 cursor-pointer ${
                    active
                      ? 'bg-gradient-to-r from-[#C85A00] via-[#D96B08] to-[#B84E00] text-white border border-[#F5D08A]/75 shadow-sm'
                      : 'text-[#1E293B] dark:text-[#DBEAFE] hover:bg-[#EFEAD8]/80 dark:hover:bg-[#003366]/65'
                  }`}
                >
                  <span className="flex items-center gap-2.5 min-w-0 truncate">
                    <Icon className={`w-4 h-4 shrink-0 ${active ? 'text-[#E4C788]' : ''}`} />
                    <span className="truncate">{item.label}</span>
                  </span>
                  {typeof item.count === 'number' && item.count > 0 && (
                    <span
                      className={`font-mono tabular-nums text-[11px] font-semibold ${
                        active ? 'text-[#E4C788] dark:text-white' : 'text-[#007AFF] dark:text-[#E4C788]'
                      }`}
                    >
                      {item.count}
                    </span>
                  )}
                </button>
              );
            })}
          </div>
        ))}
      </nav>

      <div className="p-4 border-t border-[#C5A059]/35 dark:border-[#C5A059]/30 text-[11px] text-[#5B4D38] dark:text-[#DBEAFE]/80">
        <p className="font-semibold text-[#0A1F44] dark:text-white">{t.appName} ({t.appNativeName})</p>
        <p className="mt-0.5">{t.tagline}</p>
      </div>
    </div>
  );

  return (
    <div className="min-h-screen overflow-x-clip flex bg-[#F6F4EE] dark:bg-[#06132B] text-[#0A1F44] dark:text-white bg-rajasthani-jali-light dark:bg-rajasthani-jali">
      <ToastContainer toasts={toasts} onDismiss={dismissToast} />
      {/* Desktop Sidebar */}
      <aside className="hidden lg:block w-[252px] shrink-0 sticky top-0 h-screen">
        {sidebarContent}
      </aside>

      {/* Mobile Drawer */}
      {mobileNavOpen && (
        <div className="fixed inset-0 z-50 lg:hidden flex">
          <div className="w-[272px] h-full">{sidebarContent}</div>
          <div onClick={() => setMobileNavOpen(false)} className="flex-1 bg-black/50" />
        </div>
      )}

      {/* Main Content Area */}
      <div className="flex-1 min-w-0 flex flex-col">
        {/* Global Explicit Pairing Approval Dialog */}
        {incomingPairingRequest && (
          <div className="mx-4 md:mx-6 mt-4 rounded-2xl border border-[#C5A059]/75 bg-[#FFFDF8] dark:bg-[#0D2148] p-4 shadow-md flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <p className="text-sm font-semibold text-[#0A1F44] dark:text-white">
                {isHi
                  ? `${incomingPairingRequest.fromDeviceName} (${platformLabel(incomingPairingRequest.fromPlatform)}) से जुड़ने का अनुरोध`
                  : `Connection Request from ${incomingPairingRequest.fromDeviceName} (${platformLabel(incomingPairingRequest.fromPlatform)})`}
              </p>
              <p className="text-xs text-[#6B5A3E] dark:text-[#93C5FD]">
                {isHi
                  ? 'फ़ाइलें साझा करने के लिए अनुमति दें'
                  : 'Approve to connect and share files with this device'}
              </p>
            </div>
            <div className="flex items-center gap-2 shrink-0">
              <button
                onClick={() => void respondToPairingRequest(true)}
                className="min-h-[40px] px-4 py-2 rounded-full bg-gradient-to-r from-[#C85A00] via-[#D96B08] to-[#B84E00] border border-[#F5D08A]/75 text-white text-xs font-semibold inline-flex items-center gap-1.5 whitespace-nowrap cursor-pointer"
              >
                <CheckCircle2 className="w-3.5 h-3.5" />
                <span>{t.actions.approve}</span>
              </button>
              <button
                onClick={() => void respondToPairingRequest(false)}
                className="min-h-[40px] px-4 py-2 rounded-full border border-[#C5A059]/50 dark:border-[#1B3154] text-[#0A1F44] dark:text-white text-xs font-medium inline-flex items-center gap-1.5 whitespace-nowrap cursor-pointer"
              >
                <XCircle className="w-3.5 h-3.5" />
                <span>{t.actions.reject}</span>
              </button>
            </div>
          </div>
        )}

        {/* Global Incoming File Approval Banner */}
        {pendingIncomingTransfer && screen !== 'receive' && (
          <div className="mx-4 md:mx-6 mt-4 rounded-2xl border border-[#C5A059]/75 bg-[#FFFDF8] dark:bg-[#0D2148] p-4 shadow-md flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <p className="text-sm font-semibold text-[#0A1F44] dark:text-white">
                {isHi ? 'आने वाली फ़ाइल: ' : 'Incoming File: '}
                {pendingIncomingTransfer.fileName} ({formatBytes(pendingIncomingTransfer.fileSize)})
              </p>
              <p className="text-xs text-[#6B5A3E] dark:text-[#93C5FD]">
                {isHi
                  ? `${pendingIncomingTransfer.senderName} से · प्राप्त करने के लिए तैयार`
                  : `From ${pendingIncomingTransfer.senderName} · Ready to receive`}
              </p>
            </div>
            <div className="flex items-center gap-2 shrink-0">
              <button
                onClick={() => {
                  void respondToIncomingTransfer(true);
                  setScreen('transfer-progress');
                }}
                className="min-h-[40px] px-4 py-2 rounded-full bg-gradient-to-r from-[#C85A00] via-[#D96B08] to-[#B84E00] border border-[#F5D08A]/75 text-white text-xs font-semibold whitespace-nowrap cursor-pointer"
              >
                {isHi ? 'स्वीकार करें' : 'Accept & Receive'}
              </button>
              <button
                onClick={() => void respondToIncomingTransfer(false)}
                className="min-h-[40px] px-4 py-2 rounded-full border border-[#C5A059]/50 dark:border-[#1B3154] text-[#0A1F44] dark:text-white text-xs font-medium whitespace-nowrap cursor-pointer"
              >
                {isHi ? 'अस्वीकार' : 'Reject'}
              </button>
            </div>
          </div>
        )}

        <main className="flex-1 max-w-[1320px] w-full mx-auto p-0 sm:p-6 lg:p-8">
          <div className="w-full">{renderScreen()}</div>
        </main>
      </div>
    </div>
  );
}
