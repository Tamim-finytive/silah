import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/l10n/language_provider.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../prayer_times/data/prayer_times_provider.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  final String? masjidId;
  final String? focusAnnouncementId;

  const AnnouncementsScreen(
      {super.key, this.onBack, this.masjidId, this.focusAnnouncementId});

  @override
  ConsumerState<AnnouncementsScreen> createState() =>
      _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  List<dynamic> _notices = [];
  bool _isLoading = true;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
    _notificationSubscription =
        NotificationService.instance.notificationEvents.listen((_) {
      _fetchAnnouncements();
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AnnouncementsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusAnnouncementId != widget.focusAnnouncementId) {
      _fetchAnnouncements();
    }
  }

  Future<void> _fetchAnnouncements() async {
    setState(() => _isLoading = true);
    final targetId =
        widget.masjidId ?? ref.read(prayerTimesProvider).activeMasjid?['id'];

    final results = await Future.wait<List<dynamic>>([
      if (targetId != null) ApiService.instance.getAnnouncements(targetId),
      ApiService.instance.getBroadcastAnnouncements(),
    ]);
    final notices = results.expand((items) => items).toList();
    notices.sort((a, b) {
      final aDate = DateTime.tryParse(
          a['publishedAt']?.toString() ?? a['createdAt']?.toString() ?? '');
      final bDate = DateTime.tryParse(
          b['publishedAt']?.toString() ?? b['createdAt']?.toString() ?? '');
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    final focusedIndex = notices.indexWhere(
      (notice) => notice['id']?.toString() == widget.focusAnnouncementId,
    );
    if (focusedIndex > 0) {
      notices.insert(0, notices.removeAt(focusedIndex));
    }
    if (mounted) {
      setState(() {
        _notices = notices;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);
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
                },
              )
            : null,
        title: Text(lang.tr(en: 'Notices', ta: 'அறிவிப்புகள்')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAnnouncements,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _notices.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.campaign_outlined,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              lang.tr(
                                en: 'No notices yet',
                                ta: 'அறிவிப்புகள் எதுவும் இல்லை',
                              ),
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              lang.tr(
                                en: 'New updates from your masjid will appear here.',
                                ta: 'உங்கள் பள்ளிவாசலின் புதிய அறிவிப்புகள் இங்கே வரும்.',
                              ),
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                            OutlinedButton.icon(
                              onPressed: _fetchAnnouncements,
                              icon: const Icon(Icons.refresh),
                              label: Text(lang.tr(
                                  en: 'Refresh notices', ta: 'மீண்டும் ஏற்று')),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchAnnouncements,
                      child: ListView.builder(
                        padding: AppSpacing.screenPadding,
                        itemCount: _notices.length,
                        itemBuilder: (context, index) {
                          final item = _notices[index] as Map<String, dynamic>;
                          final isEmergency = item['isEmergency'] == true ||
                              item['type'] == 'EMERGENCY';
                          final isEnglish = ref.read(languageProvider);
                          final title = (isEnglish
                                      ? item['title']
                                      : item['titleTa'] ?? item['title'])
                                  ?.toString() ??
                              '';
                          final body = (isEnglish
                                      ? item['body']
                                      : item['bodyTa'] ?? item['body'])
                                  ?.toString() ??
                              '';
                          final createdAt = item['publishedAt']?.toString() ??
                              item['createdAt']?.toString() ??
                              '';
                          String displayTime = '';
                          if (createdAt.isNotEmpty) {
                            try {
                              final dt = DateTime.parse(createdAt).toLocal();
                              displayTime =
                                  DateFormat('d MMM yyyy • h:mm a').format(dt);
                            } catch (_) {
                              displayTime = createdAt;
                            }
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: isEmergency
                                    ? AppColors.emergency
                                    : AppColors.outline,
                                width: isEmergency ? 1.5 : 0.8,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isEmergency
                                            ? Icons.warning_amber_rounded
                                            : Icons.campaign_outlined,
                                        color: isEmergency
                                            ? AppColors.emergency
                                            : AppColors.primary,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isEmergency
                                                ? AppColors.emergency
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    body,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        height: 1.4,
                                        color: AppColors.textPrimary),
                                  ),
                                  if (displayTime.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      displayTime,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary),
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
      ),
    );
  }
}
