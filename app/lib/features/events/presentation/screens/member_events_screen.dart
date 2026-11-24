import 'package:flutter/material.dart';
import 'package:masjid_namaz_app/core/constants/app_colors.dart';
import 'package:masjid_namaz_app/core/network/api_service.dart';

class MemberEventsScreen extends StatefulWidget {
  final String masjidId;
  final String masjidName;

  const MemberEventsScreen({
    super.key,
    required this.masjidId,
    required this.masjidName,
  });

  @override
  State<MemberEventsScreen> createState() => _MemberEventsScreenState();
}

class _MemberEventsScreenState extends State<MemberEventsScreen> {
  late Future<List<dynamic>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = ApiService.instance.getSpecialSchedules(widget.masjidId);
  }

  Future<void> _refresh() async {
    final future = ApiService.instance.getSpecialSchedules(widget.masjidId);
    setState(() => _eventsFuture = future);
    await future;
  }

  DateTime? _eventDate(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());

  String _dateLabel(DateTime? date) => date == null
      ? 'Date not set'
      : '${date.day.toString().padLeft(2, '0')} ${_monthName(date.month)} ${date.year}';

  String _monthName(int month) => const [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ][month - 1];

  void _showEvent(dynamic raw) {
    if (raw is! Map) return;
    final event = Map<String, dynamic>.from(raw);
    final start = _eventDate(event['startDate']);
    final end = _eventDate(event['endDate']);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event['title']?.toString() ?? 'Event',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 14),
              _detail(
                  Icons.calendar_month_outlined,
                  end == null || end == start
                      ? _dateLabel(start)
                      : '${_dateLabel(start)} – ${_dateLabel(end)}'),
              const SizedBox(height: 10),
              _detail(Icons.schedule_outlined,
                  '${event['startTime'] ?? 'Time not set'}${event['endTime'] == null ? '' : ' – ${event['endTime']}'}'),
              if ((event['notes']?.toString() ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(event['notes'].toString(),
                    style: Theme.of(context).textTheme.bodyLarge),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Events'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: FutureBuilder<List<dynamic>>(
          future: _eventsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary));
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.cloud_off_outlined, size: 44),
                    const SizedBox(height: 12),
                    const Text('Could not load events.'),
                    TextButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ]),
                ),
              );
            }
            final events = [...?snapshot.data]..sort((a, b) {
                final aDate = a is Map ? _eventDate(a['startDate']) : null;
                final bDate = b is Map ? _eventDate(b['startDate']) : null;
                return (aDate ?? DateTime(2100))
                    .compareTo(bDate ?? DateTime(2100));
              });
            if (events.isEmpty) {
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 140),
                    Icon(Icons.event_busy_outlined,
                        size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Center(child: Text('No events scheduled yet.')),
                    Center(child: Text(widget.masjidName)),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final raw = events[index];
                  if (raw is! Map) return const SizedBox.shrink();
                  final event = Map<String, dynamic>.from(raw);
                  final start = _eventDate(event['startDate']);
                  final end = _eventDate(event['endDate']);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primaryContainer,
                        child: Icon(Icons.event, color: AppColors.primary),
                      ),
                      title: Text(event['title']?.toString() ?? 'Event',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${end == null || end == start ? _dateLabel(start) : '${_dateLabel(start)} – ${_dateLabel(end)}'}\n${event['startTime'] ?? 'Time not set'}${event['endTime'] == null ? '' : ' – ${event['endTime']}'}',
                        ),
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showEvent(event),
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
}
