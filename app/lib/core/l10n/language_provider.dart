import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const appLanguageNames = <String, String>{
  'en': 'English',
  'ta': 'தமிழ்',
  'ar': 'العربية',
  'hi': 'हिन्दी',
  'ur': 'اردو',
};

class LanguageNotifier extends StateNotifier<String> {
  static const _storage = FlutterSecureStorage();
  static const _languageKey = 'preferred_language_code';
  static const _legacyLanguageKey = 'preferred_language_english';

  LanguageNotifier() : super('en') {
    _loadSavedLanguage();
  }

  bool get isEnglish => state == 'en';

  Future<void> _loadSavedLanguage() async {
    final saved = await _storage.read(key: _languageKey);
    if (saved != null && appLanguageNames.containsKey(saved)) {
      state = saved;
      return;
    }
    // Migrate the previous English/Tamil setting without changing the user's choice.
    final legacy = await _storage.read(key: _legacyLanguageKey);
    if (legacy != null) {
      await setLanguage(legacy == 'false' ? 'ta' : 'en');
    }
  }

  Future<void> setLanguage(String code) async {
    if (!appLanguageNames.containsKey(code)) return;
    state = code;
    await _storage.write(key: _languageKey, value: code);
    await _storage.write(
        key: _legacyLanguageKey, value: (code == 'en').toString());
  }

  @Deprecated('Use setLanguage with a language code')
  Future<void> setEnglish(bool isEnglish) =>
      setLanguage(isEnglish ? 'en' : 'ta');

  String tr({required String en, required String ta}) {
    if (state == 'ta') return ta;
    if (state == 'en') return en;
    return _translations[state]?[en] ?? en;
  }

  String text(String english) {
    if (state == 'en') return english;
    if (state == 'ta') return _tamil[english] ?? english;
    return _translations[state]?[english] ?? english;
  }

  static const _tamil = <String, String>{
    'Home': 'முகப்பு',
    'Masjids': 'மசூதிகள்',
    'Qibla': 'கிப்லா',
    'Notices': 'அறிவிப்புகள்',
    'Profile': 'சுயவிவரம்',
    'Overview': 'கண்ணோட்டம்',
    'Requests': 'கோரிக்கைகள்',
    'Users': 'பயனர்கள்',
    'Prayer': 'தொழுகை',
    'Members': 'உறுப்பினர்கள்',
    'Settings': 'அமைப்புகள்',
    'Language': 'மொழி',
    'App language': 'செயலி மொழி',
    'English': 'ஆங்கிலம்',
    'Sandha': 'சந்தா',
    'Holy Quran': 'திருக்குர்ஆன்',
    'Last read': 'கடைசியாகப் படித்தது',
    'Search chapters by name or number':
        'அத்தியாயப் பெயர் அல்லது எண்ணைத் தேடுங்கள்',
    'verses': 'வசனங்கள்',
    'Try again': 'மீண்டும் முயற்சி',
    'Welcome': 'அஸ்ஸலாமு அலைக்கும் வரஹ்மத்துல்லாஹி வபரகாத்துஹு',
    'Assalamu Alaikum wa Rahmatullah': 'அஸ்ஸலாமு அலைக்கும் வரஹ்மத்துல்லாஹ்',
    'Bismillahir Rahmanir Raheem': 'பிஸ்மில்லாஹிர் ரஹ்மானிர் ரஹீம்',
    'Alhamdulillah': 'அல்ஹம்துலில்லாஹ்',
    'Masha\'Allah': 'மாஷா அல்லாஹ்',
    'Sign In': 'உள்நுழைய',
    'Login / Continue': 'உள்நுழை / தொடரவும்',
    'Save & Continue': 'சேமித்து தொடரவும்',
    'Complete & Go to App': 'முடித்து செயலிக்குச் செல்லவும்',
    'Enter your mobile number to continue':
        'தொடர உங்கள் கைபேசி எண்ணை உள்ளிடவும்',
    'Name A–Z': 'பெயர் அ–ஔ',
    'Name Z–A': 'பெயர் ஔ–அ',
    'Nearby': 'அருகில்',
    'Nearest to me': 'எனக்கு அருகில்',
    'Sort by': 'வரிசைப்படுத்து',
    'No masjids are available right now': 'தற்போது பள்ளிவாசல்கள் இல்லை',
    'No masjids match your search': 'உங்கள் தேடலுக்கு பள்ளிவாசல்கள் இல்லை',
    'Available plans': 'கிடைக்கும் திட்டங்கள்',
    'Monthly contribution': 'மாதாந்திர பங்களிப்பு',
    'month': 'மாதம்',
    'Active': 'செயலில் உள்ளது',
    'Not enrolled': 'பதிவு செய்யப்படவில்லை',
    'General Fund': 'பொது நிதி',
    'Sandha plan': 'சந்தா திட்டம்',
    'Auto-play voice messages': 'குரல் செய்திகளைத் தானாக இயக்கு',
    'Clear search': 'தேடலை அழி',
    'Checking…': 'சரிபார்க்கிறது…',
    'Location': 'இடம்',
    'Read': 'படித்தவை',
    'Unread': 'படிக்காதவை',
    'Retry': 'மீண்டும் முயற்சி',
    'Proceed to Register Masjid': 'பள்ளிவாசல் பதிவைத் தொடரவும்',
    'Getting Started': 'தொடங்குவோம்',
    'Qibla Direction': 'கிப்லா திசை',
    'Your Full Name *': 'உங்கள் முழுப் பெயர் *',
    'Mobile number': 'கைபேசி எண்',
    'Follow your local masjid, see daily Namaz times, live notifications & pay monthly sandha.':
        'உங்கள் பள்ளிவாசலை இணைத்து தொழுகை நேரங்கள், அறிவிப்புகள் மற்றும் மாதாந்திர சந்தா விவரங்களைப் பெறுங்கள்.',
    'Register a new Masjid, set Adhan/Jamaah timings, pass announcements & manage members.':
        'புதிய பள்ளிவாசலைப் பதிவு செய்து, தொழுகை நேரங்கள் மற்றும் அறிவிப்புகளை நிர்வகிக்கவும்.',
    'Check the spelling or try a nearby city name.':
        'எழுத்துப்பிழையைச் சரிபார்க்கவும் அல்லது அருகிலுள்ள நகரத்தின் பெயரை முயற்சிக்கவும்.',
    'Check your connection and retry.':
        'இணைப்பைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.',
    'System Dashboard': 'அமைப்பு முகப்பு',
    'Masjid Directory': 'பள்ளிவாசல் பட்டியல்',
    'Masjid Approval Requests': 'பள்ளிவாசல் ஒப்புதல் கோரிக்கைகள்',
    'Broadcast Announcements': 'பொது அறிவிப்புகள்',
    'User Management': 'பயனர் மேலாண்மை',
    'Super Admin Profile': 'சூப்பர் அட்மின் சுயவிவரம்',
    'My Profile': 'என் சுயவிவரம்',
    'Super Administrator': 'சூப்பர் நிர்வாகி',
    'System Live Metrics': 'அமைப்பின் நேரடி விவரங்கள்',
    'Masjid Notice Board': 'பள்ளிவாசல் அறிவிப்பு பலகை',
    'Masjid currently inactive': 'பள்ளிவாசல் தற்போது செயலற்ற நிலையில் உள்ளது',
    'This masjid is currently inactive. Admin tools and schedules are unavailable until a Super Admin reactivates it.':
        'இந்த பள்ளிவாசல் தற்போது செயலற்ற நிலையில் உள்ளது. சூப்பர் அட்மின் மீண்டும் செயல்படுத்தும் வரை நிர்வாக வசதிகளும் நேர அட்டவணைகளும் கிடைக்காது.',
    'Switch Admin Masjid': 'மற்ற பள்ளிவாசலுக்கு மாறவும்',
    'Return to User App': 'பயனர் செயலிக்குத் திரும்பவும்',
    'Manage Prayer & Events': 'தொழுகை மற்றும் நிகழ்வுகள்',
    'Prayers': 'தொழுகைகள்',
    'Events': 'நிகழ்வுகள்',
    'Manage Members & Roles': 'உறுப்பினர் நிர்வாகம்',
  };

  static const _translations = <String, Map<String, String>>{
    'hi': {
      'Home': 'होम',
      'Masjids': 'मस्जिदें',
      'Qibla': 'क़िबला',
      'Notices': 'सूचनाएँ',
      'Profile': 'प्रोफ़ाइल',
      'Overview': 'अवलोकन',
      'Requests': 'अनुरोध',
      'Users': 'उपयोगकर्ता',
      'Prayer': 'नमाज़',
      'Members': 'सदस्य',
      'Settings': 'सेटिंग्स',
      'Language': 'भाषा',
      'App language': 'ऐप की भाषा',
      'Sandha': 'मासिक चंदा',
      'My Profile': 'मेरी प्रोफ़ाइल',
      'Masjid Settings & Profile': 'मस्जिद सेटिंग्स और प्रोफ़ाइल',
      'Manage Members & Roles': 'सदस्य प्रबंधन',
      'Manage Prayer & Events': 'नमाज़ और कार्यक्रम',
      'Prayers': 'नमाज़ें',
      'Events': 'कार्यक्रम',
      'Prayer Events & Schedule': 'नमाज़ कार्यक्रम और समय-सारणी',
      'Create Prayer Schedule': 'नमाज़ समय-सारणी बनाएँ',
      'Dashboard': 'डैशबोर्ड',
      'Search & Add': 'खोजें और जोड़ें',
      'Scan QR Code': 'QR कोड स्कैन करें',
      'Connect with Masjid': 'मस्जिद से जुड़ें',
      'Refresh': 'रीफ़्रेश करें',
      'Save': 'सहेजें',
      'Cancel': 'रद्द करें',
      'Sign Out / Switch Account': 'साइन आउट / खाता बदलें',
      'English': 'अंग्रेज़ी',
      'Tamil': 'तमिल',
      'Arabic': 'अरबी',
      'Hindi': 'हिन्दी',
      'Urdu': 'उर्दू',
      'Holy Quran': 'पवित्र क़ुरआन',
      'Last read': 'अंतिम बार पढ़ा',
      'Search chapters by name or number': 'अध्याय का नाम या नंबर खोजें',
      'verses': 'आयतें',
      'Try again': 'फिर से कोशिश करें',
      'Welcome': 'अस्सलाम वालेकुम व रहमतुल्लाह',
      'Assalamu Alaikum wa Rahmatullah': 'अस्सलाम वालेकुम व रहमतुल्लाह',
      'Bismillahir Rahmanir Raheem': 'बिस्मिल्लाहिर रहमानिर रहीम',
      'Alhamdulillah': 'अलहम्दुलिल्लाह',
      'Masha\'Allah': 'माशा अल्लाह',
      'Sign In': 'साइन इन करें',
      'Login / Continue': 'लॉगिन / जारी रखें',
      'Save & Continue': 'सहेजें और जारी रखें',
      'Complete & Go to App': 'पूरा करें और ऐप खोलें',
      'Enter your mobile number to continue':
          'जारी रखने के लिए मोबाइल नंबर दर्ज करें',
      'Name A–Z': 'नाम A–Z',
      'Name Z–A': 'नाम Z–A',
      'Nearby': 'आसपास',
      'Nearest to me': 'मेरे सबसे पास',
      'Sort by': 'क्रम से दिखाएँ',
      'No masjids are available right now': 'अभी कोई मस्जिद उपलब्ध नहीं है',
      'No masjids match your search': 'आपकी खोज से मेल खाती मस्जिद नहीं मिली',
      'Available plans': 'उपलब्ध योजनाएँ',
      'Monthly contribution': 'मासिक योगदान',
      'month': 'महीना',
      'Not enrolled': 'नामांकन नहीं है',
      'General Fund': 'सामान्य निधि',
      'Sandha plan': 'मासिक चंदा योजना',
      'Auto-play voice messages': 'आवाज़ संदेश अपने आप चलाएँ',
      'Clear search': 'खोज मिटाएँ',
      'Checking…': 'जाँच हो रही है…',
      'Location': 'स्थान',
      'Read': 'पढ़ी हुई',
      'Unread': 'अपठित',
      'Retry': 'फिर कोशिश करें',
      'Proceed to Register Masjid': 'मस्जिद पंजीकरण जारी रखें',
      'Getting Started': 'शुरुआत करें',
      'Qibla Direction': 'क़िबला दिशा',
      'Your Full Name *': 'आपका पूरा नाम *',
      'Mobile number': 'मोबाइल नंबर',
      'Follow your local masjid, see daily Namaz times, live notifications & pay monthly sandha.':
          'अपनी मस्जिद से जुड़ें, नमाज़ के समय और सूचनाएँ देखें, और मासिक चंदा दें।',
      'Register a new Masjid, set Adhan/Jamaah timings, pass announcements & manage members.':
          'नई मस्जिद पंजीकृत करें, नमाज़ के समय तय करें, सूचनाएँ भेजें और सदस्यों का प्रबंधन करें।',
      'Check the spelling or try a nearby city name.':
          'वर्तनी जाँचें या पास के शहर का नाम आज़माएँ।',
      'Active': 'सक्रिय',
      'Connect': 'जुड़ें',
      'Connected': 'जुड़ा हुआ',
      'Connecting…': 'जुड़ रहा है…',
      'Search masjid by name or city...': 'नाम या शहर से मस्जिद खोजें...',
      'Searching masjids…': 'मस्जिदें खोजी जा रही हैं…',
      'Type at least 3 characters. Results search after you pause typing.':
          'कम से कम 3 अक्षर लिखें। रुकने पर परिणाम खोजे जाएँगे।',
      'Could not load masjids': 'मस्जिदें लोड नहीं हो सकीं',
      'Could not load more · Retry': 'और परिणाम नहीं आए · फिर कोशिश करें',
      'Point camera at Masjid QR Code to instantly connect':
          'जुड़ने के लिए मस्जिद का QR कोड कैमरे के सामने रखें',
      'Allow location to find Qibla':
          'क़िबला दिशा खोजने के लिए लोकेशन की अनुमति दें',
      'Keep your phone level. The arrow follows your direction.':
          'फोन सीधा रखें। तीर आपकी दिशा के साथ चलेगा।',
      'You are facing the Kaaba': 'आप काबा की दिशा में हैं',
      'Waiting for compass reading': 'कम्पास रीडिंग की प्रतीक्षा है',
      'Check your connection and retry.': 'कनेक्शन जाँचकर फिर कोशिश करें।',
      'Register Masjid': 'मस्जिद पंजीकृत करें',
      'Provide accurate details and GPS location to prevent duplicate entries.':
          'डुप्लिकेट प्रविष्टियों से बचने के लिए सही विवरण और GPS लोकेशन दें।',
      'Masjid Name (English) *': 'मस्जिद का नाम *',
      'City *': 'शहर *',
      'Full Detailed Address *': 'पूरा पता *',
      'Address / Area (Optional)': 'पता / क्षेत्र (वैकल्पिक)',
      'Masjid Administrator / Trustee': 'मस्जिद प्रशासक / ट्रस्टी',
      'Regular Musalli / Devotee': 'नियमित नमाज़ी / श्रद्धालु',
      'Pass announcements & manage members.':
          'सूचनाएँ भेजें और सदस्यों का प्रबंधन करें।',
      'System Dashboard': 'सिस्टम डैशबोर्ड',
      'Masjid Directory': 'मस्जिद सूची',
      'Masjid Approval Requests': 'मस्जिद अनुमोदन अनुरोध',
      'Broadcast Announcements': 'सार्वजनिक सूचनाएँ',
      'User Management': 'उपयोगकर्ता प्रबंधन',
      'Super Admin Profile': 'सुपर एडमिन प्रोफ़ाइल',
      'Super Administrator': 'सुपर एडमिनिस्ट्रेटर',
      'System Live Metrics': 'सिस्टम के लाइव आँकड़े',
      'Masjid Notice Board': 'मस्जिद सूचना बोर्ड',
      'Masjid currently inactive': 'मस्जिद अभी निष्क्रिय है',
      'This masjid is currently inactive. Admin tools and schedules are unavailable until a Super Admin reactivates it.':
          'यह मस्जिद अभी निष्क्रिय है। सुपर एडमिन के दोबारा सक्रिय करने तक प्रशासन और समय-सारणी उपलब्ध नहीं हैं।',
      'Switch Admin Masjid': 'दूसरी मस्जिद पर जाएँ',
      'Return to User App': 'यूज़र ऐप पर लौटें',
    },
    'ar': {
      'Home': 'الرئيسية',
      'Masjids': 'المساجد',
      'Qibla': 'القبلة',
      'Notices': 'الإعلانات',
      'Profile': 'الملف الشخصي',
      'Overview': 'نظرة عامة',
      'Requests': 'الطلبات',
      'Users': 'المستخدمون',
      'Prayer': 'الصلاة',
      'Members': 'الأعضاء',
      'Settings': 'الإعدادات',
      'Language': 'اللغة',
      'App language': 'لغة التطبيق',
      'Sandha': 'الاشتراك الشهري',
      'My Profile': 'ملفي الشخصي',
      'Masjid Settings & Profile': 'إعدادات المسجد والملف الشخصي',
      'Manage Members & Roles': 'إدارة الأعضاء',
      'Manage Prayer & Events': 'الصلاة والفعاليات',
      'Prayers': 'الصلوات',
      'Events': 'الفعاليات',
      'Prayer Events & Schedule': 'مواعيد الصلاة والجدول',
      'Create Prayer Schedule': 'إنشاء جدول الصلاة',
      'Dashboard': 'لوحة التحكم',
      'Search & Add': 'بحث وإضافة',
      'Scan QR Code': 'مسح رمز QR',
      'Connect with Masjid': 'الاتصال بالمسجد',
      'Refresh': 'تحديث',
      'Save': 'حفظ',
      'Cancel': 'إلغاء',
      'Sign Out / Switch Account': 'تسجيل الخروج / تبديل الحساب',
      'English': 'الإنجليزية',
      'Tamil': 'التاميلية',
      'Arabic': 'العربية',
      'Hindi': 'الهندية',
      'Urdu': 'الأردية',
      'Holy Quran': 'القرآن الكريم',
      'Last read': 'آخر قراءة',
      'Search chapters by name or number': 'ابحث عن سورة بالاسم أو الرقم',
      'verses': 'آيات',
      'Try again': 'حاول مرة أخرى',
      'Welcome': 'السلام عليكم ورحمة الله وبركاته',
      'Assalamu Alaikum wa Rahmatullah': 'السلام عليكم ورحمة الله وبركاته',
      'Bismillahir Rahmanir Raheem': 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
      'Alhamdulillah': 'الحمد لله',
      'Masha\'Allah': 'ما شاء الله',
      'Sign In': 'تسجيل الدخول',
      'Login / Continue': 'تسجيل الدخول / متابعة',
      'Save & Continue': 'حفظ ومتابعة',
      'Complete & Go to App': 'أكمل وافتح التطبيق',
      'Enter your mobile number to continue': 'أدخل رقم هاتفك للمتابعة',
      'Name A–Z': 'الاسم أ–ي',
      'Name Z–A': 'الاسم ي–أ',
      'Nearby': 'بالقرب',
      'Nearest to me': 'الأقرب إليّ',
      'Sort by': 'ترتيب حسب',
      'No masjids are available right now': 'لا توجد مساجد متاحة الآن',
      'No masjids match your search': 'لم يتم العثور على مسجد يطابق بحثك',
      'Available plans': 'الخطط المتاحة',
      'Monthly contribution': 'المساهمة الشهرية',
      'month': 'شهر',
      'Not enrolled': 'غیر رجسٹرڈ',
      'General Fund': 'عمومی فنڈ',
      'Sandha plan': 'ماہانہ چندہ منصوبہ',
      'Auto-play voice messages': 'آواز کے پیغامات خود چلائیں',
      'Clear search': 'تلاش صاف کریں',
      'Checking…': 'جانچ ہو رہی ہے…',
      'Location': 'مقام',
      'Read': 'پڑھے گئے',
      'Unread': 'نہ پڑھے گئے',
      'Retry': 'دوبارہ کوشش کریں',
      'Proceed to Register Masjid': 'مسجد کی رجسٹریشن جاری رکھیں',
      'Getting Started': 'آغاز کریں',
      'Qibla Direction': 'قبلہ کی سمت',
      'Your Full Name *': 'آپ کا پورا نام *',
      'Mobile number': 'موبائل نمبر',
      'Follow your local masjid, see daily Namaz times, live notifications & pay monthly sandha.':
          'اپنی مسجد سے منسلک ہوں، نماز کے اوقات اور اطلاعات دیکھیں، اور ماہانہ چندہ دیں۔',
      'Register a new Masjid, set Adhan/Jamaah timings, pass announcements & manage members.':
          'نئی مسجد رجسٹر کریں، نماز کے اوقات مقرر کریں، اعلانات بھیجیں اور اراکین سنبھالیں۔',
      'Check the spelling or try a nearby city name.':
          'ہجے دیکھیں یا قریبی شہر کا نام آزمائیں۔',
      'Active': 'نشط',
      'Connect': 'اتصل',
      'Connected': 'متصل',
      'Connecting…': 'جارٍ الاتصال…',
      'Search masjid by name or city...': 'ابحث عن مسجد بالاسم أو المدينة...',
      'Searching masjids…': 'جارٍ البحث عن المساجد…',
      'Type at least 3 characters. Results search after you pause typing.':
          'اكتب ثلاثة أحرف على الأقل. سيبدأ البحث بعد توقفك عن الكتابة.',
      'Could not load masjids': 'تعذر تحميل المساجد',
      'Could not load more · Retry': 'تعذر تحميل المزيد · أعد المحاولة',
      'Point camera at Masjid QR Code to instantly connect':
          'وجّه الكاميرا إلى رمز QR الخاص بالمسجد للاتصال',
      'Allow location to find Qibla': 'اسمح بالموقع لتحديد اتجاه القبلة',
      'Keep your phone level. The arrow follows your direction.':
          'أبقِ هاتفك مستوياً. سيتبع السهم اتجاهك.',
      'You are facing the Kaaba': 'أنت تواجه الكعبة',
      'Waiting for compass reading': 'بانتظار قراءة البوصلة',
      'Check your connection and retry.': 'تحقق من اتصالك وحاول مرة أخرى.',
      'Register Masjid': 'تسجيل مسجد',
      'Provide accurate details and GPS location to prevent duplicate entries.':
          'أدخل بيانات دقيقة وموقع GPS لتجنب تكرار التسجيل.',
      'Masjid Name (English) *': 'اسم المسجد *',
      'City *': 'المدينة *',
      'Full Detailed Address *': 'العنوان الكامل بالتفصيل *',
      'Address / Area (Optional)': 'العنوان / المنطقة (اختياري)',
      'Masjid Administrator / Trustee': 'مدير المسجد / أمين الوقف',
      'Regular Musalli / Devotee': 'مصلٍّ منتظم / مؤمن',
      'Pass announcements & manage members.':
          'أرسل الإعلانات وأدر شؤون الأعضاء.',
      'System Dashboard': 'لوحة النظام',
      'Masjid Directory': 'دليل المساجد',
      'Masjid Approval Requests': 'طلبات اعتماد المساجد',
      'Broadcast Announcements': 'الإعلانات العامة',
      'User Management': 'إدارة المستخدمين',
      'Super Admin Profile': 'ملف المشرف الأعلى',
      'Super Administrator': 'المشرف الأعلى',
      'System Live Metrics': 'إحصاءات النظام المباشرة',
      'Masjid Notice Board': 'لوحة إعلانات المسجد',
      'Masjid currently inactive': 'المسجد غير نشط حالياً',
      'This masjid is currently inactive. Admin tools and schedules are unavailable until a Super Admin reactivates it.':
          'هذا المسجد غير نشط حالياً. لن تتوفر أدوات الإدارة والجداول حتى يعيد المشرف الأعلى تفعيله.',
      'Switch Admin Masjid': 'التبديل إلى مسجد آخر',
      'Return to User App': 'العودة إلى تطبيق المستخدم',
    },
    'ur': {
      'Home': 'ہوم',
      'Masjids': 'مساجد',
      'Qibla': 'قبلہ',
      'Notices': 'اطلاعات',
      'Profile': 'پروفائل',
      'Overview': 'جائزہ',
      'Requests': 'درخواستیں',
      'Users': 'صارفین',
      'Prayer': 'نماز',
      'Members': 'اراکین',
      'Settings': 'ترتیبات',
      'Language': 'زبان',
      'App language': 'ایپ کی زبان',
      'Sandha': 'ماہانہ چندہ',
      'My Profile': 'میری پروفائل',
      'Masjid Settings & Profile': 'مسجد کی ترتیبات اور پروفائل',
      'Manage Members & Roles': 'اراکین کا انتظام',
      'Manage Prayer & Events': 'نماز اور تقریبات',
      'Prayers': 'نمازیں',
      'Events': 'تقریبات',
      'Prayer Events & Schedule': 'نماز کے اوقات اور شیڈول',
      'Create Prayer Schedule': 'نماز کا شیڈول بنائیں',
      'Dashboard': 'ڈیش بورڈ',
      'Search & Add': 'تلاش کریں اور شامل کریں',
      'Scan QR Code': 'QR کوڈ اسکین کریں',
      'Connect with Masjid': 'مسجد سے رابطہ کریں',
      'Refresh': 'تازہ کریں',
      'Save': 'محفوظ کریں',
      'Cancel': 'منسوخ کریں',
      'Sign Out / Switch Account': 'سائن آؤٹ / اکاؤنٹ تبدیل کریں',
      'English': 'انگریزی',
      'Tamil': 'تمل',
      'Arabic': 'عربی',
      'Hindi': 'ہندی',
      'Urdu': 'اردو',
      'Holy Quran': 'قرآنِ پاک',
      'Last read': 'آخری بار پڑھا',
      'Search chapters by name or number': 'سورت کا نام یا نمبر تلاش کریں',
      'verses': 'آیات',
      'Try again': 'دوبارہ کوشش کریں',
      'Welcome': 'السلام علیکم ورحمۃ اللہ وبرکاتہ',
      'Assalamu Alaikum wa Rahmatullah': 'السلام علیکم ورحمۃ اللہ وبرکاتہ',
      'Bismillahir Rahmanir Raheem': 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
      'Alhamdulillah': 'الحمد للہ',
      'Masha\'Allah': 'ماشاء اللہ',
      'Sign In': 'سائن اِن کریں',
      'Login / Continue': 'لاگ اِن / جاری رکھیں',
      'Save & Continue': 'محفوظ کریں اور جاری رکھیں',
      'Complete & Go to App': 'مکمل کریں اور ایپ کھولیں',
      'Enter your mobile number to continue':
          'جاری رکھنے کے لیے موبائل نمبر درج کریں',
      'Name A–Z': 'نام الف تا ے',
      'Name Z–A': 'نام ے تا الف',
      'Nearby': 'قریب',
      'Nearest to me': 'میرے قریب ترین',
      'Sort by': 'ترتیب دیں',
      'No masjids are available right now': 'اس وقت کوئی مسجد دستیاب نہیں',
      'No masjids match your search':
          'آپ کی تلاش سے مطابقت رکھنے والی مسجد نہیں ملی',
      'Available plans': 'دستیاب منصوبے',
      'Monthly contribution': 'ماہانہ چندہ',
      'month': 'ماہ',
      'Active': 'فعال',
      'Connect': 'جڑیں',
      'Connected': 'منسلک',
      'Connecting…': 'رابطہ ہو رہا ہے…',
      'Search masjid by name or city...': 'نام یا شہر سے مسجد تلاش کریں...',
      'Searching masjids…': 'مساجد تلاش کی جا رہی ہیں…',
      'Type at least 3 characters. Results search after you pause typing.':
          'کم از کم 3 حروف لکھیں۔ رکنے کے بعد تلاش شروع ہوگی۔',
      'Could not load masjids': 'مساجد لوڈ نہیں ہو سکیں',
      'Could not load more · Retry': 'مزید لوڈ نہیں ہو سکا · دوبارہ کوشش کریں',
      'Point camera at Masjid QR Code to instantly connect':
          'مسجد کے QR کوڈ پر کیمرہ رکھ کر فوراً منسلک ہوں',
      'Allow location to find Qibla':
          'قبلہ معلوم کرنے کے لیے مقام کی اجازت دیں',
      'Keep your phone level. The arrow follows your direction.':
          'فون سیدھا رکھیں۔ تیر آپ کی سمت کے مطابق ہوگا۔',
      'You are facing the Kaaba': 'آپ کعبہ کی سمت رخ کیے ہوئے ہیں',
      'Waiting for compass reading': 'قطب نما کی پیمائش کا انتظار ہے',
      'Check your connection and retry.':
          'انٹرنیٹ کنکشن دیکھ کر دوبارہ کوشش کریں۔',
      'Register Masjid': 'مسجد رجسٹر کریں',
      'Provide accurate details and GPS location to prevent duplicate entries.':
          'دوبارہ اندراج سے بچنے کے لیے درست تفصیلات اور GPS مقام دیں۔',
      'Masjid Name (English) *': 'مسجد کا نام *',
      'City *': 'شہر *',
      'Full Detailed Address *': 'مکمل تفصیلی پتہ *',
      'Address / Area (Optional)': 'پتہ / علاقہ (اختیاری)',
      'Masjid Administrator / Trustee': 'مسجد منتظم / متولی',
      'Regular Musalli / Devotee': 'باقاعدہ نمازی / عقیدت مند',
      'Pass announcements & manage members.':
          'اعلانات بھیجیں اور اراکین کا انتظام کریں۔',
      'System Dashboard': 'سسٹم ڈیش بورڈ',
      'Masjid Directory': 'مساجد کی فہرست',
      'Masjid Approval Requests': 'مسجد کی منظوری کی درخواستیں',
      'Broadcast Announcements': 'عام اعلانات',
      'User Management': 'صارفین کا انتظام',
      'Super Admin Profile': 'سپر ایڈمن پروفائل',
      'Super Administrator': 'سپر ایڈمنسٹریٹر',
      'System Live Metrics': 'سسٹم کے براہِ راست اعدادوشمار',
      'Masjid Notice Board': 'مسجد کا نوٹس بورڈ',
      'Masjid currently inactive': 'مسجد فی الحال غیر فعال ہے',
      'This masjid is currently inactive. Admin tools and schedules are unavailable until a Super Admin reactivates it.':
          'یہ مسجد فی الحال غیر فعال ہے۔ سپر ایڈمن کے دوبارہ فعال کرنے تک انتظامی سہولتیں اور اوقات دستیاب نہیں ہوں گے۔',
      'Switch Admin Masjid': 'دوسری مسجد پر جائیں',
      'Return to User App': 'صارف ایپ پر واپس جائیں',
    },
  };
}

final languageProvider = StateNotifierProvider<LanguageNotifier, String>((ref) {
  return LanguageNotifier();
});

class AppLanguageSettingsTile extends ConsumerWidget {
  const AppLanguageSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(languageProvider);
    final language = ref.read(languageProvider.notifier);
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(language.text('Language')),
      subtitle: Text(appLanguageNames[code] ?? appLanguageNames['en']!),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(language.text('App language')),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: appLanguageNames.entries
                  .map((entry) => RadioListTile<String>(
                        value: entry.key,
                        groupValue: code,
                        title: Text(entry.value,
                            textDirection:
                                entry.key == 'ar' || entry.key == 'ur'
                                    ? TextDirection.rtl
                                    : TextDirection.ltr),
                        onChanged: (value) {
                          if (value != null) language.setLanguage(value);
                          Navigator.pop(dialogContext);
                        },
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class AppLanguageText extends ConsumerWidget {
  final String english;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const AppLanguageText(
    this.english, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    return Text(
      ref.read(languageProvider.notifier).text(english),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
