import '../../l10n/vega_strings.dart';

/// All text of the approval screens, in English or Hindi.
class ApprovalStrings {
  const ApprovalStrings(this.s);
  final VegaStrings s;

  String get sendMode => s.t('Send', 'भेजें');
  String get receiveMode => s.t('Receive', 'प्राप्त करें');

  String receiverTitle(String sender) =>
      s.t('$sender wants to send you a file', '$sender आपको फ़ाइल भेजना चाहता है');
  String senderTitle(String receiver) =>
      s.t('Match the code on $receiver\'s phone', '$receiver के फ़ोन पर कोड मिलाइए');

  String get codeCaption =>
      s.t('Both phones must show this same code', 'दोनों फ़ोन पर यही कोड दिखना चाहिए');
  String get codeCaptionInfo => s.t('Match code (for information)', 'मैच कोड (सिर्फ़ जानकारी के लिए)');

  String get unverifiedTitle => s.t('Not linked by QR', 'यह डिवाइस QR से नहीं जुड़ा');
  String get unverifiedText => s.t(
      'Compare the code with the sender\'s phone, then tap Accept.',
      'कोड भेजने वाले के फ़ोन से मिलाइए, तभी Accept दबाइए।');
  String get verifiedTitle => s.t('Recognised by QR', 'QR से पहचाना गया');
  String get verifiedText => s.t(
      'This is the device whose QR you scanned. No need to compare the code.',
      'यह वही डिवाइस है जिसका QR आपने स्कैन किया। कोड मिलाना ज़रूरी नहीं।');
  String get plaintextTitle => s.t('This transfer is not encrypted', 'यह ट्रांसफ़र एन्क्रिप्टेड नहीं है');
  String get plaintextText => s.t(
      'Anyone on the network can see the file. Accept only from a device you trust.',
      'रास्ते में कोई भी फ़ाइल देख सकता है। सिर्फ़ भरोसेमंद डिवाइस से Accept करें।');
  String get waitingTitle => s.t('Waiting for a reply', 'जवाब का इंतज़ार');
  String get waitingText => s.t(
      'The transfer starts the moment the receiver taps Accept.',
      'रिसीवर के Accept दबाते ही ट्रांसफ़र तुरंत शुरू होगा।');
  String get waitingVerifiedText => s.t(
      'Recognised by QR. The transfer starts the moment they tap Accept.',
      'QR से पहचाना गया। Accept दबते ही ट्रांसफ़र तुरंत शुरू होगा।');

  String get acceptAfterMatch => s.t('Code matches, Accept', 'कोड मिल गया, Accept');
  String get accept => s.t('Accept', 'Accept');
  String get reject => s.t('Reject', 'अस्वीकार करें');
  String get cancelMismatch => s.t('Code differs, Cancel', 'कोड अलग है, रद्द करें');

  String get linkEncrypted => s.t('Wi-Fi · encrypted', 'Wi-Fi · एन्क्रिप्टेड');
  String get linkPlain => s.t('Wi-Fi · not encrypted', 'Wi-Fi · एन्क्रिप्टेड नहीं');

  String autoReject(int seconds) =>
      s.t('Auto-rejects in $seconds s', '$seconds सेकंड में अपने आप अस्वीकार हो जाएगा');
  String get you => s.t('You', 'आप');
}
