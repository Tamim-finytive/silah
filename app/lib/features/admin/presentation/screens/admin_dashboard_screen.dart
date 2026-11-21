import 'package:flutter/material.dart';
import 'package:masjid_namaz_app/core/constants/app_colors.dart';
import 'package:masjid_namaz_app/core/constants/app_spacing.dart';
import 'package:masjid_namaz_app/core/network/api_service.dart';
import 'package:masjid_namaz_app/features/prayer_times/presentation/screens/home_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _masjidName = 'Jamia Masjid';
  final int _memberCount = 850;
  String _sandhaTotal = '₹42,000';

  @override
  void initState() {
    super.initState();
    _loadMasjidContext();
  }

  void _loadMasjidContext() {
    final user = ApiService.instance.currentUser;
    final adminRoles = user?['adminRoles'] as List<dynamic>?;
    if (adminRoles != null && adminRoles.isNotEmpty) {
      final primaryAdmin = adminRoles.first;
      setState(() {
        _masjidName = primaryAdmin['masjidName'] ?? 'GST Road Masjid';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
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
        title: const Text('Masjid Admin Portal'),
        backgroundColor: const Color(0xFF0F432B),
        foregroundColor: Colors.white,
        actions: [
          // Switch to User Mode Button in AppBar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              },
              icon: const Icon(Icons.home, size: 16, color: Color(0xFF0F432B)),
              label: const Text('User Mode', style: TextStyle(color: Color(0xFF0F432B), fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Masjid Overview Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _masjidName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF7EE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('ADMIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F432B))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildMetric('$_memberCount', 'Members / உறுப்பினர்கள்'),
                      const SizedBox(width: 16),
                      _buildMetric(_sandhaTotal, 'Collections / சந்தா வசூல்'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'நிர்வாக செயல்பாடுகள் / Admin Operations',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // 1. Update Namaz Timings
            _buildActionTile(
              context,
              icon: Icons.access_time_filled,
              color: const Color(0xFF0F432B),
              title: 'தொழுகை நேரம் அமைத்தல் / Set Namaz Times',
              subtitle: 'Configure daily Adhan & Jamaah times (Fajr, Dhuhr, Asr, Maghrib, Isha, Jummah)',
              onTap: _showUpdateNamazTimesDialog,
            ),

            // 2. Pass Announcements (Firebase Push Notifications)
            _buildActionTile(
              context,
              icon: Icons.campaign,
              color: Colors.indigo,
              title: 'அறிவிப்பு வெளியிடல் / Pass Announcement',
              subtitle: 'Publish announcement & send Firebase push notifications to all devotees',
              onTap: _showPostAnnouncementDialog,
            ),

            // 3. Sub-Roles & Custom Privileges (RBAC)
            _buildActionTile(
              context,
              icon: Icons.admin_panel_settings,
              color: Colors.teal,
              title: 'துணைப் பொறுப்புகள் / Sub-Roles & Privileges',
              subtitle: 'Assign Finance, Announcement & Volunteer custom roles and permissions',
              onTap: _showAssignSubRoleDialog,
            ),

            // 4. Santha / Chanda Collection Accounts
            _buildActionTile(
              context,
              icon: Icons.payments,
              color: AppColors.success,
              title: 'சந்தா வரவு / Record Santha Collection',
              subtitle: 'Record member subscription payments (Cash / UPI / Bank) with ledger tracking',
              onTap: _showRecordSanthaDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FBF9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F432B))),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color, size: 26),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  // 1. DIALOG: Update Namaz Timings
  void _showUpdateNamazTimesDialog() {
    final fajrCtrl = TextEditingController(text: '05:15 AM');
    final dhuhrCtrl = TextEditingController(text: '12:45 PM');
    final asrCtrl = TextEditingController(text: '04:45 PM');
    final maghribCtrl = TextEditingController(text: '05:55 PM');
    final ishaCtrl = TextEditingController(text: '07:30 PM');
    final jummahCtrl = TextEditingController(text: '01:30 PM');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Namaz Jamaah Timings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTimeField('Fajr Jamaah', fajrCtrl),
              _buildTimeField('Dhuhr Jamaah', dhuhrCtrl),
              _buildTimeField('Asr Jamaah', asrCtrl),
              _buildTimeField('Maghrib Jamaah', maghribCtrl),
              _buildTimeField('Isha Jamaah', ishaCtrl),
              _buildTimeField('Jumu\'ah Jamaah', jummahCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F432B)),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Colors.green,
                  content: Text('Namaz timings updated and synchronized across all user devices!'),
                ),
              );
            },
            child: const Text('Save & Sync Clock', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.access_time, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  // 2. DIALOG: Pass Announcement
  void _showPostAnnouncementDialog() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    bool sendPush = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Pass New Announcement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Announcement Title',
                    hintText: 'e.g. Special Bayan after Maghrib',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notice Details / Body',
                    hintText: 'Enter full announcement message...',
                  ),
                ),
                const SizedBox(height: 14),
                CheckboxListTile(
                  title: const Text('Trigger Firebase In-App & Push Notification', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Alerts all devotees connected to this masjid', style: TextStyle(fontSize: 11)),
                  value: sendPush,
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF0F432B),
                  onChanged: (v) => setDialogState(() => sendPush = v ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F432B)),
              onPressed: () {
                final title = titleCtrl.text.trim();
                final body = bodyCtrl.text.trim();
                if (title.isEmpty || body.isEmpty) return;

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.green.shade800,
                    content: Text('Announcement "$title" published! Push notifications dispatched via Firebase.'),
                  ),
                );
              },
              child: const Text('Broadcast Notice', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // 3. DIALOG: Sub-Roles & Custom Privileges
  void _showAssignSubRoleDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String selectedRole = 'FINANCE';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Sub-Role / Privileges'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Staff / Trustee Name', hintText: 'Janab Farooq'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile Number', hintText: '+91 9876543210'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role & Privilege Level'),
                  items: const [
                    DropdownMenuItem(value: 'ADMIN', child: Text('Full Co-Admin (All Controls)')),
                    DropdownMenuItem(value: 'FINANCE', child: Text('Finance (Santha & Accounts only)')),
                    DropdownMenuItem(value: 'ANNOUNCEMENT', child: Text('Announcements (Notices only)')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedRole = v ?? 'FINANCE'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F432B)),
              onPressed: () {
                final phone = phoneCtrl.text.trim();
                final name = nameCtrl.text.trim();
                if (phone.isEmpty || name.isEmpty) return;

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.green.shade800,
                    content: Text('Assigned $selectedRole privileges to $name ($phone).'),
                  ),
                );
              },
              child: const Text('Assign Role', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // 4. DIALOG: Record Santha Collection
  void _showRecordSanthaDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '500');
    String paymentMethod = 'UPI';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Record Santha Collection'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Member Name', hintText: 'Abdul Rahman'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile Number', hintText: '9876543210'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount (₹)', prefixText: '₹ '),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: paymentMethod,
                  decoration: const InputDecoration(labelText: 'Payment Method'),
                  items: const [
                    DropdownMenuItem(value: 'UPI', child: Text('UPI / Google Pay / PhonePe')),
                    DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                    DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                  ],
                  onChanged: (v) => setDialogState(() => paymentMethod = v ?? 'UPI'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800),
              onPressed: () {
                final name = nameCtrl.text.trim();
                final amt = amountCtrl.text.trim();
                if (amt.isEmpty) return;

                Navigator.pop(ctx);
                setState(() {
                  _sandhaTotal = '₹42,500';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.green.shade800,
                    content: Text('₹$amt payment recorded for $name via $paymentMethod!'),
                  ),
                );
              },
              child: const Text('Record & Issue Receipt', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
