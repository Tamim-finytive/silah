import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_colors.dart';

class QuranScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const QuranScreen({super.key, this.onBack});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  static const _storage = FlutterSecureStorage();
  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://api.alquran.cloud/v1',
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 20),
  ));

  List<Map<String, dynamic>> _surahs = [];
  bool _loading = true;
  String? _error;
  int? _lastSurah;
  int _lastAyah = 1;
  String? _lastSurahName;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadLastRead();
    _loadSurahs();
  }

  Future<void> _loadLastRead() async {
    try {
      final surah =
          int.tryParse(await _storage.read(key: 'quran_last_surah') ?? '');
      final ayah =
          int.tryParse(await _storage.read(key: 'quran_last_ayah') ?? '1') ?? 1;
      final name = await _storage.read(key: 'quran_last_surah_name');
      if (mounted) {
        setState(() {
          _lastSurah = surah;
          _lastAyah = ayah;
          _lastSurahName = name;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSurahs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _dio.get('/surah');
      final data =
          (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _surahs = data.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'Could not load the Quran chapters. Check your connection and try again.';
        });
      }
    }
  }

  Future<void> _openSurah(Map<String, dynamic> surah,
      {int startAyah = 1}) async {
    final number = (surah['number'] as num).toInt();
    await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              _SurahReaderScreen(surahNumber: number, startAyah: startAyah),
        ));
    await _loadLastRead();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _surahs.where((surah) {
      final query = _query.trim().toLowerCase();
      return query.isEmpty ||
          '${surah['englishName']}'.toLowerCase().contains(query) ||
          '${surah['name']}'.contains(_query.trim()) ||
          '${surah['number']}'.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: (widget.onBack != null || Navigator.canPop(context))
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: () {
                  if (widget.onBack != null) {
                    widget.onBack!();
                  } else if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                })
            : null,
        title: const Text('திருக்குர்ஆன் / Holy Quran'),
      ),
      body: Column(children: [
        if (_lastSurah != null)
          Card(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            color: AppColors.primary,
            child: ListTile(
              leading: const Icon(Icons.bookmark, color: AppColors.secondary),
              title: const Text('Last read',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              subtitle: Text(
                  '${_lastSurahName ?? 'Surah $_lastSurah'} · Ayah $_lastAyah',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.play_circle_fill, color: Colors.white),
              onTap: () {
                final matches =
                    _surahs.where((s) => s['number'] == _lastSurah).toList();
                if (matches.isNotEmpty) {
                  _openSurah(matches.first, startAyah: _lastAyah);
                }
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Search chapters by name or number',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                  onPressed: _loadSurahs,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Try again'))
                            ],
                          )))
                  : ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (context, index) {
                        final surah = visible[index];
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(10)),
                            child: Text('${surah['number']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary)),
                          ),
                          title: Text(
                              '${surah['englishName']} · ${surah['englishNameTranslation']}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${surah['numberOfAyahs']} verses · ${surah['revelationType']}'),
                          trailing: Text('${surah['name']}',
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                  fontSize: 22,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600)),
                          onTap: () => _openSurah(surah),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

class _SurahReaderScreen extends StatefulWidget {
  final int surahNumber;
  final int startAyah;
  const _SurahReaderScreen(
      {required this.surahNumber, required this.startAyah});

  @override
  State<_SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<_SurahReaderScreen> {
  static const _storage = FlutterSecureStorage();
  static final _dio = Dio(BaseOptions(
      baseUrl: 'https://api.alquran.cloud/v1',
      receiveTimeout: const Duration(seconds: 30)));
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _arabic;
  Map<String, dynamic>? _translation;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _ayahKeys = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _dio
          .get('/surah/${widget.surahNumber}/editions/quran-uthmani,en.sahih');
      final editions =
          (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _arabic = editions[0] as Map<String, dynamic>;
        _translation = editions[1] as Map<String, dynamic>;
        _loading = false;
      });
      await _saveProgress(widget.startAyah);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _ayahKeys[widget.startAyah]?.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(target,
              duration: const Duration(milliseconds: 350), alignment: 0.08);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'Could not load this chapter. Check your connection and try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _saveProgress(int ayah) async {
    final name =
        _arabic?['englishName']?.toString() ?? 'Surah ${widget.surahNumber}';
    await _storage.write(
        key: 'quran_last_surah', value: '${widget.surahNumber}');
    await _storage.write(key: 'quran_last_ayah', value: '$ayah');
    await _storage.write(key: 'quran_last_surah_name', value: name);
  }

  Widget _buildAyah(
      int index, List<dynamic> arabicAyahs, List<dynamic> translatedAyahs) {
    final arabic = arabicAyahs[index] as Map<String, dynamic>;
    final translation = index < translatedAyahs.length
        ? translatedAyahs[index] as Map<String, dynamic>
        : null;
    final ayahNumber = arabic['numberInSurah'] as int? ?? index + 1;
    final key = _ayahKeys.putIfAbsent(ayahNumber, GlobalKey.new);
    return InkWell(
      key: key,
      onTap: () => _saveProgress(ayahNumber),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.primaryContainer,
                child: Text('$ayahNumber',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold))),
            const Spacer(),
            const Icon(Icons.bookmark_add_outlined,
                size: 18, color: AppColors.textMuted),
          ]),
          const SizedBox(height: 12),
          Text('${arabic['text'] ?? ''}',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 27, height: 1.9, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Text('${translation?['text'] ?? ''}',
              style: const TextStyle(
                  fontSize: 15, height: 1.55, color: AppColors.textSecondary)),
          const Divider(height: 22),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final arabicAyahs = _arabic?['ayahs'] as List<dynamic>? ?? [];
    final translatedAyahs = _translation?['ayahs'] as List<dynamic>? ?? [];
    final name = _arabic?['englishName']?.toString() ?? 'Quran';
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'))
                      ])))
              : SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(children: [
                    Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(children: [
                          Text('${_arabic?['name'] ?? ''}',
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                  fontSize: 32,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                              '${_arabic?['englishNameTranslation'] ?? ''} · ${_arabic?['numberOfAyahs'] ?? ''} verses',
                              style: const TextStyle(
                                  color: AppColors.textSecondary)),
                          if (widget.surahNumber != 1 &&
                              widget.surahNumber != 9) ...[
                            const SizedBox(height: 18),
                            const Text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                                textDirection: TextDirection.rtl,
                                style: TextStyle(fontSize: 26, height: 1.8)),
                          ],
                        ])),
                    ...List<Widget>.generate(
                        arabicAyahs.length,
                        (index) =>
                            _buildAyah(index, arabicAyahs, translatedAyahs)),
                  ]),
                ),
    );
  }
}
