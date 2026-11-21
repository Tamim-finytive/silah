import 'package:flutter/material.dart';
import 'package:masjid_namaz_app/core/constants/app_colors.dart';
import 'package:masjid_namaz_app/core/constants/app_spacing.dart';
import 'package:masjid_namaz_app/core/network/api_service.dart';
import 'package:masjid_namaz_app/features/prayer_times/presentation/screens/home_screen.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  Map<String, dynamic>? _stats;
  List<dynamic> _pendingRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    final data = await ApiService.instance.getSuperAdminStats();
    final pending = await ApiService.instance.getPendingMasjidRequests();
    if (mounted) {
      setState(() {
        _stats = data;
        _pendingRequests = pending;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleApprove(String masjidId, String masjidName) async {
    try {
      final res = await ApiService.instance.approveMasjidRequest(masjidId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Text(res['message'] ?? 'Masjid "$masjidName" approved!'),
          ),
        );
        _fetchStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('Failed to approve: $e'),
          ),
        );
      }
    }
  }

  Future<void> _handleReject(String masjidId, String masjidName) async {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject Request: $masjidName'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'e.g. Duplicate location, incomplete address',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.instance.rejectMasjidRequest(masjidId, reasonCtrl.text.trim());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.orange.shade800,
                      content: Text('Request for "$masjidName" rejected.'),
                    ),
                  );
                  _fetchStats();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to reject: $e')),
                  );
                }
              }
            },
            child: const Text('Confirm Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _pendingRequests.length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to User App',
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
          title: const Text('Super Admin Portal'),
          backgroundColor: const Color(0xFF072A1A),
          bottom: TabBar(
            indicatorColor: Colors.amber,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              const Tab(
                icon: Icon(Icons.dashboard_outlined),
                text: 'Overview',
              ),
              Tab(
                icon: Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text('$pendingCount'),
                  child: const Icon(Icons.domain_verification),
                ),
                text: 'Masjid Management',
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchStats,
              tooltip: 'Refresh',
            ),
            TextButton.icon(
              icon: const Icon(Icons.mosque, color: AppColors.secondary, size: 20),
              label: const Text('User App', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildOverviewTab(),
                  _buildMasjidManagementTab(),
                ],
              ),
      ),
    );
  }

  // TAB 1: OVERVIEW
  Widget _buildOverviewTab() {
    final metrics = _stats?['metrics'] ?? {
      'totalMasjids': 2,
      'totalUsers': 4,
      'totalFollowers': 1,
      'totalSandhaCollected': '0.00',
      'pendingRequestsCount': _pendingRequests.length,
    };

    final recentMasjids = (_stats?['recentMasjids'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Super Admin Badge
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.security, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Super Administrator',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onPrimaryContainer),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Full System Control • Database Live',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Pending Requests Alert Banner
          if (_pendingRequests.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade400, width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pending_actions, color: Colors.amber, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_pendingRequests.length} Pending Masjid Creation Requests',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Review applicant details & approve to grant Masjid Admin role.',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Metrics Grid (2x2)
          Row(
            children: [
              _buildMetricTile('Masjids', '${metrics['totalMasjids']}', Icons.account_balance, Colors.teal),
              const SizedBox(width: 12),
              _buildMetricTile('Total Users', '${metrics['totalUsers']}', Icons.people, Colors.blue),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricTile('Pending Requests', '${metrics['pendingRequestsCount'] ?? _pendingRequests.length}', Icons.pending, Colors.orange),
              const SizedBox(width: 12),
              _buildMetricTile('Sandha Total', '₹${metrics['totalSandhaCollected']}', Icons.savings, AppColors.success),
            ],
          ),
          const SizedBox(height: 24),

          // Quick Action Buttons
          const Text('System Operations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_business),
            label: const Text('Add New Masjid Directly'),
            onPressed: _showAddMasjidDialog,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.person_add),
            label: const Text('Create User / Assign Role'),
            onPressed: _showAddUserDialog,
          ),
          const SizedBox(height: 24),

          // Registered Masjids
          const Text('Recently Active Masjids', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (recentMasjids.isEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.mosque, color: AppColors.primary),
                title: const Text('Jamia Masjid (Chennai)'),
                subtitle: const Text('12 Anna Salai • Active'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                  child: const Text('LIVE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ),
          ...recentMasjids.map((m) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.mosque, color: AppColors.primary),
                title: Text('${m['name']} (${m['city'] ?? ''})'),
                subtitle: Text(m['address'] ?? ''),
                trailing: const Icon(Icons.chevron_right),
              ),
            );
          }),
        ],
      ),
    );
  }

  // TAB 2: MASJID MANAGEMENT (Request Approve Sub-Tab)
  Widget _buildMasjidManagementTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.grey.shade100,
            child: const TabBar(
              labelColor: Color(0xFF072A1A),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF072A1A),
              tabs: [
                Tab(text: 'Request Approve (Pending)'),
                Tab(text: 'Active Masjids'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildPendingApprovalsList(),
                _buildActiveMasjidsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingApprovalsList() {
    if (_pendingRequests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.task_alt, size: 64, color: Colors.green),
              SizedBox(height: 16),
              Text('No Pending Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(
                'All new masjid creation requests have been approved or processed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingRequests.length,
      itemBuilder: (ctx, index) {
        final m = _pendingRequests[index];
        final creator = m['creator'] as Map<String, dynamic>?;
        final lat = m['latitude'];
        final lng = m['longitude'];

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        m['name'] ?? 'Untitled Masjid',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'PENDING APPROVAL',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                      ),
                    ),
                  ],
                ),
                if (m['nameTa'] != null && (m['nameTa'] as String).isNotEmpty)
                  Text(m['nameTa'], style: const TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),

                // Location Details
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${m['address'] ?? ''}, ${m['city'] ?? ''}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                if (lat != null && lng != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.gps_fixed, size: 16, color: Colors.blue),
                      const SizedBox(width: 6),
                      Text(
                        'Lat: $lat, Lng: $lng',
                        style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 20),

                // Applicant Info
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFF072A1A),
                        child: Icon(Icons.person, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Applicant: ${creator?['name'] ?? 'User'}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'Phone: ${creator?['phone'] ?? 'N/A'} • Age: ${creator?['age'] ?? 'N/A'}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Action Buttons: Approve / Reject
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close, color: Colors.red, size: 18),
                        label: const Text('Reject', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _handleReject(m['id'], m['name']),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check, color: Colors.white, size: 18),
                        label: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade800,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _handleApprove(m['id'], m['name']),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveMasjidsList() {
    final recentMasjids = (_stats?['recentMasjids'] as List<dynamic>?) ?? [];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: recentMasjids.length,
      itemBuilder: (ctx, index) {
        final m = recentMasjids[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFEAF7EE),
              child: Icon(Icons.mosque, color: Color(0xFF0F432B)),
            ),
            title: Text('${m['name']} (${m['city'] ?? ''})'),
            subtitle: Text(m['address'] ?? ''),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
              child: const Text('ACTIVE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricTile(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                Icon(icon, color: color, size: 22),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMasjidDialog() {
    final nameCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register Masjid'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Masjid Name')),
              TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'City')),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final city = cityCtrl.text.trim();
              final address = addressCtrl.text.trim();
              if (name.isEmpty || city.isEmpty) return;

              Navigator.pop(ctx);
              try {
                await ApiService.instance.createMasjid(
                  name: name,
                  city: city,
                  address: address.isEmpty ? city : address,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.green.shade800,
                      content: Text('Masjid "$name" created in database!'),
                    ),
                  );
                  _fetchStats();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog() {
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create User / Role'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'User Name')),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Mobile Number')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final phone = phoneCtrl.text.trim();
              if (phone.isEmpty) return;

              Navigator.pop(ctx);
              try {
                await ApiService.instance.sendOtp(phone);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.green.shade800,
                      content: Text('User $phone registered in database!'),
                    ),
                  );
                  _fetchStats();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
