import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/l10n/language_provider.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/services/notification_service.dart';
import '../widgets/notice_audio_player.dart';

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

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 20;

  late final TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _notices = [];
  String _status = 'UNREAD';
  String? _nextCursor;
  String? _loadError;
  String? _loadMoreError;
  int _requestVersion = 0;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _autoPlayAudio = false;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        _selectStatus(_tabController.index);
      }
    });
    _scrollController.addListener(_handleScroll);
    _fetchAnnouncements();
    _notificationSubscription =
        NotificationService.instance.notificationEvents.listen((_) {
      _fetchAnnouncements();
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AnnouncementsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusAnnouncementId != widget.focusAnnouncementId) {
      _fetchAnnouncements();
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        !_hasMore ||
        _isLoadingMore ||
        _isLoading) {
      return;
    }
    if (_scrollController.position.extentAfter < 360) {
      _loadNextPage();
    }
  }

  Future<void> _fetchAnnouncements({bool refreshing = false}) async {
    if (!mounted) return;
    final requestVersion = ++_requestVersion;
    setState(() {
      _isLoading = !refreshing;
      _isLoadingMore = false;
      _loadError = null;
      _loadMoreError = null;
      _nextCursor = null;
      _hasMore = true;
      if (!refreshing) _notices = [];
    });
    try {
      final page = await ApiService.instance.getMyAnnouncements(
        status: _status,
        limit: _pageSize,
      );
      final notices = _readItems(page['items']);
      final focusIndex = notices.indexWhere(
        (notice) => notice['id']?.toString() == widget.focusAnnouncementId,
      );
      if (focusIndex > 0) {
        notices.insert(0, notices.removeAt(focusIndex));
      }
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _notices = notices;
        _nextCursor = page['nextCursor']?.toString();
        _hasMore = page['hasMore'] == true && _nextCursor != null;
        _loadMoreError = null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || requestVersion != _requestVersion) return;
      final canKeepCurrentPage = refreshing && _notices.isNotEmpty;
      setState(() {
        _isLoading = false;
        _hasMore = false;
        _loadError = canKeepCurrentPage
            ? null
            : 'Unable to load notices. Check your connection and try again.';
      });
      if (canKeepCurrentPage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not refresh notices.')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _readItems(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _loadNextPage() async {
    final cursor = _nextCursor;
    if (!_hasMore || _isLoadingMore || _isLoading || cursor == null) return;
    final requestVersion = _requestVersion;
    final requestedStatus = _status;
    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });
    try {
      final page = await ApiService.instance.getMyAnnouncements(
        status: requestedStatus,
        limit: _pageSize,
        cursor: cursor,
      );
      if (!mounted || requestVersion != _requestVersion) return;
      final nextItems = _readItems(page['items']);
      final existingIds =
          _notices.map((item) => item['id']?.toString()).toSet();
      setState(() {
        _notices.addAll(nextItems.where(
          (item) => !existingIds.contains(item['id']?.toString()),
        ));
        _nextCursor = page['nextCursor']?.toString();
        _hasMore = page['hasMore'] == true && _nextCursor != null;
        _isLoadingMore = false;
        _loadMoreError = null;
      });
    } catch (_) {
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _isLoadingMore = false;
        _loadMoreError = 'Could not load more notices. Tap to retry.';
      });
    }
  }

  void _selectStatus(int index) {
    final nextStatus = index == 0 ? 'UNREAD' : 'READ';
    if (nextStatus == _status) return;
    setState(() => _status = nextStatus);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _fetchAnnouncements();
  }

  Future<void> _setReadState(Map<String, dynamic> notice, bool isRead) async {
    final id = notice['id']?.toString();
    if (id == null || id.isEmpty) return;
    try {
      await ApiService.instance.setAnnouncementReadState(id, isRead);
      if (!mounted) return;
      setState(() {
        _notices.removeWhere((item) => item['id']?.toString() == id);
      });
      if (_notices.isEmpty && _hasMore) {
        _loadNextPage();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 2),
        content:
            Text(isRead ? 'Notice marked as read' : 'Notice marked as unread'),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not update notice status. Try again.')),
      );
    }
  }

  Future<void> _hideNotice(Map<String, dynamic> notice) async {
    final id = notice['id']?.toString();
    if (id == null || id.isEmpty) return;
    try {
      await ApiService.instance.hideAnnouncementForUser(id);
      if (!mounted) return;
      setState(
          () => _notices.removeWhere((item) => item['id']?.toString() == id));
      if (_notices.isEmpty && _hasMore) _loadNextPage();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notice removed from your list')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not remove this notice. Try again.')),
      );
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
            onPressed: () => _fetchAnnouncements(refreshing: true),
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: _selectStatus,
          indicatorColor: AppColors.secondary,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
          tabs: [
            Tab(text: lang.tr(en: 'Unread', ta: 'படிக்காதவை')),
            Tab(text: lang.tr(en: 'Read', ta: 'படித்தவை')),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.white,
            child: Row(
              children: [
                Icon(
                  _autoPlayAudio ? Icons.volume_up : Icons.volume_off_outlined,
                  size: 18,
                  color: _autoPlayAudio
                      ? const Color(0xFF0F432B)
                      : Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  lang.tr(
                    en: 'Auto-play voice messages',
                    ta: 'குரல் செய்திகளை தானாக இயக்கு',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _autoPlayAudio
                        ? const Color(0xFF0F432B)
                        : Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: _autoPlayAudio,
                    activeThumbColor: const Color(0xFF0F432B),
                    onChanged: (val) => setState(() => _autoPlayAudio = val),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.8),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: _buildNoticeList(lang),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeList(LanguageNotifier language) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null && _notices.isEmpty) {
      return _buildMessageState(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load notices',
        message: _loadError!,
        actionLabel: 'Try again',
        onAction: () => _fetchAnnouncements(),
      );
    }
    if (_notices.isEmpty) {
      final isUnread = _status == 'UNREAD';
      return _buildMessageState(
        icon: isUnread ? Icons.mark_email_read_outlined : Icons.inbox_outlined,
        title: isUnread ? 'You’re all caught up' : 'No read notices yet',
        message: isUnread
            ? 'New notices from your connected masjids will appear here.'
            : 'Notices you mark as read will appear in this tab.',
        actionLabel: 'Refresh',
        onAction: () => _fetchAnnouncements(refreshing: true),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchAnnouncements(refreshing: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: AppSpacing.screenPadding,
        itemCount:
            _notices.length + (_hasMore || _loadMoreError != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _notices.length) {
            if (_isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (_loadMoreError != null) {
              return Center(
                child: TextButton.icon(
                  onPressed: _loadNextPage,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry loading more'),
                ),
              );
            }
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text('You’re all caught up',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            );
          }
          return _buildNoticeCard(_notices[index], language);
        },
      ),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: AppColors.primaryMid),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(url, fit: BoxFit.contain),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeCard(
      Map<String, dynamic> item, LanguageNotifier language) {
    final isRead = item['isRead'] == true;
    final isEmergency = item['isEmergency'] == true ||
        item['type'] == 'EMERGENCY' ||
        item['category'] == 'EMERGENCY';
    final isEnglish = ref.read(languageProvider);
    final title = (isEnglish ? item['title'] : item['titleTa'] ?? item['title'])
            ?.toString() ??
        '';
    final body = (isEnglish ? item['body'] : item['bodyTa'] ?? item['body'])
            ?.toString() ??
        '';
    final imageUrl = item['imageUrl']?.toString();
    final audioUrl = item['audioUrl']?.toString();
    final createdAt =
        item['publishedAt']?.toString() ?? item['createdAt']?.toString() ?? '';
    var displayTime = '';
    if (createdAt.isNotEmpty) {
      try {
        displayTime = DateFormat('d MMM yyyy • h:mm a')
            .format(DateTime.parse(createdAt).toLocal());
      } catch (_) {
        displayTime = createdAt;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isEmergency ? AppColors.emergency : AppColors.outline,
          width: isEmergency ? 1.5 : .8,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (!isRead) {
            _setReadState(item, true);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 10, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      isEmergency
                          ? Icons.warning_amber_rounded
                          : Icons.campaign_outlined,
                      color:
                          isEmergency ? AppColors.emergency : AppColors.primary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isRead
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                  color: isEmergency
                                      ? AppColors.emergency
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 9,
                                height: 9,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: const BoxDecoration(
                                    color: AppColors.primaryMid,
                                    shape: BoxShape.circle),
                              ),
                          ],
                        ),
                        if (displayTime.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(displayTime,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Notice options',
                    onSelected: (action) {
                      if (action == 'read') _setReadState(item, true);
                      if (action == 'unread') _setReadState(item, false);
                      if (action == 'hide') _hideNotice(item);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: isRead ? 'unread' : 'read',
                        child: Text(isRead ? 'Mark as unread' : 'Mark as read'),
                      ),
                      const PopupMenuItem(
                        value: 'hide',
                        child: Text('Remove from my notices'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Text(body,
                  style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: AppColors.textPrimary)),
              if (imageUrl != null && imageUrl.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _showImageDialog(context, imageUrl.trim()),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl.trim(),
                      width: double.infinity,
                      height: 190,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : Container(
                                  height: 190,
                                  color: Colors.grey.shade100,
                                  child: const Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                ),
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
              if (audioUrl != null && audioUrl.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                NoticeAudioPlayer(
                  audioUrl: audioUrl.trim(),
                  autoPlay: _autoPlayAudio,
                ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  isRead ? 'READ' : 'UNREAD',
                  style: TextStyle(
                      color:
                          isRead ? AppColors.textSecondary : AppColors.primary,
                      fontSize: 9,
                      letterSpacing: .7,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
