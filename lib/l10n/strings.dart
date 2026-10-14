import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/errors.dart';
import '../state/providers.dart' show RunStatus;

/// All user-facing text in English, Hindi and Marathi. Use `S.of(context)`.
class S {
  const S(this.code);

  final String code;

  static const languages = {'en': 'English', 'hi': 'हिंदी', 'mr': 'मराठी'};
  static const delegate = _SDelegate();

  static S of(BuildContext context) => Localizations.of<S>(context, S) ?? const S('en');

  String _t(String en, String hi, String mr) => switch (code) {
        'hi' => hi,
        'mr' => mr,
        _ => en,
      };

  // ---- Home --------------------------------------------------------------------------------
  String get pasteHint => _t('Paste Instagram reel link', 'Instagram रील लिंक यहाँ पेस्ट करें', 'Instagram रील लिंक इथे पेस्ट करा');
  String get publicOnlyHelper => _t('Only reels from public accounts can be downloaded',
      'केवल पब्लिक अकाउंट की रील डाउनलोड हो सकती हैं', 'फक्त पब्लिक अकाउंटच्या रील डाउनलोड करता येतात');
  String get paste => _t('Paste', 'पेस्ट करें', 'पेस्ट करा');
  String get clear => _t('Clear', 'हटाएँ', 'काढा');
  String get download => _t('Download', 'डाउनलोड', 'डाउनलोड');
  String get downloads => _t('Downloads', 'डाउनलोड्स', 'डाउनलोड्स');
  String get settings => _t('Settings', 'सेटिंग्स', 'सेटिंग्ज');
  String get cancel => _t('Cancel', 'रद्द करें', 'रद्द करा');
  String get clipboardEmpty => _t('Clipboard is empty. Copy a reel link in Instagram first.',
      'क्लिपबोर्ड खाली है। पहले Instagram में रील लिंक कॉपी करें।', 'क्लिपबोर्ड रिकामा आहे. आधी Instagram मध्ये रील लिंक कॉपी करा.');
  String get savedSnack => _t('Saved to Download/PrettySaver', 'Download/PrettySaver में सेव हो गया',
      'Download/PrettySaver मध्ये सेव्ह झाले');
  String savedFrom(String uploader) =>
      _t('Saved @$uploader', '@$uploader की रील सेव हो गई', '@$uploader ची रील सेव्ह झाली');
  String videosSaved(int n) => _t('$n videos saved', '$n वीडियो सेव हुए', '$n व्हिडिओ सेव्ह झाले');
  String get signInInstagram => _t('Sign in to Instagram', 'Instagram में साइन इन करें', 'Instagram मध्ये साइन इन करा');
  String get details => _t('Details', 'विवरण', 'तपशील');
  String get copy => _t('Copy', 'कॉपी करें', 'कॉपी करा');
  String get detailsCopied => _t('Error details copied', 'त्रुटि विवरण कॉपी हुआ', 'त्रुटीचा तपशील कॉपी झाला');

  String status(RunStatus status) => switch (status) {
        RunStatus.preparing => _t('Preparing download engine…', 'डाउनलोड इंजन तैयार हो रहा है…', 'डाउनलोड इंजिन तयार होत आहे…'),
        RunStatus.updating => _t('Updating download engine…', 'डाउनलोड इंजन अपडेट हो रहा है…', 'डाउनलोड इंजिन अपडेट होत आहे…'),
        RunStatus.fetching => _t('Fetching reel…', 'रील लाई जा रही है…', 'रील आणली जात आहे…'),
        RunStatus.downloading => _t('Downloading…', 'डाउनलोड हो रहा है…', 'डाउनलोड होत आहे…'),
        RunStatus.merging => _t('Merging video + audio…', 'वीडियो और ऑडियो जोड़े जा रहे हैं…', 'व्हिडिओ आणि ऑडिओ जोडले जात आहेत…'),
      };

  // ---- Problems ----------------------------------------------------------------------------
  String get _copySteps => _t('Open a reel from a public account, tap Share → Copy link, and paste it here.',
      'किसी पब्लिक अकाउंट की रील खोलें, Share → Copy link दबाएँ और यहाँ पेस्ट करें।',
      'पब्लिक अकाउंटची रील उघडा, Share → Copy link दाबा आणि इथे पेस्ट करा.');

  String problem(Problem problem) => switch (problem) {
        Problem.notInstagram =>
          '${_t('This isn\'t an Instagram link.', 'यह Instagram लिंक नहीं है।', 'ही Instagram लिंक नाही.')}\n\n$_copySteps',
        Problem.notReel => '${_t('This isn\'t a reel link.', 'यह रील का लिंक नहीं है।', 'ही रीलची लिंक नाही.')}\n\n$_copySteps',
        Problem.unsupported =>
          '${_t('This link isn\'t supported.', 'यह लिंक सपोर्टेड नहीं है।', 'ही लिंक सपोर्टेड नाही.')}\n\n$_copySteps',
        Problem.publicOnly => '${_t('Couldn\'t download this reel.', 'यह रील डाउनलोड नहीं हो सकी।', 'ही रील डाउनलोड झाली नाही.')}\n\n'
            '${_t('Only reels from public accounts can be downloaded.', 'केवल पब्लिक अकाउंट की रील डाउनलोड हो सकती हैं।', 'फक्त पब्लिक अकाउंटच्या रील डाउनलोड करता येतात.')} '
            '$_copySteps',
        Problem.needsSignIn => '${this.problem(Problem.publicOnly)}\n\n'
            '${_t('Already from a public account? Instagram sometimes asks for a one-time sign-in. Tap below and the download will retry automatically.', 'अकाउंट पब्लिक है? Instagram कभी-कभी एक बार साइन इन माँगता है। नीचे टैप करें, डाउनलोड अपने-आप दोबारा शुरू होगा।', 'अकाउंट पब्लिक आहे? Instagram कधी कधी एकदा साइन इन मागते. खाली टॅप करा, डाउनलोड आपोआप पुन्हा सुरू होईल.')}',
        Problem.noInternet => _t('No internet connection.\n\nCheck your Wi-Fi or mobile data and try again.',
            'इंटरनेट कनेक्शन नहीं है।\n\nअपना Wi-Fi या मोबाइल डेटा जाँचें और फिर कोशिश करें।',
            'इंटरनेट कनेक्शन नाही.\n\nतुमचे Wi-Fi किंवा मोबाइल डेटा तपासा आणि पुन्हा प्रयत्न करा.'),
        Problem.noSpace => _t('Your phone is out of storage.\n\nFree up some space and try again.',
            'फ़ोन की स्टोरेज भर गई है।\n\nकुछ जगह खाली करें और फिर कोशिश करें।',
            'फोनची स्टोरेज भरली आहे.\n\nथोडी जागा मोकळी करा आणि पुन्हा प्रयत्न करा.'),
        Problem.cancelled => _t('Download cancelled.', 'डाउनलोड रद्द किया गया।', 'डाउनलोड रद्द केले.'),
        Problem.noVideo => _t('This post has no video.\n\nPaste the link of a reel or video post from a public account.',
            'इस पोस्ट में वीडियो नहीं है।\n\nकिसी पब्लिक अकाउंट की रील या वीडियो पोस्ट का लिंक पेस्ट करें।',
            'या पोस्टमध्ये व्हिडिओ नाही.\n\nपब्लिक अकाउंटच्या रील किंवा व्हिडिओ पोस्टची लिंक पेस्ट करा.'),
        Problem.busy => _t('Instagram is busy right now.\n\nWait a few minutes and try again.',
            'Instagram अभी व्यस्त है।\n\nकुछ मिनट रुककर फिर कोशिश करें।',
            'Instagram सध्या व्यस्त आहे.\n\nकाही मिनिटे थांबून पुन्हा प्रयत्न करा.'),
        Problem.storagePermission => _t('Storage permission is needed to save videos.',
            'वीडियो सेव करने के लिए स्टोरेज अनुमति चाहिए।', 'व्हिडिओ सेव्ह करण्यासाठी स्टोरेज परवानगी लागते.'),
      };

  // ---- How-to guide ------------------------------------------------------------------------
  String get howToTitle => _t('How to download', 'डाउनलोड कैसे करें', 'डाउनलोड कसे करावे');
  String get step1Title => _t('Open a reel from a public account', 'किसी पब्लिक अकाउंट की रील खोलें', 'पब्लिक अकाउंटची रील उघडा');
  String get step1Body => _t(
      'Public accounts have no 🔒 lock next to their name. Reels from private accounts can\'t be downloaded.',
      'पब्लिक अकाउंट के नाम के पास 🔒 लॉक नहीं होता। प्राइवेट अकाउंट की रील डाउनलोड नहीं हो सकती।',
      'पब्लिक अकाउंटच्या नावाजवळ 🔒 लॉक नसते. प्रायव्हेट अकाउंटच्या रील डाउनलोड करता येत नाहीत.');
  String get step2Title => _t('Tap Share, then Copy link', 'Share दबाएँ, फिर Copy link', 'Share दाबा, मग Copy link');
  String get step2Body => _t('Or tap Share → Pretty Saver to start the download straight away.',
      'या Share → Pretty Saver दबाएँ, डाउनलोड तुरंत शुरू होगा।', 'किंवा Share → Pretty Saver दाबा, डाउनलोड लगेच सुरू होईल.');
  String get step3Title => _t('Come back and tap Download', 'वापस आएँ और Download दबाएँ', 'परत या आणि Download दाबा');
  String get step3Body => _t('The copied link is pasted for you. The video is saved to your gallery.',
      'कॉपी किया लिंक अपने-आप पेस्ट हो जाता है। वीडियो आपकी गैलरी में सेव होता है।',
      'कॉपी केलेली लिंक आपोआप पेस्ट होते. व्हिडिओ तुमच्या गॅलरीत सेव्ह होतो.');

  // ---- Settings ----------------------------------------------------------------------------
  String get appearance => _t('Appearance', 'दिखावट', 'दिसणे');
  String get language => _t('Language', 'भाषा', 'भाषा');
  String get themeSystem => _t('System', 'सिस्टम', 'सिस्टम');
  String get themeLight => _t('Light', 'लाइट', 'लाइट');
  String get themeDark => _t('Dark', 'डार्क', 'डार्क');
  String get font => _t('Font', 'फ़ॉन्ट', 'फॉन्ट');
  String get fontDefault => _t('Default', 'डिफ़ॉल्ट', 'डीफॉल्ट');
  String get textSize => _t('Text size', 'टेक्स्ट साइज़', 'अक्षरांचा आकार');
  String get small => _t('Small', 'छोटा', 'लहान');
  String get normal => _t('Normal', 'सामान्य', 'सामान्य');
  String get large => _t('Large', 'बड़ा', 'मोठा');
  String get signedIn => _t('Signed in', 'साइन इन है', 'साइन इन केले आहे');
  String get signOut => _t('Sign out', 'साइन आउट', 'साइन आउट');
  String get signOutHint => _t('Tap Sign out to remove your login', 'लॉगिन हटाने के लिए साइन आउट दबाएँ',
      'लॉगिन काढण्यासाठी साइन आउट दाबा');
  String get fixProblems => _t('Fix download problems', 'डाउनलोड की समस्या ठीक करें', 'डाउनलोडची समस्या दूर करा');
  String get fixProblemsSub => _t('Updates the downloader', 'डाउनलोडर अपडेट करता है', 'डाउनलोडर अपडेट करते');
  String get upToDate => _t('Downloader is up to date', 'डाउनलोडर अप टू डेट है', 'डाउनलोडर अद्ययावत आहे');
  String get updateFailed => _t('Couldn\'t update. Check your internet connection.',
      'अपडेट नहीं हो सका। इंटरनेट कनेक्शन जाँचें।', 'अपडेट झाले नाही. इंटरनेट कनेक्शन तपासा.');
  String get clearHistory => _t('Clear history', 'हिस्ट्री साफ़ करें', 'हिस्ट्री साफ करा');
  String get clearHistorySub => _t('Videos stay in your gallery', 'वीडियो आपकी गैलरी में रहेंगे', 'व्हिडिओ तुमच्या गॅलरीत राहतील');
  String get clearHistoryQ => _t('Clear history?', 'हिस्ट्री साफ़ करें?', 'हिस्ट्री साफ करायची?');
  String get clearHistoryBody => _t(
      'This only clears the list in this app.\n\nYour videos will NOT be deleted from your gallery.',
      'इससे सिर्फ़ इस ऐप की सूची साफ़ होगी।\n\nआपके वीडियो गैलरी से डिलीट नहीं होंगे।',
      'यामुळे फक्त या ॲपमधील यादी साफ होईल.\n\nतुमचे व्हिडिओ गॅलरीतून डिलीट होणार नाहीत.');
  String get historyCleared => _t('History cleared. Your videos are still in your gallery.',
      'हिस्ट्री साफ़ हो गई। आपके वीडियो गैलरी में सुरक्षित हैं।', 'हिस्ट्री साफ झाली. तुमचे व्हिडिओ गॅलरीत सुरक्षित आहेत.');
  String get clearBtn => _t('Clear', 'साफ़ करें', 'साफ करा');
  String get madeBy => 'Made with ♥ by Priti';

  // ---- History & player ----------------------------------------------------------------------
  String get play => _t('Play', 'चलाएँ', 'प्ले करा');
  String get openInGallery => _t('Open in gallery app', 'गैलरी ऐप में खोलें', 'गॅलरी ॲपमध्ये उघडा');
  String get share => _t('Share', 'शेयर करें', 'शेअर करा');
  String get delete => _t('Delete', 'डिलीट करें', 'डिलीट करा');
  String get deleteQ => _t('Delete download?', 'डाउनलोड डिलीट करें?', 'डाउनलोड डिलीट करायचे?');
  String get deleteBody => _t('Remove it from this list only, or also delete the video from your phone?',
      'इसे सिर्फ़ सूची से हटाएँ या फ़ोन से वीडियो भी डिलीट करें?',
      'फक्त यादीतून काढायचे की फोनमधून व्हिडिओही डिलीट करायचा?');
  String get listOnly => _t('List only', 'सिर्फ़ सूची से', 'फक्त यादीतून');
  String get deleteVideo => _t('Delete video', 'वीडियो डिलीट करें', 'व्हिडिओ डिलीट करा');
  String nVideos(int n) => _t('$n videos', '$n वीडियो', '$n व्हिडिओ');
  String get videoMissing => _t('This video was moved or deleted from your phone.',
      'यह वीडियो फ़ोन से हटाया या खिसकाया गया है।', 'हा व्हिडिओ फोनमधून हलवला किंवा डिलीट केला आहे.');
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  bool isSupported(Locale locale) => S.languages.containsKey(locale.languageCode);

  @override
  Future<S> load(Locale locale) => SynchronousFuture(S(locale.languageCode));

  @override
  bool shouldReload(_SDelegate old) => false;
}
