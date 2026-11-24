import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/l10n/language_provider.dart';
import '../../../../core/network/api_service.dart';
import '../../../prayer_times/data/prayer_times_provider.dart';
import '../../../prayer_times/presentation/screens/home_screen.dart';

class ConnectMasjidScreen extends ConsumerStatefulWidget {
  const ConnectMasjidScreen({super.key});

  @override
  ConsumerState<ConnectMasjidScreen> createState() =>
      _ConnectMasjidScreenState();
}

class _ConnectMasjidScreenState extends ConsumerState<ConnectMasjidScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _resultsScrollController = ScrollController();
  List<dynamic> _allMasjids = [];
  List<dynamic> _filteredMasjids = [];
  final Set<String> _connectedMasjidIds = <String>{};
  bool _isLoadingConnectedMasjids = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isProcessing = false;
  String? _connectingMasjidId;
  bool _isSearching = false;
  bool _searchTooShort = false;
  bool _hasMore = false;
  String? _loadError;
  int _page = 1;
  int _totalMasjids = 0;
  String _sort = 'NAME_ASC';
  double? _userLatitude;
  double? _userLongitude;
  int _searchRequestId = 0;
  Timer? _searchDebounce;
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scannerController = MobileScannerController();
    _resultsScrollController.addListener(_onResultsScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMasjids(reset: true);
      _loadConnectedMasjids();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scannerController?.dispose();
    _searchDebounce?.cancel();
    _resultsScrollController
      ..removeListener(_onResultsScroll)
      ..dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onResultsScroll() {
    if (_resultsScrollController.hasClients &&
        _resultsScrollController.position.extentAfter < 360 &&
        _hasMore &&
        !_isLoadingMore &&
        !_isLoading) {
      _loadMasjids();
    }
  }

  Future<void> _loadConnectedMasjids() async {
    final masjids = await ApiService.instance.getMyMasjids();
    if (!mounted) return;
    setState(() {
      _connectedMasjidIds
        ..clear()
        ..addAll(masjids
            .whereType<Map<String, dynamic>>()
            .map((masjid) => masjid['id']?.toString())
            .whereType<String>());
      _isLoadingConnectedMasjids = false;
    });
  }

  Future<void> _loadMasjids({bool reset = false}) async {
    if (!reset && (_isLoadingMore || !_hasMore)) return;
    final requestId = reset ? ++_searchRequestId : _searchRequestId;
    final requestedPage = reset ? 1 : _page + 1;
    final query = _searchCtrl.text.trim();
    final search = query.length >= 3 ? query : null;
    setState(() {
      _loadError = null;
      if (reset) {
        _isLoading = true;
        _isLoadingMore = false;
        _isSearching = search != null;
        _hasMore = false;
        _allMasjids = [];
        _filteredMasjids = [];
        _totalMasjids = 0;
      } else {
        _isLoadingMore = true;
      }
    });
    try {
      final result = await ApiService.instance.getMasjidsPage(
        search: search,
        page: requestedPage,
        limit: 20,
        sort: _sort,
        latitude: _sort == 'NEAREST' ? _userLatitude : null,
        longitude: _sort == 'NEAREST' ? _userLongitude : null,
      );
      if (!mounted || requestId != _searchRequestId) return;
      final items = (result['items'] as List<dynamic>? ?? const []);
      setState(() {
        if (reset) {
          _allMasjids = items;
        } else {
          final knownIds =
              _allMasjids.map((masjid) => masjid['id']?.toString()).toSet();
          _allMasjids.addAll(items
              .where((masjid) => !knownIds.contains(masjid['id']?.toString())));
        }
        _filteredMasjids = _allMasjids;
        _page = (result['page'] as num?)?.toInt() ?? requestedPage;
        _totalMasjids =
            (result['total'] as num?)?.toInt() ?? _allMasjids.length;
        _hasMore = result['hasMore'] == true;
        _isLoading = false;
        _isLoadingMore = false;
        _isSearching = false;
      });
    } catch (error) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _isSearching = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _selectSort(String? sort) async {
    if (sort == null) return;
    if (sort == 'NEAREST') {
      try {
        if (!await Geolocator.isLocationServiceEnabled()) {
          throw Exception('Turn on location services to find nearby masjids.');
        }
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw Exception('Location permission is needed for nearby search.');
        }
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 12),
          ),
        );
        if (!mounted) return;
        setState(() {
          _userLatitude = position.latitude;
          _userLongitude = position.longitude;
          _sort = sort;
        });
        await _loadMasjids(reset: true);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
      return;
    }
    setState(() => _sort = sort);
    await _loadMasjids(reset: true);
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    _searchDebounce?.cancel();
    final requestId = ++_searchRequestId;

    final localMatches = _allMasjids.where((m) {
      final name = (m['name'] ?? '').toString().toLowerCase();
      final nameTa = (m['nameTa'] ?? '').toString().toLowerCase();
      final city = (m['city'] ?? '').toString().toLowerCase();
      final address = (m['address'] ?? '').toString().toLowerCase();
      return name.contains(q) ||
          nameTa.contains(q) ||
          city.contains(q) ||
          address.contains(q);
    }).toList();

    if (q.isEmpty) {
      _searchRequestId++;
      setState(() {
        _filteredMasjids = _allMasjids;
        _isSearching = false;
        _searchTooShort = false;
      });
      _loadMasjids(reset: true);
      return;
    }

    if (q.length < 3) {
      setState(() {
        _filteredMasjids = localMatches;
        _isLoading = false;
        _isLoadingMore = false;
        _isSearching = false;
        _searchTooShort = true;
        _hasMore = false;
        _loadError = null;
      });
      return;
    }

    setState(() {
      _filteredMasjids = localMatches;
      _isSearching = true;
      _searchTooShort = false;
    });
    _searchDebounce = Timer(const Duration(seconds: 1), () async {
      if (!mounted || requestId != _searchRequestId) return;
      await _loadMasjids(reset: true);
    });
  }

  Future<void> _handleJoinMasjid(String masjidId, String masjidName) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _connectingMasjidId = masjidId;
    });

    await _completeMasjidJoin(masjidId, masjidName);
  }

  Future<void> _completeMasjidJoin(String masjidId, String masjidName) async {
    try {
      await ApiService.instance.joinMasjid(masjidId, isPrimary: true);
      if (mounted) {
        setState(() => _connectedMasjidIds.add(masjidId));
      }
      final masjid = _allMasjids.cast<Map<String, dynamic>?>().firstWhere(
            (item) => item?['id']?.toString() == masjidId,
            orElse: () => null,
          );
      if (masjid != null) {
        await ref.read(prayerTimesProvider.notifier).switchMasjid(masjid);
      } else {
        await ref
            .read(prayerTimesProvider.notifier)
            .refreshFromBackend(specificMasjidId: masjidId);
      }
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade800,
          content: Text('Connected to "$masjidName" successfully!'),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _connectingMasjidId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text(ApiService.getErrorMessage(e,
                fallback: 'Failed to connect to masjid')),
          ),
        );
      }
    }
  }

  Future<void> _openMasjidLocation(Map<String, dynamic> masjid) async {
    final mapUrl = masjid['mapUrl']?.toString();
    if (mapUrl != null &&
        mapUrl.trim().isNotEmpty &&
        mapUrl.startsWith('http')) {
      final uri = Uri.parse(mapUrl.trim());
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    final lat = masjid['latitude'];
    final lng = masjid['longitude'];
    String query;
    if (lat != null && lng != null) {
      query = '$lat,$lng';
    } else {
      query = Uri.encodeComponent(
          '${masjid['name'] ?? ''}, ${masjid['city'] ?? ''}');
    }
    final mapsUri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(mapsUri)) {
      await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _onQrDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final token = barcode.rawValue!.trim();
    setState(() => _isProcessing = true);

    try {
      final masjid = await ApiService.instance.getMasjidByQr(token);
      if (masjid != null && mounted) {
        await _completeMasjidJoin(
          masjid['id'].toString(),
          masjid['name']?.toString() ?? 'Masjid',
        );
      } else if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text('Invalid or unrecognized Masjid QR code'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.getErrorMessage(e,
                fallback: 'Could not connect from this QR code')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            lang.tr(en: 'Connect with Masjid', ta: 'பள்ளிவாசலுடன் இணையவும்')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            }
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.secondary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              icon: const Icon(Icons.search),
              text: lang.tr(en: 'Search & Add', ta: 'தேடி இணைக்கவும்'),
            ),
            Tab(
              icon: const Icon(Icons.qr_code_scanner),
              text: lang.tr(en: 'Scan QR Code', ta: 'QR ஸ்கேன்'),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Search & Add
          _buildSearchAndAddTab(lang, isEn),

          // Tab 2: Scan QR Code
          _buildQrScannerTab(lang, isEn),
        ],
      ),
    );
  }

  Widget _buildSearchAndAddTab(LanguageNotifier lang, bool isEn) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.tr(
                      en: 'Find your masjid',
                      ta: 'உங்கள் பள்ளிவாசலைத் தேடுங்கள்',
                    ),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    lang.tr(
                      en: 'Search by masjid name, city, or address, then connect.',
                      ta: 'பெயர், ஊர் அல்லது முகவரி மூலம் தேடி இணையுங்கள்.',
                    ),
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon:
                          const Icon(Icons.search, color: AppColors.primary),
                      hintText: lang.tr(
                        en: 'Search masjid by name or city...',
                        ta: 'பள்ளிவாசல் பெயர் அல்லது ஊர் தேடுக...',
                      ),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip:
                                  lang.tr(en: 'Clear search', ta: 'நீக்கு'),
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchCtrl.clear();
                                _onSearchChanged('');
                              },
                            ),
                      filled: true,
                      fillColor: const Color(0xFFF7F8FA),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.outline),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.sort, size: 19, color: Colors.grey.shade700),
                      const SizedBox(width: 6),
                      Text(
                        lang.tr(en: 'Sort by', ta: 'வரிசை'),
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _sort,
                          underline: const SizedBox.shrink(),
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: 'NAME_ASC',
                              child: Text(
                                  lang.tr(en: 'Name A–Z', ta: 'பெயர் A–Z')),
                            ),
                            DropdownMenuItem(
                              value: 'NAME_DESC',
                              child: Text(
                                  lang.tr(en: 'Name Z–A', ta: 'பெயர் Z–A')),
                            ),
                            DropdownMenuItem(
                              value: 'NEAREST',
                              child: Text(lang.tr(
                                  en: 'Nearest to me', ta: 'அருகிலுள்ளவை')),
                            ),
                          ],
                          onChanged: _selectSort,
                        ),
                      ),
                      if (_sort == 'NEAREST' && _userLatitude != null)
                        Text(
                          lang.tr(en: 'Nearby', ta: 'அருகில்'),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  if (_searchTooShort)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Text(
                        lang.tr(
                          en: 'Type at least 3 characters. Results search after you pause typing.',
                          ta: 'குறைந்தது 3 எழுத்துகள் உள்ளிடுங்கள். தட்டச்சை நிறுத்தியதும் தேடப்படும்.',
                        ),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_isSearching) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _isLoading && _filteredMasjids.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _filteredMasjids.isEmpty
                  ? _buildMasjidSearchEmptyState(lang)
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                              child: Text(
                                _isSearching
                                    ? lang.tr(
                                        en: 'Searching masjids…',
                                        ta: 'பள்ளிவாசல்கள் தேடப்படுகின்றன…',
                                      )
                                    : lang.tr(
                                        en: '$_totalMasjids masjid${_totalMasjids == 1 ? '' : 's'} found',
                                        ta: '$_totalMasjids பள்ளிவாசல்கள் கிடைத்தன',
                                      ),
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                controller: _resultsScrollController,
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                itemCount: _filteredMasjids.length +
                                    (_isLoadingMore || _loadError != null
                                        ? 1
                                        : 0),
                                itemBuilder: (context, index) {
                                  if (index >= _filteredMasjids.length) {
                                    if (_loadError != null) {
                                      return Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: OutlinedButton.icon(
                                            onPressed: () => _loadMasjids(),
                                            icon: const Icon(Icons.refresh),
                                            label: Text(lang.tr(
                                              en: 'Could not load more · Retry',
                                              ta: 'மேலும் ஏற்ற முடியவில்லை · மீண்டும் முயற்சி',
                                            )),
                                          ),
                                        ),
                                      );
                                    }
                                    return const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  return _buildMasjidResultCard(
                                    _filteredMasjids[index],
                                    lang,
                                    isEn,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildMasjidSearchEmptyState(LanguageNotifier lang) {
    final query = _searchCtrl.text.trim();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mosque_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              _loadError != null
                  ? lang.tr(
                      en: 'Could not load masjids',
                      ta: 'பள்ளிவாசல்களை ஏற்ற முடியவில்லை',
                    )
                  : _isSearching
                      ? lang.tr(en: 'Searching masjids…', ta: 'தேடுகிறது…')
                      : query.isEmpty
                          ? lang.tr(
                              en: 'No masjids are available right now',
                              ta: 'தற்போது பள்ளிவாசல்கள் இல்லை',
                            )
                          : lang.tr(
                              en: 'No masjids found for "$query"',
                              ta: '"$query" க்கு பள்ளிவாசல்கள் இல்லை',
                            ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            if (_loadError != null) ...[
              const SizedBox(height: 8),
              Text(
                lang.tr(
                  en: 'Check your connection and retry.',
                  ta: 'இணைப்பைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _loadMasjids(reset: true),
                icon: const Icon(Icons.refresh),
                label: Text(lang.tr(en: 'Retry', ta: 'மீண்டும் முயற்சி')),
              ),
            ] else if (query.isNotEmpty && !_isSearching) ...[
              const SizedBox(height: 6),
              Text(
                lang.tr(
                  en: 'Check the spelling or try a nearby city name.',
                  ta: 'எழுத்துப்பிழையைச் சரிபார்த்து, ஊர் பெயரையும் முயற்சிக்கவும்.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMasjidResultCard(
    dynamic masjid,
    LanguageNotifier lang,
    bool isEn,
  ) {
    final map = Map<String, dynamic>.from(masjid as Map);
    final name = isEn
        ? (map['name'] ?? 'Masjid').toString()
        : (map['nameTa'] ?? map['name'] ?? 'பள்ளிவாசல்').toString();
    final city = (map['city'] ?? '').toString().trim();
    final address = (map['address'] ?? '').toString().trim();
    final location = [
      if (address.isNotEmpty) address,
      if (city.isNotEmpty && city.toLowerCase() != address.toLowerCase()) city,
    ].join(' • ');
    final distanceKm = (map['distanceKm'] as num?)?.toDouble();
    final masjidId = map['id']?.toString();
    final isConnected =
        masjidId != null && _connectedMasjidIds.contains(masjidId);
    final isThisConnecting =
        _isProcessing && masjidId != null && _connectingMasjidId == masjidId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.mosque,
                      color: AppColors.primary, size: 27),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          location,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                      if (distanceKm != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          distanceKm < 1
                              ? '${(distanceKm * 1000).round()} m away'
                              : '${distanceKm.toStringAsFixed(1)} km away',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runAlignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => _openMasjidLocation(map),
                  icon: const Icon(Icons.directions_outlined, size: 18),
                  label: Text(lang.tr(en: 'Location', ta: 'இடம்')),
                ),
                FilledButton.icon(
                  onPressed: _isProcessing ||
                          _isLoadingConnectedMasjids ||
                          masjidId == null ||
                          isConnected
                      ? null
                      : () => _handleJoinMasjid(masjidId, name),
                  icon: _isLoadingConnectedMasjids
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : isThisConnecting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              isConnected
                                  ? Icons.check_circle_outline
                                  : Icons.add_link,
                              size: 18),
                  label: Text(_isLoadingConnectedMasjids
                      ? lang.tr(en: 'Checking…', ta: 'சரிபார்க்கிறது…')
                      : isConnected
                          ? lang.tr(en: 'Connected', ta: 'இணைக்கப்பட்டது')
                          : isThisConnecting
                              ? lang.tr(en: 'Connecting…', ta: 'இணைக்கிறது…')
                              : lang.tr(en: 'Connect', ta: 'இணை')),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrScannerTab(LanguageNotifier lang, bool isEn) {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: _onQrDetected,
        ),
        // Overlay Instruction
        Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code_scanner,
                    color: AppColors.secondary, size: 36),
                const SizedBox(height: 8),
                Text(
                  lang.tr(
                    en: 'Point camera at Masjid QR Code to instantly connect',
                    ta: 'உடனடியாக இணைய பள்ளிவாசல் QR குறியீட்டை ஸ்கேன் செய்யவும்',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                if (_isProcessing) ...[
                  const SizedBox(height: 12),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: AppColors.secondary, strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
