import 'package:masjid_namaz_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:masjid_namaz_app/core/network/api_service.dart';
import 'package:masjid_namaz_app/core/utils/prayer_time_format.dart';

class SuperAdminMasjidDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> masjid;

  const SuperAdminMasjidDetailsScreen({super.key, required this.masjid});

  Future<Map<String, dynamic>> _load() async {
    final id = masjid['id'].toString();
    final result = await Future.wait([
      ApiService.instance.getMasjidAdminOverview(id),
      ApiService.instance.getMasjidMembers(id),
      ApiService.instance.getTodayPrayerTimes(id),
    ]);
    return {
      'overview': result[0],
      'members': result[1],
      'times': result[2],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(masjid['name']?.toString() ?? 'Masjid dashboard'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _load(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || snapshot.data == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Masjid details could not be loaded.'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) =>
                                  SuperAdminMasjidDetailsScreen(masjid: masjid),
                            ),
                          ),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final data = snapshot.data!;
              final overview = data['overview'] as Map<String, dynamic>? ?? {};
              final metrics =
                  overview['metrics'] as Map<String, dynamic>? ?? {};
              final membersData =
                  data['members'] as Map<String, dynamic>? ?? {};
              final members =
                  membersData['memberships'] as List<dynamic>? ?? [];
              final admins = membersData['admins'] as List<dynamic>? ?? [];
              final times = data['times'] as Map<String, dynamic>?;
              final location = [
                masjid['address'],
                masjid['city'],
                masjid['state']
              ]
                  .where((part) =>
                      part != null && part.toString().trim().isNotEmpty)
                  .join(', ');

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionCard(
                    title: 'Masjid overview',
                    icon: Icons.mosque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(location.isEmpty
                            ? 'Address not provided'
                            : location),
                        const SizedBox(height: 8),
                        Text(
                            'Status: ${masjid['approvalStatus'] ?? '—'} · ${masjid['isActive'] == true ? 'Active' : 'Stopped'}'),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _metric(
                                'Connected members',
                                '${metrics['memberCount'] ?? masjid['_count']?['memberships'] ?? members.length}',
                                Icons.people),
                            _metric('Masjid admins', '${admins.length}',
                                Icons.admin_panel_settings),
                            _metric(
                                'Monthly Sandha due',
                                '₹${metrics['monthlySandhaExpected'] ?? '—'}',
                                Icons.account_balance_wallet),
                            _metric(
                                'Collected this month',
                                '₹${metrics['currentMonthSandhaCollected'] ?? '—'}',
                                Icons.currency_rupee),
                          ],
                        ),
                        if (location.isNotEmpty ||
                            masjid['mapUrl'] != null) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _openMap(masjid),
                            icon: const Icon(Icons.directions),
                            label: const Text('Open location in Maps'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _sectionCard(
                    title: "Today's prayer timings",
                    icon: Icons.schedule,
                    child: times == null
                        ? const Text('No timings are saved for today.')
                        : Column(
                            children: [
                              _prayerRow('Fajr', times['fajrAdhan'],
                                  times['fajrJamaah']),
                              _prayerRow('Dhuhr', times['dhuhrAdhan'],
                                  times['dhuhrJamaah']),
                              _prayerRow(
                                  'Asr', times['asrAdhan'], times['asrJamaah']),
                              _prayerRow('Maghrib', times['maghribAdhan'],
                                  times['maghribJamaah']),
                              _prayerRow('Isha', times['ishaAdhan'],
                                  times['ishaJamaah']),
                              _prayerRow('Jummah', times['jummahKhutbah'],
                                  times['jummahJamaah']),
                            ],
                          ),
                  ),
                  _sectionCard(
                    title: 'Administrators (${admins.length})',
                    icon: Icons.admin_panel_settings,
                    child: admins.isEmpty
                        ? const Text('No administrators are assigned.')
                        : Column(
                            children: admins.map((item) {
                              final admin = item as Map<String, dynamic>;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const CircleAvatar(
                                    child: Icon(Icons.person)),
                                title: Text(admin['name']?.toString() ??
                                    'Unnamed admin'),
                                subtitle: Text(
                                    '${admin['phone'] ?? ''} · ${admin['role'] ?? 'Admin'}'),
                              );
                            }).toList(),
                          ),
                  ),
                  _sectionCard(
                    title: 'Connected members (${members.length})',
                    icon: Icons.groups,
                    child: members.isEmpty
                        ? const Text('No members are connected yet.')
                        : Column(
                            children: members.map((item) {
                              final member = item as Map<String, dynamic>;
                              final address = member['address']?.toString();
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const CircleAvatar(
                                    child: Icon(Icons.person_outline)),
                                title: Text(member['name']
                                            ?.toString()
                                            .trim()
                                            .isNotEmpty ==
                                        true
                                    ? member['name'].toString()
                                    : 'Unnamed member'),
                                subtitle: Text([
                                  member['phone']?.toString(),
                                  if (address != null &&
                                      address.trim().isNotEmpty)
                                    address,
                                ]
                                    .whereType<String>()
                                    .where((value) => value.isNotEmpty)
                                    .join(' · ')),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _sectionCard(
      {required String title, required IconData icon, required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold))
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon) {
    return SizedBox(
      width: 155,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFF1F6F2),
            borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: AppColors.primary, size: 19),
          const SizedBox(height: 8),
          Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ]),
      ),
    );
  }

  Widget _prayerRow(String name, dynamic adhan, dynamic jamaah) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(
            child: Text(name,
                style: const TextStyle(fontWeight: FontWeight.w600))),
        Text(formatPrayerTime(adhan?.toString())),
        const SizedBox(width: 16),
        SizedBox(
            width: 86,
            child: Text(
                jamaah == null ? '—' : formatPrayerTime(jamaah.toString()),
                textAlign: TextAlign.end)),
      ]),
    );
  }

  Future<void> _openMap(Map<String, dynamic> item) async {
    final mapUrl = item['mapUrl']?.toString();
    final lat = item['latitude']?.toString();
    final lng = item['longitude']?.toString();
    final query = lat != null && lng != null
        ? '$lat,$lng'
        : '${item['name'] ?? ''}, ${item['city'] ?? ''}';
    final uri = mapUrl != null && mapUrl.startsWith('http')
        ? Uri.tryParse(mapUrl)
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
