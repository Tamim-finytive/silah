import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LanguageNotifier extends StateNotifier<bool> {
  static const _storage = FlutterSecureStorage();
  static const _languageKey = 'preferred_language_english';

  // true = English, false = Tamil
  LanguageNotifier() : super(true) {
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final saved = await _storage.read(key: _languageKey);
    if (saved != null) state = saved != 'false';
  }

  Future<void> setEnglish(bool isEnglish) async {
    state = isEnglish;
    await _storage.write(key: _languageKey, value: isEnglish.toString());
  }

  String tr({required String en, required String ta}) => state ? en : ta;
}

final languageProvider = StateNotifierProvider<LanguageNotifier, bool>((ref) {
  return LanguageNotifier();
});
