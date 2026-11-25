import 'package:masjid_namaz_app/core/constants/app_colors.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masjid_namaz_app/core/l10n/language_provider.dart';
import 'package:masjid_namaz_app/core/network/api_service.dart';
import 'package:masjid_namaz_app/core/services/notification_service.dart';
import 'package:masjid_namaz_app/features/prayer_times/presentation/screens/home_screen.dart';
import 'package:masjid_namaz_app/features/admin/presentation/screens/super_admin_masjid_details_screen.dart';
import 'package:masjid_namaz_app/features/auth/presentation/screens/otp_login_screen.dart';
import 'package:masjid_namaz_app/features/masjid/presentation/widgets/location_input_widget.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  final bool openContactRequests;

  const SuperAdminDashboardScreen({
    super.key,
    this.openContactRequests = false,
  });

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
  List<dynamic> _requestItems = [];
  List<dynamic> _supportRequestItems = [];
  String _requestType = 'MASJID';
  String _supportRequestStatus = 'OPEN';
  int _supportRequestPage = 1;
  int _supportRequestTotal = 0;
  bool _loadingMoreSupportRequests = false;
  bool _hasMoreSupportRequests = true;
  String? _supportRequestError;
  String _requestStatus = 'PENDING';
  int _requestPage = 0;
  int _requestTotal = 0;
  bool _loadingMoreRequests = false;
  bool _hasMoreRequests = true;
  String? _requestLoadError;
  int _requestGeneration = 0;
  List<dynamic> _users = [];
  List<dynamic> _broadcasts = [];
  String _userSearchQuery = '';
  String _masjidSearchQuery = '';
  String _masjidStatus = 'ALL';
  String _masjidApprovalStatus = 'ALL';
  String _masjidSort = 'CREATED_DESC';
  DateTimeRange? _masjidCreatedRange;
  int _masjidPage = 1;
  int _masjidTotal = 0;
  int _masjidGeneration = 0;
  int _usersPage = 1;
  int _usersTotal = 0;
  final ScrollController _masjidScrollController = ScrollController();
  final ScrollController _usersScrollController = ScrollController();
  final ScrollController _requestScrollController = ScrollController();
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
    if (widget.openContactRequests) {
      _currentIndex = 2;
      _requestType = 'CONTACT';
    }
    _masjidScrollController.addListener(_onMasjidScroll);
    _usersScrollController.addListener(_onUsersScroll);
    _requestScrollController.addListener(_onRequestScroll);
    _loadAllData();
    if (widget.openContactRequests) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadSupportRequestPage(reset: true);
      });
    }
    _notificationSubscription =
        NotificationService.instance.notificationEvents.listen((event) {
      if (event['opened'] == true &&
          event['type'] == 'SUPPORT_REQUEST' &&
          mounted) {
        _openContactRequests();
        return;
      }
      if (event['opened'] == true && event['type'] == 'BROADCAST' && mounted) {
        setState(() => _currentIndex = 3);
        _loadAllData();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending =
          NotificationService.instance.takePendingNotificationEvent();
      if (pending != null &&
          pending['type'] == 'SUPPORT_REQUEST' &&
          mounted) {
        _openContactRequests();
      } else if (pending != null &&
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
    _requestScrollController.dispose();
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

  void _onRequestScroll() {
    if (_currentIndex != 2 || !_requestScrollController.hasClients) return;
    if (_requestScrollController.position.extentAfter < 320) {
      if (_requestType == 'CONTACT') {
        _loadSupportRequestPage();
      } else {
        _loadRequestPage();
      }
    }
  }

  Future<void> _loadAllData() async {
    final masjidGeneration = ++_masjidGeneration;
    setState(() => _isLoading = true);
    try {
      final stats = await ApiService.instance.getSuperAdminStats();
      final masjidPage = await ApiService.instance.getAdminMasjids(
        search: _masjidSearchQuery,
        status: _masjidStatus,
        approvalStatus: _masjidApprovalStatus,
        sort: _masjidSort,
        createdFrom: _masjidCreatedRange?.start,
        createdTo: _masjidCreatedRange?.end,
        page: 1,
      );
      final requestStatus = _requestStatus;
      final requestGeneration = ++_requestGeneration;
      final requestPage = await ApiService.instance.getAdminMasjids(
        approvalStatus: requestStatus,
        page: 1,
      );
      final usersRes =
          await ApiService.instance.getUsers(search: _userSearchQuery, page: 1);
      final broadcasts = await ApiService.instance.getBroadcastAnnouncements();
      Map<String, dynamic>? supportRequests;
      try {
        supportRequests =
            await ApiService.instance.getSuperAdminSupportRequests(
          status: _supportRequestStatus,
          page: 1,
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _stats = stats;
          if (masjidGeneration == _masjidGeneration) {
            _allMasjids = masjidPage?['items'] ?? [];
            _masjidTotal = masjidPage?['total'] ?? 0;
            _masjidPage = 1;
            _hasMoreMasjids = _allMasjids.length < _masjidTotal;
            _masjidLoadError = masjidPage == null
                ? 'Masjids could not be loaded. Pull down or tap refresh to try again.'
                : null;
            _loadingMoreMasjids = false;
          }
          if (requestStatus == _requestStatus &&
              requestGeneration == _requestGeneration) {
            _requestItems = requestPage?['items'] as List<dynamic>? ?? [];
            _requestPage = 1;
            _requestTotal = (requestPage?['total'] as num?)?.toInt() ?? 0;
            _hasMoreRequests = _requestItems.length < _requestTotal;
            _requestLoadError = requestPage == null
                ? 'Could not load masjid requests. Tap refresh to retry.'
                : null;
          }
          _users = usersRes?['items'] ?? [];
          _usersTotal = usersRes?['total'] ?? 0;
          _usersPage = 1;
          _hasMoreUsers = _users.length < _usersTotal;
          _usersLoadError = usersRes == null
              ? 'Users could not be loaded from the backend. Tap refresh to retry.'
              : null;
          _broadcasts = broadcasts;
          if (supportRequests != null) {
            _supportRequestItems =
                supportRequests['items'] as List<dynamic>? ?? [];
            _supportRequestPage = 1;
            _supportRequestTotal =
                (supportRequests['total'] as num?)?.toInt() ?? 0;
            _hasMoreSupportRequests = _supportRequestItems.length <
                _supportRequestTotal;
            _supportRequestError = null;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMasjidPage({bool reset = false}) async {
    if ((!reset && _loadingMoreMasjids) || (!reset && !_hasMoreMasjids)) return;
    final generation = reset ? ++_masjidGeneration : _masjidGeneration;
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
        approvalStatus: _masjidApprovalStatus,
        sort: _masjidSort,
        createdFrom: _masjidCreatedRange?.start,
        createdTo: _masjidCreatedRange?.end,
        page: page,
      );
      if (result == null) throw StateError('Masjid directory request failed');
      if (!mounted || generation != _masjidGeneration) return;
      final items = (result['items'] as List<dynamic>? ?? []);
      setState(() {
        _allMasjids = reset ? items : [..._allMasjids, ...items];
        _masjidPage = page;
        _masjidTotal = (result['total'] as num?)?.toInt() ?? _allMasjids.length;
        _hasMoreMasjids = _allMasjids.length < _masjidTotal;
      });
    } catch (error) {
      if (mounted && generation == _masjidGeneration)
        setState(
            () => _masjidLoadError = 'Could not load more masjids: $error');
    } finally {
      if (mounted && generation == _masjidGeneration) {
        setState(() => _loadingMoreMasjids = false);
      }
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

  Future<void> _loadRequestPage({bool reset = false}) async {
    if ((!reset && _loadingMoreRequests) || (!reset && !_hasMoreRequests)) {
      return;
    }
    final generation = ++_requestGeneration;
    final requestStatus = _requestStatus;
    final page = reset ? 1 : _requestPage + 1;
    setState(() {
      _loadingMoreRequests = true;
      _requestLoadError = null;
      if (reset) {
        _requestItems = [];
        _requestPage = 0;
        _requestTotal = 0;
        _hasMoreRequests = true;
      }
    });
    try {
      final result = await ApiService.instance.getAdminMasjids(
        approvalStatus: requestStatus,
        page: page,
      );
      if (result == null) throw StateError('Request list could not be loaded');
      if (!mounted || generation != _requestGeneration) return;
      final items = result['items'] as List<dynamic>? ?? [];
      setState(() {
        _requestItems = reset ? items : [..._requestItems, ...items];
        _requestPage = page;
        _requestTotal =
            (result['total'] as num?)?.toInt() ?? _requestItems.length;
        _hasMoreRequests = _requestItems.length < _requestTotal;
      });
    } catch (error) {
      if (mounted && generation == _requestGeneration) {
        setState(() => _requestLoadError =
            'Could not load requests: ${ApiService.getErrorMessage(error)}');
      }
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _loadingMoreRequests = false);
      }
    }
  }

  void _openContactRequests() {
    if (!mounted) return;
    setState(() {
      _currentIndex = 2;
      _requestType = 'CONTACT';
      _supportRequestStatus = 'OPEN';
    });
    _loadSupportRequestPage(reset: true);
  }

  Future<void> _loadSupportRequestPage({bool reset = false}) async {
    if (_loadingMoreSupportRequests ||
        (!reset && !_hasMoreSupportRequests)) return;
    final generation = ++_requestGeneration;
    final page = reset ? 1 : _supportRequestPage + 1;
    final status = _supportRequestStatus;
    setState(() {
      _loadingMoreSupportRequests = true;
      _supportRequestError = null;
      if (reset) {
        _supportRequestItems = [];
        _supportRequestPage = 0;
        _supportRequestTotal = 0;
        _hasMoreSupportRequests = true;
      }
    });
    try {
      final result = await ApiService.instance.getSuperAdminSupportRequests(
        status: status,
        page: page,
      );
      if (!mounted || generation != _requestGeneration) return;
      final items = result['items'] as List<dynamic>? ?? [];
      setState(() {
        _supportRequestItems =
            reset ? items : [..._supportRequestItems, ...items];
        _supportRequestPage = page;
        _supportRequestTotal =
            (result['total'] as num?)?.toInt() ?? _supportRequestItems.length;
        _hasMoreSupportRequests =
            _supportRequestItems.length < _supportRequestTotal;
      });
    } catch (error) {
      if (mounted && generation == _requestGeneration) {
        setState(() => _supportRequestError =
            'Could not load Contact Us messages: ${ApiService.getErrorMessage(error)}');
      }
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _loadingMoreSupportRequests = false);
      }
    }
  }

  void _changeSupportRequestStatus(String? status) {
    if (status == null || status == _supportRequestStatus) return;
    setState(() => _supportRequestStatus = status);
    _loadSupportRequestPage(reset: true);
  }

  Future<void> _updateSupportRequestStatus(
      Map<String, dynamic> request, String status) async {
    final id = request['id']?.toString();
    if (id == null) return;
    try {
      await ApiService.instance.updateSuperAdminSupportRequestStatus(id, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Contact message marked ${status.toLowerCase().replaceAll('_', ' ')}.'),
      ));
      await _loadSupportRequestPage(reset: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ApiService.getErrorMessage(error)),
      ));
    }
  }

  void _changeRequestStatus(String? status) {
    if (status == null || status == _requestStatus) return;
    setState(() => _requestStatus = status);
    _loadRequestPage(reset: true);
  }

  // -------------------------------------------------------------
  // TAB 1: System Dashboard
  // -------------------------------------------------------------
  Widget _buildOverviewTab() {
    final metrics = _stats?['metrics'] ?? {};
    final recentMasjids = (_stats?['recentMasjids'] as List<dynamic>?) ?? [];
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const AppLanguageText('System Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
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
                    const Icon(Icons.pending_actions, color: AppColors.primary),
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
                          const Icon(Icons.mosque, color: AppColors.primary),
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
  Future<void> _chooseMasjidCreatedRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _masjidCreatedRange,
      helpText: 'Filter masjids by creation date',
    );
    if (!mounted) return;
    setState(() => _masjidCreatedRange = range);
    _loadMasjidPage(reset: true);
  }

  String _shortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  ({IconData icon, Color color, String label}) _approvalPresentation(
      String status) {
    switch (status) {
      case 'APPROVED':
        return (
          icon: Icons.check_circle,
          color: Colors.green,
          label: 'Approved'
        );
      case 'PENDING':
        return (
          icon: Icons.schedule,
          color: Colors.orange,
          label: 'Pending approval'
        );
      case 'REJECTED':
        return (icon: Icons.cancel, color: Colors.red, label: 'Rejected');
      default:
        return (
          icon: Icons.help,
          color: Colors.grey,
          label: 'Approval status unknown'
        );
    }
  }

  Widget _buildMasjidsTab() {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const AppLanguageText('Masjid Directory',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Masjid'),
        onPressed: _showCreateMasjidDialog,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
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
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<String>(
                      value: _masjidStatus,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                            value: 'ALL', child: Text('All activity')),
                        DropdownMenuItem(
                            value: 'ACTIVE', child: Text('Active')),
                        DropdownMenuItem(
                            value: 'STOPPED', child: Text('Stopped')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _masjidStatus = value);
                        _loadMasjidPage(reset: true);
                      },
                    ),
                    DropdownButton<String>(
                      value: _masjidApprovalStatus,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                            value: 'ALL', child: Text('Any approval')),
                        DropdownMenuItem(
                            value: 'APPROVED', child: Text('Approved')),
                        DropdownMenuItem(
                            value: 'PENDING', child: Text('Pending')),
                        DropdownMenuItem(
                            value: 'REJECTED', child: Text('Rejected')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _masjidApprovalStatus = value);
                        _loadMasjidPage(reset: true);
                      },
                    ),
                    DropdownButton<String>(
                      value: _masjidSort,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                            value: 'CREATED_DESC', child: Text('Newest')),
                        DropdownMenuItem(
                            value: 'CREATED_ASC', child: Text('Oldest')),
                        DropdownMenuItem(
                            value: 'NAME_ASC', child: Text('Name A–Z')),
                        DropdownMenuItem(
                            value: 'NAME_DESC', child: Text('Name Z–A')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _masjidSort = value);
                        _loadMasjidPage(reset: true);
                      },
                    ),
                    OutlinedButton.icon(
                      onPressed: _chooseMasjidCreatedRange,
                      icon: const Icon(Icons.date_range, size: 17),
                      label: Text(_masjidCreatedRange == null
                          ? 'Date range'
                          : '${_shortDate(_masjidCreatedRange!.start)} – ${_shortDate(_masjidCreatedRange!.end)}'),
                    ),
                    if (_masjidCreatedRange != null)
                      IconButton(
                        tooltip: 'Clear date range',
                        onPressed: () {
                          setState(() => _masjidCreatedRange = null);
                          _loadMasjidPage(reset: true);
                        },
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              ],
            ),
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
                              final approvalView =
                                  _approvalPresentation(approval);
                              final createdAt = DateTime.tryParse(
                                  m['createdAt']?.toString() ?? '');
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 1,
                                child: ListTile(
                                  onTap: () => _showMasjidDetails(m),
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    child: const Icon(Icons.mosque,
                                        color: AppColors.primary),
                                  ),
                                  title: Text(
                                    m['name'] ?? 'Unnamed Masjid',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
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
                                      if (createdAt != null) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                            'Created ${_shortDate(createdAt.toLocal())}',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey)),
                                      ],
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Tooltip(
                                        message: approvalView.label,
                                        child: IconButton(
                                          constraints:
                                              const BoxConstraints.tightFor(
                                                  width: 38, height: 40),
                                          padding: EdgeInsets.zero,
                                          icon: Icon(approvalView.icon,
                                              color: approvalView.color,
                                              size: 22),
                                          onPressed: () => ScaffoldMessenger.of(
                                              context)
                                            ..hideCurrentSnackBar()
                                            ..showSnackBar(SnackBar(
                                                content:
                                                    Text(approvalView.label),
                                                duration: const Duration(
                                                    seconds: 2))),
                                        ),
                                      ),
                                      Tooltip(
                                        message: active ? 'Active' : 'Stopped',
                                        child: Icon(
                                          Icons.circle,
                                          size: 12,
                                          color: active
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
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
              const SizedBox(height: 12),
              TextField(
                  controller: cityCtrl,
                  decoration: const InputDecoration(labelText: 'City *')),
              const SizedBox(height: 12),
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
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assign Masjid Administrator',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.primary)),
                    const SizedBox(height: 4),
                    const Text(
                        'This admin will be registered and can directly login to manage this masjid.',
                        style: TextStyle(fontSize: 11, color: Colors.black54)),
                    TextField(
                        controller: adminNameCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Admin Name (e.g. Ahmed)')),
                    const SizedBox(height: 12),
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
                backgroundColor: AppColors.primary,
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
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ApiService.getErrorMessage(e))));
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const AppLanguageText('Requests',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'MASJID',
                    icon: Icon(Icons.mosque_outlined),
                    label: Text('Masjid requests'),
                  ),
                  ButtonSegment(
                    value: 'CONTACT',
                    icon: Icon(Icons.support_agent_outlined),
                    label: Text('Contact Us'),
                  ),
                ],
                selected: {_requestType},
                onSelectionChanged: (value) {
                  final next = value.first;
                  if (next == _requestType) return;
                  setState(() => _requestType = next);
                  if (next == 'CONTACT') {
                    _loadSupportRequestPage(reset: true);
                  } else {
                    _loadRequestPage(reset: true);
                  }
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: _requestType == 'MASJID'
                ? DropdownButtonFormField<String>(
              value: _requestStatus,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Request status',
                prefixIcon: Icon(Icons.filter_list, size: 20),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'PENDING',
                    child: Text('Waiting for approval',
                        style: TextStyle(fontSize: 13))),
                DropdownMenuItem(
                    value: 'APPROVED',
                    child: Text('Approved', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(
                    value: 'REJECTED',
                    child: Text('Rejected', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(
                    value: 'ALL',
                    child:
                        Text('All requests', style: TextStyle(fontSize: 13))),
              ],
              onChanged: _changeRequestStatus,
                  )
                : DropdownButtonFormField<String>(
                    initialValue: _supportRequestStatus,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Contact message status',
                      prefixIcon: Icon(Icons.filter_list, size: 20),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'OPEN', child: Text('Open messages')),
                      DropdownMenuItem(
                          value: 'IN_PROGRESS', child: Text('In progress')),
                      DropdownMenuItem(
                          value: 'RESOLVED', child: Text('Resolved')),
                      DropdownMenuItem(
                          value: 'ALL', child: Text('All messages')),
                    ],
                    onChanged: _changeSupportRequestStatus,
                  ),
          ),
          Expanded(
            child: _requestType == 'CONTACT'
                ? _buildSupportRequestsList()
                : _isLoading && _requestItems.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _requestLoadError != null && _requestItems.isEmpty
                    ? _buildRetryState(
                        _requestLoadError!,
                        () => _loadRequestPage(reset: true),
                        Icons.pending_actions,
                      )
                    : _requestItems.isEmpty
                        ? _buildEmptyState(
                            _requestStatus == 'PENDING'
                                ? 'No Pending Registration Requests'
                                : 'No Requests Found',
                            Icons.check_circle_outline,
                          )
                        : RefreshIndicator(
                            onRefresh: () => _loadRequestPage(reset: true),
                            child: ListView.builder(
                              controller: _requestScrollController,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              itemCount: _requestItems.length +
                                  (_loadingMoreRequests ||
                                          _requestLoadError != null
                                      ? 1
                                      : 0),
                              itemBuilder: (ctx, i) {
                                if (i == _requestItems.length) {
                                  return _requestLoadError != null
                                      ? TextButton(
                                          onPressed: _loadRequestPage,
                                          child: Text(_requestLoadError!),
                                        )
                                      : const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                }
                                final req =
                                    _requestItems[i] as Map<String, dynamic>;
                                final creator = req['creator'] ?? {};
                                final approval =
                                    req['approvalStatus']?.toString() ??
                                        'PENDING';
                                final city =
                                    (req['city'] ?? '').toString().trim();
                                final address =
                                    (req['address'] ?? '').toString().trim();
                                final locationText = [
                                  if (city.isNotEmpty) city,
                                  if (address.isNotEmpty) address,
                                ].join(' • ');

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(
                                        color: AppColors.outline),
                                  ),
                                  elevation: 0,
                                  color: Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 11),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color:
                                                    AppColors.primaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Icon(Icons.mosque,
                                                  color: AppColors.primary,
                                                  size: 18),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                req['name'] ?? 'Unnamed',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: approval == 'APPROVED'
                                                    ? Colors.green.shade50
                                                    : approval == 'REJECTED'
                                                        ? Colors.red.shade50
                                                        : Colors.amber.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: approval == 'APPROVED'
                                                      ? Colors.green.shade300
                                                      : approval == 'REJECTED'
                                                          ? Colors.red.shade300
                                                          : Colors
                                                              .amber.shade300,
                                                ),
                                              ),
                                              child: Text(
                                                approval,
                                                style: TextStyle(
                                                  color: approval == 'APPROVED'
                                                      ? Colors.green.shade800
                                                      : approval == 'REJECTED'
                                                          ? Colors.red.shade800
                                                          : Colors
                                                              .amber.shade900,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (locationText.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Icon(Icons.location_on_outlined,
                                                  size: 14,
                                                  color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  locationText,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Icon(Icons.person_outline,
                                                size: 14,
                                                color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'Applicant: ${creator['name'] ?? 'Unknown'} (${creator['phone'] ?? ''})',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (approval == 'PENDING') ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              SizedBox(
                                                height: 32,
                                                child: OutlinedButton(
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.red,
                                                    side: const BorderSide(
                                                        color: Colors.red),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 14),
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                  ),
                                                  onPressed: () =>
                                                      _handleReject(req['id'],
                                                          req['name'] ?? ''),
                                                  child: const Text('Reject',
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              SizedBox(
                                                height: 32,
                                                child: FilledButton(
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor:
                                                        AppColors.primary,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 16),
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                  ),
                                                  onPressed: () =>
                                                      _handleApprove(req['id'],
                                                          req['name'] ?? ''),
                                                  child: const Text('Approve',
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportRequestsList() {
    if (_supportRequestItems.isEmpty && _loadingMoreSupportRequests) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_supportRequestItems.isEmpty && _supportRequestError != null) {
      return _buildRetryState(
        _supportRequestError!,
        () => _loadSupportRequestPage(reset: true),
        Icons.support_agent_outlined,
      );
    }
    if (_supportRequestItems.isEmpty) {
      return _buildEmptyState(
        _supportRequestStatus == 'OPEN'
            ? 'No new Contact Us messages'
            : 'No Contact Us messages found',
        Icons.mark_email_read_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadSupportRequestPage(reset: true),
      child: ListView.builder(
        controller: _requestScrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: _supportRequestItems.length +
            (_loadingMoreSupportRequests || _supportRequestError != null
                ? 1
                : 0),
        itemBuilder: (context, index) {
          if (index == _supportRequestItems.length) {
            return _supportRequestError != null
                ? TextButton(
                    onPressed: _loadSupportRequestPage,
                    child: Text(_supportRequestError!),
                  )
                : const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
          }
          final request =
              _supportRequestItems[index] as Map<String, dynamic>;
          final status = request['status']?.toString() ?? 'OPEN';
          final createdAt =
              DateTime.tryParse(request['createdAt']?.toString() ?? '');
          final statusColor = status == 'RESOLVED'
              ? Colors.green
              : status == 'IN_PROGRESS'
                  ? Colors.orange
                  : AppColors.primary;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.outline),
            ),
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: AppColors.primaryContainer,
                        child: Icon(Icons.support_agent,
                            color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          request['subject']?.toString() ?? 'Contact request',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.replaceAll('_', ' '),
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 5,
                    children: [
                      _contactDetail(Icons.person_outline,
                          request['name']?.toString() ?? '—'),
                      _contactDetail(Icons.phone_outlined,
                          request['phone']?.toString() ?? '—'),
                      if (createdAt != null)
                        _contactDetail(Icons.calendar_today_outlined,
                            _shortDate(createdAt.toLocal())),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    request['message']?.toString() ?? '',
                    style: const TextStyle(
                        color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (status == 'OPEN')
                        OutlinedButton.icon(
                          onPressed: () => _updateSupportRequestStatus(
                              request, 'IN_PROGRESS'),
                          icon: const Icon(Icons.pending_actions, size: 17),
                          label: const Text('In progress'),
                        ),
                      if (status != 'RESOLVED')
                        FilledButton.icon(
                          onPressed: () =>
                              _updateSupportRequestStatus(request, 'RESOLVED'),
                          icon: const Icon(Icons.check, size: 17),
                          label: const Text('Resolve'),
                        )
                      else
                        TextButton.icon(
                          onPressed: () =>
                              _updateSupportRequestStatus(request, 'OPEN'),
                          icon: const Icon(Icons.refresh, size: 17),
                          label: const Text('Reopen'),
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

  Widget _contactDetail(IconData icon, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      );

  Future<void> _handleApprove(String id, String name) async {
    try {
      final res = await ApiService.instance.approveMasjidRequest(id);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res['message'] ?? 'Approved!')));
      _loadAllData();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ApiService.getErrorMessage(e))));
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
              try {
                await ApiService.instance
                    .rejectMasjidRequest(id, reasonCtrl.text.trim());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Request rejected.')));
                }
                _loadAllData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ApiService.getErrorMessage(e))));
                }
              }
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const AppLanguageText('Broadcast Announcements',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.campaign),
        label: const Text('New Broadcast'),
        onPressed: _showBroadcastDialog,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primaryContainer,
                child: Icon(Icons.support_agent, color: AppColors.primary),
              ),
              title: const Text('Contact Us messages',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('$_supportRequestTotal open messages from users.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openContactRequests,
            ),
          ),
          if (_broadcasts.isEmpty)
            _buildEmptyState(
                'No Broadcast Messages Sent Yet', Icons.campaign_outlined)
          else
            ..._broadcasts.map((b) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading:
                        const Icon(Icons.campaign, color: AppColors.primary),
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
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(ApiService.getErrorMessage(e))));
                        }
                      },
                    ),
                  ),
                )),
        ],
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
                  backgroundColor: AppColors.primary,
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const AppLanguageText('User Management',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
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
                                    backgroundColor: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    child: Text(
                                      (userName.isEmpty ? 'U' : userName[0])
                                          .toUpperCase(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary),
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
                const SizedBox(height: 12),
                TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Mobile Number (+91...) *')),
                const SizedBox(height: 12),
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
                  backgroundColor: AppColors.primary,
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
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ApiService.getErrorMessage(e))));
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const AppLanguageText('Super Admin Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AppLanguageSettingsTile(),
          const Divider(height: 1),
          // Header Card
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: AppColors.primary,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.security,
                        size: 40, color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),
                  const AppLanguageText('Super Administrator',
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
          const AppLanguageText('System Live Metrics',
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
            leading: const Icon(Icons.switch_account, color: AppColors.primary),
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
          Icon(icon, size: 20, color: AppColors.primary),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ApiService.getErrorMessage(e))));
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
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ApiService.getErrorMessage(e))));
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
    return Consumer(builder: (context, ref, _) {
      ref.watch(languageProvider);
      final language = ref.read(languageProvider.notifier);
      return Scaffold(
        body: _buildSelectedTab(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) {
            setState(() => _currentIndex = i);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (i == 1) _onMasjidScroll();
              if (i == 4) _onUsersScroll();
            });
          },
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: language.text('Overview'),
            ),
            NavigationDestination(
              icon: Icon(Icons.mosque_outlined),
              selectedIcon: Icon(Icons.mosque_rounded),
              label: language.text('Masjids'),
            ),
            NavigationDestination(
              icon: Icon(Icons.pending_actions_outlined),
              selectedIcon: Icon(Icons.pending_actions_rounded),
              label: language.text('Requests'),
            ),
            NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign_rounded),
              label: language.text('Notices'),
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people_rounded),
              label: language.text('Users'),
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded),
              label: language.text('Profile'),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSelectedTab() {
    switch (_currentIndex) {
      case 1:
        return _buildMasjidsTab();
      case 2:
        return _buildRequestsTab();
      case 3:
        return _buildAnnouncementsTab();
      case 4:
        return _buildUsersTab();
      case 5:
        return _buildProfileTab();
      default:
        return _buildOverviewTab();
    }
  }
}
