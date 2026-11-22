/// All text of the approval screens in one place (easy to change or localize).
class ApprovalStrings {
  static const receiveMode = 'Receive';
  static const sendMode = 'Send';

  static String receiverTitle(String sender) => '$sender file bhejna chahta hai';
  static String senderTitle(String receiver) => '$receiver ke phone se code milaiye';

  static const codeCaption = 'Dono phone par yahi code dikhna chahiye';
  static const codeCaptionInfo = 'Match code (sirf jaankari ke liye)';

  static const unverifiedTitle = 'Ye device QR se nahi juda';
  static const unverifiedText =
      'Code bhejne wale ke phone se milaiye, tabhi Accept dabaiye.';
  static const verifiedTitle = 'QR se pehchaana gaya';
  static const verifiedText =
      'Yahi wo device hai jiska QR aapne scan kiya. Code milana zaroori nahi.';
  static const plaintextTitle = 'Ye transfer encrypted nahi hai';
  static const plaintextText =
      'Raste me koi bhi file dekh sakta hai. Sirf bharose ke device se Accept kijiye.';
  static const waitingTitle = 'Jawab ka intezaar';
  static const waitingText = 'Receiver ke phone par Accept dabte hi transfer turant shuru hoga.';
  static const waitingVerifiedText =
      'QR se pehchaana gaya. Accept dabte hi transfer turant shuru hoga.';

  static const acceptAfterMatch = 'Code mil gaya, Accept';
  static const accept = 'Accept';
  static const reject = 'Reject';
  static const cancelMismatch = 'Code alag hai, Cancel';

  static const linkEncrypted = 'Wi-Fi · encrypted';
  static const linkPlain = 'Wi-Fi · not encrypted';

  static String autoReject(int seconds) => '$seconds s me apne aap reject ho jayega';
  static const you = 'Aap';
}
