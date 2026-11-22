import React from 'react';
import { HelpCircle, QrCode } from 'lucide-react';
import { useVega } from '../../context/VegaContext.tsx';
import { HeritageScreenCard } from '../HeritageScreenCard.tsx';

export function HelpAndAuditScreen() {
  const { settings, setScreen, clearPreselectedSendFiles } = useVega();
  const isHi = settings.language === 'hi';

  const quickSteps = [
    {
      step: '1',
      title: isHi ? 'एक ही Wi-Fi या हॉटस्पॉट से जुड़ें' : 'Connect to Same Wi-Fi or Hotspot',
      desc: isHi
        ? 'दोनों डिवाइस (फ़ोन या कंप्यूटर) को एक ही वाई-फ़ाई या मोबाइल हॉटस्पॉट से जोड़ें। इंटरनेट की ज़रूरत नहीं है।'
        : 'Connect both devices to the same Wi-Fi or mobile hotspot. Internet is not required.',
    },
    {
      step: '2',
      title: isHi ? 'QR स्कैन करें या डिवाइस चुनें' : 'Scan QR or Pick Device',
      desc: isHi
        ? 'Receive स्क्रीन पर दिखने वाला QR कोड स्कैन करें, छोटा कोड (VEG-XXXX) डालें, या नज़दीकी डिवाइस चुनें।'
        : 'Scan the QR code on the Receive screen, enter the short code (VEG-XXXX), or pick a nearby device.',
    },
    {
      step: '3',
      title: isHi ? 'फ़ाइलें चुनें और भेजें' : 'Choose Files & Send',
      desc: isHi
        ? 'कोई भी फ़ाइल चुनें और भेजें। दूसरे डिवाइस पर स्वीकार करते ही फ़ाइल तुरंत सेव हो जाएगी।'
        : 'Pick your files and tap Send. Once accepted, they save straight to the other device.',
    },
  ];

  const commonQuestions = [
    {
      title: isHi ? 'दूसरा डिवाइस नहीं दिख रहा?' : 'Device Not Showing Up?',
      action: isHi
        ? 'देखें कि दोनों डिवाइस एक ही Wi-Fi या हॉटस्पॉट पर हैं, या सीधे QR कोड स्कैन करें।'
        : 'Make sure both devices are on the same Wi-Fi or hotspot, or scan the QR code directly.',
    },
    {
      title: isHi ? 'QR कोड या कोड काम नहीं कर रहा?' : 'QR or Code Expired?',
      action: isHi
        ? 'सुरक्षा के लिए कोड कुछ समय बाद बदल जाता है। नया कोड पाने के लिए रिफ़्रेश दबाएं।'
        : 'Codes expire after a short time for safety. Tap Refresh on the Receive screen for a new one.',
    },
    {
      title: isHi ? 'कैमरा उपलब्ध नहीं है?' : 'Camera Not Available?',
      action: isHi
        ? 'अगर कैमरा काम न करे, तो QR के नीचे दिया गया छोटा कोड (VEG-XXXX) टाइप करके जुड़ें।'
        : 'If camera access is off, type the short code (VEG-XXXX) shown below the QR code.',
    },
    {
      title: isHi ? 'प्राप्त फ़ाइलें कहां मिलेंगी?' : 'Where Are Received Files Saved?',
      action: isHi
        ? 'प्राप्त फ़ाइलें आपके डाउनलोड फ़ोल्डर और ऐप के "फ़ाइलें" सेक्शन में मिल जाएंगी।'
        : 'Received files go to your Downloads folder and also appear inside the Files tab.',
    },
  ];

  return (
    <HeritageScreenCard
      title={isHi ? 'कैसे उपयोग करें' : 'How It Works'}
      subtitle={isHi ? 'ऑफ़लाइन फ़ाइल शेयरिंग के आसान चरण' : 'Simple steps for offline file sharing'}
      onBack={() => setScreen('dashboard')}
      backLabel={isHi ? 'वापस जाएं' : 'Back'}
      rightAction={
        <button
          type="button"
          onClick={() => {
            clearPreselectedSendFiles();
            setScreen('receive');
          }}
          className="min-h-[38px] px-3.5 py-1.5 rounded-full bg-gradient-to-r from-[#C85A00] to-[#B84E00] border border-[#F5D08A]/75 text-white text-xs font-semibold inline-flex items-center gap-1.5 whitespace-nowrap cursor-pointer"
        >
          <QrCode className="w-3.5 h-3.5" />
          <span>{isHi ? 'प्राप्त व QR' : 'Receive & QR'}</span>
        </button>
      }
    >
      {/* 3-Step Guide */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        {quickSteps.map((item) => (
          <div
            key={item.step}
            className="rounded-[22px] border border-[#C5A059]/45 dark:border-[#C5A059]/30 bg-white/90 dark:bg-[#0D2148]/90 p-4 space-y-2 shadow-xs"
          >
            <span className="inline-flex items-center justify-center w-7 h-7 rounded-full bg-gradient-to-br from-[#D96B08] to-[#B84E00] border border-[#F5D08A]/75 text-xs font-bold text-white">
              {item.step}
            </span>
            <h2 className="text-sm font-bold text-[#0A1F44] dark:text-white leading-snug">{item.title}</h2>
            <p className="text-xs text-[#6B5A3E] dark:text-[#DBEAFE]/85 leading-relaxed">
              {item.desc}
            </p>
          </div>
        ))}
      </div>

      {/* Common Questions */}
      <div className="rounded-[24px] border border-[#C5A059]/45 dark:border-[#C5A059]/30 bg-white/90 dark:bg-[#0D2148]/90 p-5 space-y-3.5 shadow-xs">
        <h2 className="text-base font-bold text-[#0A1F44] dark:text-white font-heritage">
          {isHi ? 'सामान्य प्रश्न' : 'Common Questions'}
        </h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {commonQuestions.map((g) => (
            <div
              key={g.title}
              className="rounded-2xl border border-[#C5A059]/35 dark:border-[#1B3154] bg-[#FAF6EC] dark:bg-[#06132B] p-3.5 space-y-1.5"
            >
              <div className="flex items-center gap-2">
                <HelpCircle className="w-4 h-4 text-[#D96B08] dark:text-[#E4C788] shrink-0" />
                <h3 className="text-xs font-semibold text-[#0A1F44] dark:text-white">{g.title}</h3>
              </div>
              <p className="text-xs text-[#6B5A3E] dark:text-[#DBEAFE]/85 leading-relaxed">
                {g.action}
              </p>
            </div>
          ))}
        </div>
      </div>
    </HeritageScreenCard>
  );
}
