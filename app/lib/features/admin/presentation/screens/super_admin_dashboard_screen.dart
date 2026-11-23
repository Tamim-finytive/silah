import 'dart:async';
import 'package:flutter/material.dart';
import 'package:masjid_namaz_app/core/network/api_service.dart';
import 'package:masjid_namaz_app/core/services/notification_service.dart';
import 'package:masjid_namaz_app/features/prayer_times/presentation/screens/home_screen.dart';
import 'package:masjid_namaz_app/features/admin/presentation/screens/super_admin_masjid_details_screen.dart';
import 'package:masjid_namaz_app/features/auth/presentation/screens/otp_login_screen.dart';
import 'package:masjid_namaz_app/features/masjid/presentation/widgets/location_input_widget.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() =>
      _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;

  // Data states directly from backend
  Map<String, dynamic>? _stats;
  List<dynamic> _allMasjids = [];
  List<dynamic> _pendingRequests = [];
  List<dynamic> _users = [];
  List<dynamic> _broadcasts = [];
  String _userSearchQuery = '';
  String _masjidSearchQuery = '';
  String _masjidStatus = 'ALL';
  int _masjidPage = 1;
  int _masjidTotal = 0;
  int _usersPage = 1;
  int _usersTotal = 0;
  final ScrollController _masjidScrollController = ScrollController();
  final ScrollController _usersScrollController = ScrollController();
  bool _loadingMoreMasjids = false;
  bool _loadingMoreUsers = false;
  bool _hasMoreMasjids = true;
  bool _hasMoreUsers = true;
  String? _masjidLoadError;
  String? _usersLoadError;
  Timer? _searchDebounce;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _masjidScrollController.addListener(_onMasjidScroll);
    _usersScrollController.addListener(_onUsersScroll);
    _loadAllData();
    _notificationSubscription =
        NotificationService.instance.notificationEvents.listen((event) {
      if (event['opened'] == true && event['type'] == 'BROADCAST' && mounted) {
        setState(() => _currentIndex = 3);
        _loadAllData();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending =
          NotificationService.instance.takePendingNotificationEvent();
      if (pending != null &&
          pending['opened'] == true &&
          pending['type'] == 'BROADCAST' &&
          mounted) {
        setState(() => _currentIndex = 3);
        _loadAllData();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _notificationSubscription?.cancel();
    _masjidScrollController.dispose();
    _usersScrollController.dispose();
    super.dispose();
  }

  void _onMasjidScroll() {
    if (_currentIndex != 1 ||
        !_masjidScrollController.hasClients ||
        _loadingMoreMasjids ||
        !_hasMoreMasjids) return;
    if (_masjidScrollController.position.extentAfter < 320) {
      _loadMasjidPage();
    }
  }

  void _onUsersScroll() {
    if (_currentIndex != 4 ||
        !_usersScrollController.hasClients ||
        _loadingMoreUsers ||
        !_hasMoreUsers) return;
    if (_usersScrollController.position.extentAfter < 320) {
      _loadUsersPage();
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await ApiService.instance.getSuperAdminStats();
      final masjidPage = await ApiService.instance.getAdminMasjids(
        search: _masjidSearchQuery,
        status: _masjidStatus,
        page: 1,
      );
      final pending = await ApiService.instance.getPendingMasjidRequests();
      final usersRes =
          await ApiService.instance.getUsers(search: _userSearchQuery, page: 1);
      final broadcasts = await ApiService.instance.getBroadcastAnnouncements();

      if (mounted) {
        setState(() {
          _stats = stats;
          _allMasjids = masjidPage?['items'] ?? [];
          _masjidTotal = masjidPage?['total'] ?? 0;
          _masjidPage = 1;
          _hasMoreMasjids = _allMasjids.length < _masjidTotal;
          _masjidLoadError = masjidPage == null
              ? 'Masjids could not be loaded. Pull down or tap refresh to try again.'
              : null;
          _pendingRequests = pending;
          _users = usersRes?['items'] ?? [];
          _usersTotal = usersRes?['total'] ?? 0;
          _usersPage = 1;
          _hasMoreUsers = _users.length < _usersTotal;
          _usersLoadError = usersRes == null
              ? 'Users could not be loaded from the backend. Tap refresh to retry.'
              : null;
          _broadcasts = broadcasts;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMasjidPage({bool reset = false}) async {
    if (_loadingMoreMasjids || (!reset && !_hasMoreMasjids)) return;
    final page = reset ? 1 : _masjidPage + 1;
    setState(() {
      _loadingMoreMasjids = true;
      _masjidLoadError = null;
      if (reset) {
        _allMasjids = [];
        _masjidPage = 0;
        _masjidTotal = 0;
        _hasMoreMasjids = true;
      }
    });
    try {
      final result = await ApiService.instance.getAdminMasjids(
        search: _masjidSearchQuery,
        status: _masjidStatus,
        page: page,
      );
      if (result == null) throw StateError('Masjid directory request failed');
      if (!mounted) return;
      final items = (result['items'] as List<dynamic>? ?? []);
      setState(() {
        _allMasjids = reset ? items : [..._allMasjids, ...items];
        _masjidPage = page;
        _masjidTotal = (result['total'] as num?)?.toInt() ?? _allMasjids.length;
        _hasMoreMasjids = _allMasjids.length < _masjidTotal;
      });
    } catch (error) {
      if (mounted)
        setState(
            () => _masjidLoadError = 'Could not load more masjids: $error');
    } finally {
      if (mounted) setState(() => _loadingMoreMasjids = false);
    }
  }

  Future<void> _loadUsersPage({bool reset = false}) async {
    if (_loadingMoreUsers || (!reset && !_hasMoreUsers)) return;
    final page = reset ? 1 : _usersPage + 1;
    setState(() {
      _loadingMoreUsers = true;
      _usersLoadError = null;
      if (reset) {
        _users = [];
        _usersPage = 0;
        _usersTotal = 0;
        _hasMoreUsers = true;
      }
    });
    try {
      final result = await ApiService.instance.getUsers(
        search: _userSearchQuery,
        page: page,
      );
      if (result == null) throw StateError('Users list request failed');
      if (!mounted) return;
      final items = (result['items'] as List<dynamic>? ?? []);
      setState(() {
        _users = reset ? items : [..._users, ...items];
        _usersPage = page;
        _usersTotal = (result['total'] as num?)?.toInt() ?? _users.length;
        _hasMoreUsers = _users.length < _usersTotal;
      });
    } catch (error) {
      if (mounted)
        setState(() => _usersLoadError = 'Could not load users: $error');
    } finally {
      if (mounted) setState(() => _loadingMoreUsers = false);
    }
  }

  // -------------------------------------------------------------
  // TAB 1: System Dashboard
  // -------------------------------------------------------------
  Widget _buildOverviewTab() {
    final metrics = _stats?['metrics'] ?? {};
    final recentMasjids = (_stats?['recentMasjids'] as List<dynamic>?) ?? [];
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      appBar: AppBar(
        title: const Text('System Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F432B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData)
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [
                Expanded(
                    child: _metricCard('Active Masjids',
                        '${metrics['totalMasjids'] ?? 0}', Icons.mosque)),
                const SizedBox(width: 10),
                Expanded(
                    child: _metricCard('Registered Users',
                        '${metrics['totalUsers'] ?? 0}', Icons.people)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _metricCard(
                        'Users Active · 30 days',
                        '${metrics['activeUsersLast30Days'] ?? 0}',
                        Icons.person_pin_circle)),
                const SizedBox(width: 10),
                Expanded(
                    child: _metricCard(
                        'Requests Waiting',
                        '${metrics['pendingRequestsCount'] ?? 0}',
                        Icons.pending_actions)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _metricCard(
                        'Monthly Sandha Due',
                        '₹${metrics['monthlySandhaExpected'] ?? 0}',
                        Icons.account_balance_wallet)),
                const SizedBox(width: 10),
                Expanded(
                    child: _metricCard(
                        'Collected This Month',
                        '₹${metrics['currentMonthSandhaCollected'] ?? 0}',
                        Icons.currency_rupee)),
              ]),
              const SizedBox(height: 20),
              Card(
                  child: ListTile(
                leading:
                    const Icon(Icons.pending_actions, color: Color(0xFF0F432B)),
                title: const Text('Review masjid requests'),
                subtitle: Text(
                    '${metrics['pendingRequestsCount'] ?? 0} waiting for a decision'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() => _currentIndex = 2),
              )),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Recently Added Masjids',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                TextButton(
                    onPressed: () => setState(() => _currentIndex = 1),
                    child: const Text('View directory')),
              ]),
              if (recentMasjids.isEmpty)
                _buildEmptyState(
                    'No masjids have been created yet', Icons.mosque_outlined)
              else
                ...recentMasjids.map((item) {
                  final masjid = item as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading:
                          const Icon(Icons.mosque, color: Color(0xFF0F432B)),
                      title: Text(masjid['name']?.toString() ?? 'Masjid'),
                      subtitle: Text(
                          '${masjid['city'] ?? ''} · ${masjid['_count']?['memberships'] ?? 0} members'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showMasjidDetails(masjid),
                    ),
                  );
                }),
            ]),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: Masjids List & Create
  // -------------------------------------------------------------
  Widget _buildMasjidsTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      appBar: AppBar(
        title: const Text('Masjid Directory',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F432B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F432B),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Masjid'),
        onPressed: _showCreateMasjidDialog,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search masjid, city, or address',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    _masjidSearchQuery = value;
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(const Duration(milliseconds: 350),
                        () => _loadMasjidPage(reset: true));
                  },
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _masjidStatus,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All')),
                  DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                  DropdownMenuItem(value: 'INACTIVE', child: Text('Stopped')),
                  DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _masjidStatus = value);
                  _loadMasjidPage(reset: true);
                },
              ),
            ]),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allMasjids.isEmpty && _loadingMoreMasjids
                    ? const Center(child: CircularProgressIndicator())
                    : _allMasjids.isEmpty
                        ? _buildRetryState(
                            _masjidLoadError ?? 'No Masjids Found',
                            () => _loadMasjidPage(reset: true),
                            Icons.mosque)
                        : ListView.builder(
                            controller: _masjidScrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _allMasjids.length +
                                (_loadingMoreMasjids || _masjidLoadError != null
                                    ? 1
                                    : 0),
                            itemBuilder: (ctx, i) {
                              if (i == _allMasjids.length) {
                                return _masjidLoadError != null
                                    ? TextButton(
                                        onPressed: _loadMasjidPage,
                                        child: Text(_masjidLoadError!))
                                    : const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                            child:
                                                CircularProgressIndicator()));
                              }
                              final m = _allMasjids[i] as Map<String, dynamic>;
                              final active = m['isActive'] == true;
                              final approval =
                                  m['approvalStatus']?.toString() ?? 'UNKNOWN';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 1,
                                child: ListTile(
                                  onTap: () => _showMasjidDetails(m),
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF0F432B)
                                        .withValues(alpha: 0.1),
                                    child: const Icon(Icons.mosque,
                                        color: Color(0xFF0F432B)),
                                  ),
                                  title: Text(
                                    m['name'] ?? 'Unnamed Masjid',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (m['nameTa'] != null)
                                        Text(m['nameTa'],
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on,
                                              size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              '${m['city'] ?? ''}, ${m['address'] ?? ''}',
                                              style:
                                                  const TextStyle(fontSize: 12),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: active
                                              ? Colors.green.shade50
                                              : Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: active
                                                  ? Colors.green.shade300
                                                  : Colors.grey.shade400),
                                        ),
                                        child: Text(
                                            active
                                                ? approval
                                                : (approval == 'PENDING'
                                                    ? 'PENDING'
                                                    : 'STOPPED'),
                                            style: TextStyle(
                                                color: active
                                                    ? Colors.green.shade800
                                                    : Colors.grey.shade800,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 4),
                                      if (approval == 'APPROVED')
                                        IconButton(
                                          icon: Icon(
                                              active
                                                  ? Icons.pause_circle_outline
                                                  : Icons.play_circle_outline,
                                              color: const Color(0xFF0F432B),
                                              size: 21),
                                          tooltip: active
                                              ? 'Stop Masjid'
                                              : 'Activate Masjid',
                                          onPressed: () =>
                                              _setMasjidStatus(m, !active),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.red, size: 20),
                                        tooltip: 'Delete Masjid',
                                        onPressed: () =>
                                            _confirmDeleteMasjid(m),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _setMasjidStatus(
      Map<String, dynamic> masjid, bool active) async {
    try {
      await ApiService.instance
          .setMasjidActive(masjid['id'].toString(), active);
      await _loadAllData();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update masjid: $e')));
    }
  }

  Future<void> _showMasjidDetails(Map<String, dynamic> masjid) async {
    final id = masjid['id']?.toString();
    if (id == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SuperAdminMasjidDetailsScreen(masjid: masjid),
      ),
    );
  }

  void _showCreateMasjidDialog() {
    final nameCtrl = TextEditingController();
    final nameTaCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    final mapUrlCtrl = TextEditingController();
    final adminNameCtrl = TextEditingController();
    final adminPhoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Create New Masjid (Super Admin)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Masjid Name *')),
              TextField(
                  controller: nameTaCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Tamil Name (Optional)')),
              TextField(
                  controller: cityCtrl,
                  decoration: const InputDecoration(labelText: 'City *')),
              TextField(
                  controller: addrCtrl,
                  decoration: const InputDecoration(labelText: 'Address *')),
              const SizedBox(height: 12),
              LocationInputWidget(
                latController: latCtrl,
                lngController: lngCtrl,
                mapUrlController: mapUrlCtrl,
                masjidNameController: nameCtrl,
                cityController: cityCtrl,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F432B).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assign Masjid Administrator',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF0F432B))),
                    const SizedBox(height: 4),
                    const Text(
                        'This admin will be registered and can directly login to manage this masjid.',
                        style: TextStyle(fontSize: 11, color: Colors.black54)),
                    TextField(
                        controller: adminNameCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Admin Name (e.g. Ahmed)')),
                    TextField(
                      controller: adminPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                          labelText: 'Admin Mobile Number (10 digits) *',
                          hintText: '9876543210'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F432B),
                foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.isEmpty ||
                  cityCtrl.text.isEmpty ||
                  addrCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Please fill required fields')));
                return;
              }
              if (adminPhoneCtrl.text.trim().isNotEmpty &&
                  adminNameCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Enter the mapped administrator name')));
                return;
              }
              Navigator.pop(ctx);
              try {
                await ApiService.instance.createMasjid(
                  name: nameCtrl.text.trim(),
                  city: cityCtrl.text.trim(),
                  address: addrCtrl.text.trim(),
                  nameTa: nameTaCtrl.text.trim().isEmpty
                      ? null
                      : nameTaCtrl.text.trim(),
                  latitude: double.tryParse(latCtrl.text),
                  longitude: double.tryParse(lngCtrl.text),
                  mapUrl: mapUrlCtrl.text.trim().isEmpty
                      ? null
                      : mapUrlCtrl.text.trim(),
                  adminName: adminNameCtrl.text.trim().isEmpty
                      ? null
                      : adminNameCtrl.text.trim(),
                  adminPhone: adminPhoneCtrl.text.trim().isEmpty
                      ? null
                      : adminPhoneCtrl.text.trim(),
                );
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Masjid and Admin created successfully!')));
                _loadAllData();
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: Pending Approval Requests
  // -------------------------------------------------------------
  Widget _buildRequestsTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      appBar: AppBar(
        title: const Text('Masjid Approval Requests',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F432B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingRequests.isEmpty
              ? _buildEmptyState('No Pending Registration Requests',
                  Icons.check_circle_outline)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pendingRequests.length,
                  itemBuilder: (ctx, i) {
                    final req = _pendingRequests[i];
                    final creator = req['creator'] ?? {};
                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    req['name'] ?? 'Unnamed',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('PENDING',
                                      style: TextStyle(
                                          color: Colors.amber.shade900,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                                'City: ${req['city'] ?? ''} | Address: ${req['address'] ?? ''}',
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.grey)),
                            const Divider(height: 20),
                            Row(
                              children: [
                                const Icon(Icons.person,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                    'Applicant: ${creator['name'] ?? 'Unknown'} (${creator['phone'] ?? ''})',
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red),
                                  onPressed: () => _handleReject(
                                      req['id'], req['name'] ?? ''),
                                  child: const Text('Reject'),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F432B),
                                      foregroundColor: Colors.white),
                                  onPressed: () => _handleApprove(
                                      req['id'], req['name'] ?? ''),
                                  child: const Text('Accept & Approve'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _handleApprove(String id, String name) async {
    try {
      final res = await ApiService.instance.approveMasjidRequest(id);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res['message'] ?? 'Approved!')));
      _loadAllData();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _handleReject(String id, String name) async {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject: $name'),
        content: TextField(
            controller: reasonCtrl,
            decoration: const InputDecoration(labelText: 'Reason (optional)')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.instance
                  .rejectMasjidRequest(id, reasonCtrl.text.trim());
              _loadAllData();
            },
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 3: Global Announcements
  // -------------------------------------------------------------
  Widget _buildAnnouncementsTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      appBar: AppBar(
        title: const Text('Broadcast Announcements',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F432B),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F432B),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.campaign),
        label: const Text('New Broadcast'),
        onPressed: _showBroadcastDialog,
      ),
      body: _broadcasts.isEmpty
          ? _buildEmptyState(
              'No Broadcast Messages Sent Yet', Icons.campaign_outlined)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _broadcasts.length,
              itemBuilder: (ctx, i) {
                final b = _broadcasts[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading:
                        const Icon(Icons.campaign, color: Color(0xFF0F432B)),
                    title: Text(b['title'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '${b['body'] ?? ''}\n${b['publishedAt']?.toString().split('T')[0] ?? ''}'),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 20),
                      onPressed: () async {
                        try {
                          await ApiService.instance
                              .deleteBroadcastAnnouncement(b['id']);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Broadcast deleted!')));
                          _loadAllData();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed: $e')));
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showBroadcastDialog() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String targetAudience = 'All Users';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Send Broadcast Notice'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Target Audience:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: targetAudience,
                  items: const [
                    DropdownMenuItem(
                        value: 'All Users',
                        child: Text('All Users (System-wide)')),
                    DropdownMenuItem(
                        value: 'Admins Only',
                        child: Text('Masjid Admins Only')),
                    DropdownMenuItem(
                        value: 'Musallis Only', child: Text('Musallis Only')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDState(() => targetAudience = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title *')),
                const SizedBox(height: 10),
                TextField(
                    controller: bodyCtrl,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Message Body *')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F432B),
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (titleCtrl.text.isEmpty || bodyCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final res =
                      await ApiService.instance.sendBroadcastAnnouncement(
                    title: titleCtrl.text.trim(),
                    body: bodyCtrl.text.trim(),
                    targetAudience: targetAudience,
                  );
                  final recipients = res['data']?['recipientCount'] ?? 0;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.green.shade800,
                      content: Text(
                          'Broadcast sent to $targetAudience via Firebase Push ($recipients devices)!'),
                    ),
                  );
                  _loadAllData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to broadcast: $e')));
                }
              },
              child: const Text('Send Broadcast'),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 4: User Management
  // -------------------------------------------------------------
  Widget _buildUsersTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      appBar: AppBar(
        title: const Text('User Management',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F432B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F432B),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
        onPressed: _showAddUserDialog,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search user by name or phone...',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (val) {
                _userSearchQuery = val;
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 350),
                    () => _loadUsersPage(reset: true));
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty && _loadingMoreUsers
                    ? const Center(child: CircularProgressIndicator())
                    : _users.isEmpty
                        ? _buildRetryState(
                            _usersLoadError ?? 'No Users Found in Database',
                            () => _loadUsersPage(reset: true),
                            Icons.people_outline)
                        : ListView.builder(
                            controller: _usersScrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _users.length +
                                (_loadingMoreUsers || _usersLoadError != null
                                    ? 1
                                    : 0),
                            itemBuilder: (ctx, i) {
                              if (i == _users.length) {
                                return _usersLoadError != null
                                    ? TextButton(
                                        onPressed: _loadUsersPage,
                                        child: Text(_usersLoadError!))
                                    : const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                            child:
                                                CircularProgressIndicator()));
                              }
                              final u = _users[i];
                              final userName =
                                  u['name']?.toString().trim() ?? '';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF0F432B)
                                        .withValues(alpha: 0.1),
                                    child: Text(
                                      (userName.isEmpty ? 'U' : userName[0])
                                          .toUpperCase(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F432B)),
                                    ),
                                  ),
                                  title: Text(
                                      userName.isEmpty ? 'No Name' : userName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  onTap: () => _showUserDetails(
                                      u as Map<String, dynamic>),
                                  subtitle: Text(
                                      '${u['phone'] ?? ''} ${u['address'] != null ? '• ${u['address']}' : ''} · ${u['isActive'] == true ? 'Active' : 'Disabled'}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (u['isSuperAdmin'] == true) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                              color: Colors.purple.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(6)),
                                          child: const Text('SUPER ADMIN',
                                              style: TextStyle(
                                                  color: Colors.purple,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      IconButton(
                                        icon: Icon(
                                            u['isActive'] == true
                                                ? Icons.block
                                                : Icons.check_circle_outline,
                                            color: u['isActive'] == true
                                                ? Colors.orange
                                                : Colors.green,
                                            size: 20),
                                        tooltip: u['isActive'] == true
                                            ? 'Deactivate User'
                                            : 'Reactivate User',
                                        onPressed: () => _setUserStatus(
                                            u as Map<String, dynamic>,
                                            u['isActive'] != true),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.red, size: 20),
                                        tooltip: 'Delete User',
                                        onPressed: () => _confirmDeleteUser(
                                            u as Map<String, dynamic>),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _setUserStatus(Map<String, dynamic> user, bool active) async {
    try {
      await ApiService.instance.setUserActive(user['id'].toString(), active);
      await _loadAllData();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not update user: $e')));
    }
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(user['name']?.toString() ?? 'User details'),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mobile: ${user['phone'] ?? '—'}'),
                    Text('Address: ${user['address'] ?? '—'}'),
                    Text(
                        'Account: ${user['isActive'] == true ? 'Active' : 'Disabled'}'),
                    Text(
                        'Role: ${user['isSuperAdmin'] == true ? 'Super Admin' : 'User'}'),
                  ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'))
              ],
            ));
  }

  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    bool isSuper = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Add New User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Full Name *')),
                TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Mobile Number (+91...) *')),
                TextField(
                    controller: addrCtrl,
                    decoration: const InputDecoration(labelText: 'Address')),
                CheckboxListTile(
                  title: const Text('Make Super Admin'),
                  value: isSuper,
                  onChanged: (v) => setDState(() => isSuper = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F432B),
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await ApiService.instance.createUser({
                    'name': nameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'address': addrCtrl.text.trim().isEmpty
                        ? null
                        : addrCtrl.text.trim(),
                    'isSuperAdmin': isSuper,
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('User registered in database!')));
                  _loadAllData();
                } catch (e) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              },
              child: const Text('Add User'),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 5: Profile & System Stats
  // -------------------------------------------------------------
  Widget _buildProfileTab() {
    final metrics = _stats?['metrics'] ?? {};
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      appBar: AppBar(
        title: const Text('Super Admin Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F432B),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: const Color(0xFF0F432B),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.security,
                        size: 40, color: Color(0xFF0F432B)),
                  ),
                  const SizedBox(height: 12),
                  const Text('Super Administrator',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    ApiService.instance.currentUser?['phone']?.toString() ??
                        'Phone unavailable',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // System Metrics
          const Text('System Live Metrics',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _metricCard('Total Masjids',
                      '${metrics['totalMasjids'] ?? 0}', Icons.mosque)),
              const SizedBox(width: 10),
              Expanded(
                  child: _metricCard('Total Users',
                      '${metrics['totalUsers'] ?? 0}', Icons.people)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _metricCard('Followers',
                      '${metrics['totalFollowers'] ?? 0}', Icons.favorite)),
              const SizedBox(width: 10),
              Expanded(
                  child: _metricCard(
                      'Sandha Total',
                      '₹${metrics['totalSandhaCollected'] ?? 0}',
                      Icons.currency_rupee)),
            ],
          ),
          const SizedBox(height: 24),

          // Switch / Logout Options
          ListTile(
            tileColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.switch_account, color: Color(0xFF0F432B)),
            title: const Text('Switch to User App (Home)'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()));
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log Out',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () async {
              await ApiService.instance.clearSession();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const OtpLoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String title, String val, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF0F432B)),
          const SizedBox(height: 8),
          Text(val,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(msg,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildRetryState(String message, VoidCallback onRetry, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteMasjid(Map<String, dynamic> masjid) {
    final name = masjid['name'] ?? 'this Masjid';
    final id = masjid['id']?.toString() ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Masjid?',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "$name"? All its prayer timings, announcements, and schedules will be deleted from the database.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.instance.deleteMasjid(id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Masjid "$name" deleted successfully'),
                        backgroundColor: Colors.red),
                  );
                }
                _loadAllData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteUser(Map<String, dynamic> user) {
    final name = user['name'] ?? user['phone'] ?? 'this user';
    final id = user['id']?.toString() ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.person_remove, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete User?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
            'Are you sure you want to delete user "$name" (${user['phone'] ?? ''})?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.instance.deleteUser(id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('User "$name" deleted successfully'),
                        backgroundColor: Colors.red),
                  );
                }
                _loadAllData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildOverviewTab(),
          _buildMasjidsTab(),
          _buildRequestsTab(),
          _buildAnnouncementsTab(),
          _buildUsersTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() => _currentIndex = i);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (i == 1) _onMasjidScroll();
            if (i == 4) _onUsersScroll();
          });
        },
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.mosque_outlined),
            selectedIcon: Icon(Icons.mosque_rounded),
            label: 'Masjids',
          ),
          NavigationDestination(
            icon: Icon(Icons.pending_actions_outlined),
            selectedIcon: Icon(Icons.pending_actions_rounded),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign_rounded),
            label: 'Notices',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
