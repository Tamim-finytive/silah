import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_service.dart';
import 'sandha_settings_screen.dart';

class SandhaManagementScreen extends StatefulWidget {
  final String masjidId;
  final bool isEmbedded;
  const SandhaManagementScreen({
    super.key,
    required this.masjidId,
    this.isEmbedded = false,
  });

  @override
  State<SandhaManagementScreen> createState() => _SandhaManagementScreenState();
}

class _SandhaManagementScreenState extends State<SandhaManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();

  List<dynamic> _plans = [];
  List<dynamic> _members = [];
  List<dynamic> _payments = [];
  Map<String, dynamic> _summary = {};

  String _currentMonth = _monthFor(DateTime.now());
  String _paymentStatusFilter = 'ALL';
  String _memberStatusFilter = 'ALL'; // ALL, PAID, UNPAID
  String? _selectedPlanId;

  bool _isLoading = true;

  static String _monthFor(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  static String _monthDisplay(String yyyyMm) {
    try {
      final parts = yyyyMm.split('-');
      if (parts.length == 2) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        const months = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];
        if (month >= 1 && month <= 12) {
          return '${months[month - 1]} $year';
        }
      }
    } catch (_) {}
    return yyyyMm;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final plans =
          await ApiService.instance.getMasjidSandhaPlans(widget.masjidId);
      final activePlanId = plans.isNotEmpty ? plans.first['id']?.toString() : null;
      _selectedPlanId = activePlanId;

      final membersFuture = ApiService.instance.getSandhaMembers(
        widget.masjidId,
        planId: activePlanId,
        month: _currentMonth,
      );

      final paymentsFuture = ApiService.instance.getAdminSandhaPayments(
        widget.masjidId,
        _currentMonth,
        status: _paymentStatusFilter,
        page: 1,
      );

      final results = await Future.wait([membersFuture, paymentsFuture]);
      final members = results[0] as List<dynamic>;
      final paymentsResult = results[1] as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _plans = plans;
        _members = members;
        _payments = (paymentsResult['items'] as List<dynamic>? ?? []);
        _summary = Map<String, dynamic>.from(paymentsResult['summary'] as Map? ?? {});
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showToast(ApiService.getErrorMessage(e));
    }
  }

  Future<void> _loadMembersOnly() async {
    try {
      final members = await ApiService.instance.getSandhaMembers(
        widget.masjidId,
        planId: _selectedPlanId,
        month: _currentMonth,
      );
      if (!mounted) return;
      setState(() => _members = members);
    } catch (_) {}
  }

  Future<void> _loadPaymentsOnly() async {
    try {
      final paymentsResult = await ApiService.instance.getAdminSandhaPayments(
        widget.masjidId,
        _currentMonth,
        status: _paymentStatusFilter,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _payments = (paymentsResult['items'] as List<dynamic>? ?? []);
        _summary = Map<String, dynamic>.from(paymentsResult['summary'] as Map? ?? {});
      });
    } catch (_) {}
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatMoney(dynamic val) {
    final d = double.tryParse('$val') ?? 0;
    return '₹${d.toStringAsFixed(0)}';
  }

  void _changeMonth(int delta) {
    try {
      final parts = _currentMonth.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final newDate = DateTime(year, month + delta, 1);
      setState(() {
        _currentMonth = _monthFor(newDate);
      });
      _loadAllData();
    } catch (_) {}
  }

  Future<void> _pickMonth() async {
    final initial = DateTime.tryParse('$_currentMonth-01') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select Month for Sandha',
    );
    if (picked != null) {
      setState(() => _currentMonth = _monthFor(picked));
      _loadAllData();
    }
  }

  // ----------------------------------------------------------------------
  // ASSIGN MEMBER MODAL
  // ----------------------------------------------------------------------
  Future<void> _showAssignMemberModal() async {
    if (_plans.isEmpty) {
      _showToast('Please create a Sandha Plan in Settings first.');
      _openSettings();
      return;
    }

    final planId = _selectedPlanId ?? _plans.first['id'].toString();
    final planName = _plans.firstWhere((p) => p['id'].toString() == planId,
        orElse: () => _plans.first)['name']?.toString() ?? 'Sandha';

    // Fetch masjid connected members to choose from
    List<dynamic> connectedMembers = [];
    bool isFetchingMembers = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String inputName = '';
        String inputPhone = '';
        String filterText = '';
        bool customMode = false;
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            if (isFetchingMembers) {
              isFetchingMembers = false;
              ApiService.instance.getMasjidMembers(widget.masjidId).then((data) {
                if (data != null && data['memberships'] != null) {
                  final list = data['memberships'] as List<dynamic>;
                  final enrolledPhones = _members.map((m) => m['phone']?.toString()).toSet();
                  setModalState(() {
                    connectedMembers = list.where((m) {
                      final p = m['phone']?.toString();
                      return p != null && !enrolledPhones.contains(p);
                    }).toList();
                  });
                }
              }).catchError((_) {});
            }

            final filteredConnected = connectedMembers.where((m) {
              if (filterText.isEmpty) return true;
              final name = (m['name'] ?? '').toString().toLowerCase();
              final phone = (m['phone'] ?? '').toString().toLowerCase();
              final q = filterText.toLowerCase();
              return name.contains(q) || phone.contains(q);
            }).toList();

            Future<void> submitEnrollment(String name, String phone) async {
              if (name.trim().isEmpty || phone.trim().isEmpty) {
                _showToast('Name and phone are required.');
                return;
              }
              // Normalizing phone to +91 or keeping clean digits
              String cleanPhone = phone.trim();
              if (!cleanPhone.startsWith('+')) {
                cleanPhone = cleanPhone.length == 10 ? '+91$cleanPhone' : '+$cleanPhone';
              }

              setModalState(() => isSubmitting = true);
              try {
                await ApiService.instance.enrollSandhaMember(
                  widget.masjidId,
                  planId,
                  {'name': name.trim(), 'phone': cleanPhone},
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _showToast('Alhamdulillah! Member assigned to Sandha successfully.');
                _loadAllData();
              } catch (e) {
                setModalState(() => isSubmitting = false);
                _showToast(ApiService.getErrorMessage(e));
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
                left: 18,
                right: 18,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Assign Member to Sandha',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    Text(
                      'Plan: $planName',
                      style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),

                    // Toggle between selecting connected member vs entering manually
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Connected Members'),
                            selected: !customMode,
                            onSelected: (val) => setModalState(() => customMode = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Enter Manually'),
                            selected: customMode,
                            onSelected: (val) => setModalState(() => customMode = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (!customMode) ...[
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search members by name or phone...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (val) => setModalState(() => filterText = val),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: filteredConnected.isEmpty
                            ? Center(
                                child: Text(
                                  filterText.isEmpty
                                      ? 'No unassigned connected members found.\nSwitch to "Enter Manually" to add.'
                                      : 'No members matching "$filterText"',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.textSecondary),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filteredConnected.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (c, i) {
                                  final m = filteredConnected[i];
                                  final mName = m['name'] ?? 'Member';
                                  final mPhone = m['phone'] ?? '';
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.primaryContainer,
                                      child: Text(
                                        mName.isNotEmpty ? mName[0].toUpperCase() : 'M',
                                        style: const TextStyle(
                                            color: AppColors.primary, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(mName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    subtitle: Text(mPhone),
                                    trailing: FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: isSubmitting
                                          ? null
                                          : () => submitEnrollment(mName, mPhone),
                                      child: const Text('Assign'),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ] else ...[
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Member Name *',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                onChanged: (v) => inputName = v,
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Mobile Number *',
                                  hintText: '+919876543210 or 9876543210',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                ),
                                onChanged: (v) => inputPhone = v,
                              ),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: isSubmitting
                                    ? null
                                    : () => submitEnrollment(inputName, inputPhone),
                                icon: isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Icon(Icons.person_add_rounded),
                                label: Text(isSubmitting ? 'Assigning...' : 'Assign to Sandha'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ----------------------------------------------------------------------
  // RECORD PAYMENT MODAL (Admin Records Cash / UPI)
  // ----------------------------------------------------------------------
  Future<void> _showRecordPaymentModal(Map<String, dynamic> member) async {
    final memberId = member['id']?.toString();
    final memberName = member['name']?.toString() ?? 'Member';
    final plan = Map<String, dynamic>.from(member['plan'] as Map? ?? {});
    final defaultAmount = member['balance'] != null && (member['balance'] as num) > 0
        ? (member['balance'] as num).toDouble()
        : (double.tryParse('${plan['amount']}') ?? 200.0);

    final amountCtrl = TextEditingController(text: defaultAmount.toStringAsFixed(0));
    final receiptCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String method = 'CASH';
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Record Sandha: $memberName'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('For Month: ${_monthDisplay(_currentMonth)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹) *',
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: method,
                    decoration: const InputDecoration(labelText: 'Payment Method'),
                    items: const [
                      DropdownMenuItem(value: 'CASH', child: Text('Cash / ரொக்கம்')),
                      DropdownMenuItem(value: 'UPI', child: Text('UPI / GPay / PhonePe')),
                      DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer / வங்கி')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => method = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: receiptCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Receipt / Reference Number (Optional)',
                      prefixIcon: Icon(Icons.receipt_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      prefixIcon: Icon(Icons.note_alt_outlined),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: isSaving
                    ? null
                    : () async {
                        final amt = double.tryParse(amountCtrl.text.trim());
                        if (amt == null || amt <= 0) {
                          _showToast('Enter valid amount');
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        try {
                          final start = '$_currentMonth-01';
                          final date = DateTime.tryParse(start) ?? DateTime.now();
                          final end = DateTime(date.year, date.month + 1, 0);
                          final endText =
                              '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';

                          await ApiService.instance.recordSandhaPayment(widget.masjidId, {
                            'planMemberId': memberId,
                            'amount': amt,
                            'method': method,
                            'receiptNumber': receiptCtrl.text.trim().isEmpty ? null : receiptCtrl.text.trim(),
                            'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                            'periodStart': start,
                            'periodEnd': endText,
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                          _showToast('Alhamdulillah! Payment recorded successfully.');
                          _loadAllData();
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          _showToast(ApiService.getErrorMessage(e));
                        }
                      },
                child: Text(isSaving ? 'Saving...' : 'Record Payment'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ----------------------------------------------------------------------
  // REMOVE MEMBER CONFIRMATION
  // ----------------------------------------------------------------------
  Future<void> _confirmRemoveMember(Map<String, dynamic> member) async {
    final memberId = member['id']?.toString();
    final name = member['name'] ?? 'Member';
    if (memberId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Sandha?'),
        content: Text('Are you sure you want to remove $name from Sandha subscriptions?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.instance.removeSandhaMember(widget.masjidId, memberId);
        _showToast('$name removed from Sandha.');
        _loadMembersOnly();
      } catch (e) {
        _showToast(ApiService.getErrorMessage(e));
      }
    }
  }

  // ----------------------------------------------------------------------
  // REVIEW PAYMENT PROOF
  // ----------------------------------------------------------------------
  Future<void> _reviewProof(Map<String, dynamic> payment, bool approve) async {
    final paymentId = payment['id']?.toString();
    if (paymentId == null) return;
    try {
      await ApiService.instance.reviewSandhaPayment(widget.masjidId, paymentId, approve: approve);
      _showToast(approve ? 'Alhamdulillah! Payment approved and verified.' : 'Payment receipt rejected.');
      _loadAllData();
    } catch (e) {
      _showToast(ApiService.getErrorMessage(e));
    }
  }

  void _showProofDialog(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Could not load screenshot.'),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _openSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SandhaSettingsScreen(masjidId: widget.masjidId),
      ),
    );
    if (result == true) {
      _loadAllData();
    }
  }

  // ----------------------------------------------------------------------
  // MAIN BUILD
  // ----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Sandha Management', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: !widget.isEmbedded,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Sandha Settings',
            onPressed: _openSettings,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadAllData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.people_alt_outlined, size: 20), text: 'Members & Status'),
                Tab(icon: Icon(Icons.history_rounded, size: 20), text: 'Payment History'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildMonthAndSummaryHeader(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMembersTab(),
                      _buildHistoryTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ----------------------------------------------------------------------
  // TOP MONTH AND SUMMARY METRICS HEADER
  // ----------------------------------------------------------------------
  Widget _buildMonthAndSummaryHeader() {
    final expected = _summary['expected'] ?? 0;
    final collected = _summary['collected'] ?? 0;
    final due = _summary['pendingBalance'] ?? 0;
    final pendingProofs = _summary['pendingProofCount'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          // Month Selector Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _changeMonth(-1),
                visualDensity: VisualDensity.compact,
              ),
              InkWell(
                onTap: _pickMonth,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        _monthDisplay(_currentMonth),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                      ),
                      const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => _changeMonth(1),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 4 Compact Metric Cards
          Row(
            children: [
              _metricChip('Expected', _formatMoney(expected), AppColors.textPrimary),
              const SizedBox(width: 6),
              _metricChip('Collected', _formatMoney(collected), AppColors.success),
              const SizedBox(width: 6),
              _metricChip('Still Due', _formatMoney(due), AppColors.emergency),
              const SizedBox(width: 6),
              _metricChip('Pending Proofs', '$pendingProofs', AppColors.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), maxLines: 1),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  // TAB 1: MEMBERS & STATUS
  // ----------------------------------------------------------------------
  Widget _buildMembersTab() {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _members.where((m) {
      if (_memberStatusFilter != 'ALL') {
        final st = m['monthStatus']?.toString() ?? 'UNPAID';
        if (_memberStatusFilter == 'PAID' && st != 'PAID') return false;
        if (_memberStatusFilter == 'UNPAID' && st != 'UNPAID' && st != 'PARTIAL') return false;
      }
      if (query.isEmpty) return true;
      final name = (m['name'] ?? '').toString().toLowerCase();
      final phone = (m['phone'] ?? '').toString().toLowerCase();
      return name.contains(query) || phone.contains(query);
    }).toList();

    return Column(
      children: [
        // Top Action & Filter Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search assigned members...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _showAssignMemberModal,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Assign', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),

        // Filter chips (All, Paid, Unpaid)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          color: Colors.white,
          child: Row(
            children: [
              _filterChip('All (${_members.length})', 'ALL'),
              const SizedBox(width: 6),
              _filterChip('Paid', 'PAID'),
              const SizedBox(width: 6),
              _filterChip('Unpaid / Due', 'UNPAID'),
            ],
          ),
        ),

        // Members List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          _members.isEmpty
                              ? 'No members assigned to Sandha yet.\nClick "Assign" to add members who pay Sandha.'
                              : 'No members matching filter.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        if (_members.isEmpty) ...[
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                            onPressed: _showAssignMemberModal,
                            icon: const Icon(Icons.person_add),
                            label: const Text('Assign First Member'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final member = Map<String, dynamic>.from(filtered[index] as Map);
                    return _buildMemberCard(member);
                  },
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _memberStatusFilter == value;
    return InkWell(
      onTap: () => setState(() => _memberStatusFilter = value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final name = member['name']?.toString() ?? 'Member';
    final phone = member['phone']?.toString() ?? '';
    final isLinked = member['autoLinked'] == true || member['user'] != null;
    final status = member['monthStatus']?.toString() ?? 'UNPAID';
    final plan = Map<String, dynamic>.from(member['plan'] as Map? ?? {});
    final planAmount = _formatMoney(plan['amount']);
    final paidSum = (member['paidSum'] as num?)?.toDouble() ?? 0.0;
    final balance = (member['balance'] as num?)?.toDouble() ?? 0.0;

    Color statusColor;
    String statusText;
    switch (status) {
      case 'PAID':
        statusColor = AppColors.success;
        statusText = 'PAID';
        break;
      case 'PARTIAL':
        statusColor = Colors.orange;
        statusText = 'PARTIAL (₹${paidSum.toStringAsFixed(0)})';
        break;
      case 'PENDING_APPROVAL':
        statusColor = Colors.blue;
        statusText = 'UNDER REVIEW';
        break;
      default:
        statusColor = AppColors.emergency;
        statusText = 'DUE';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryContainer,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'M',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isLinked) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, size: 14, color: AppColors.primary),
                          ],
                        ],
                      ),
                      Text(
                        '$phone · Plan: $planAmount',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  status == 'PAID'
                      ? 'Fully paid for ${_monthDisplay(_currentMonth)}'
                      : 'Remaining Due: ₹${balance.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: status == 'PAID' ? AppColors.success : AppColors.emergency,
                  ),
                ),
                Row(
                  children: [
                    SizedBox(
                      height: 28,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _confirmRemoveMember(member),
                        icon: const Icon(Icons.delete_outline, size: 14),
                        label: const Text('Remove', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      height: 28,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _showRecordPaymentModal(member),
                        icon: const Icon(Icons.add_card_rounded, size: 14),
                        label: const Text('Record Payment', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  // TAB 2: PAYMENT HISTORY
  // ----------------------------------------------------------------------
  Widget _buildHistoryTab() {
    return Column(
      children: [
        // Status filter bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              const Text('Filter: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _historyFilterChip('All', 'ALL'),
                      _historyFilterChip('Paid', 'PAID'),
                      _historyFilterChip('Pending Review', 'PENDING'),
                      _historyFilterChip('Rejected', 'REJECTED'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Payments list
        Expanded(
          child: _payments.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No Sandha payments recorded for ${_monthDisplay(_currentMonth)}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _payments.length,
                  itemBuilder: (context, index) {
                    final payment = Map<String, dynamic>.from(_payments[index] as Map);
                    return _buildPaymentCard(payment);
                  },
                ),
        ),
      ],
    );
  }

  Widget _historyFilterChip(String label, String value) {
    final isSelected = _paymentStatusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: isSelected,
        visualDensity: VisualDensity.compact,
        onSelected: (val) {
          if (val) {
            setState(() => _paymentStatusFilter = value);
            _loadPaymentsOnly();
          }
        },
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final member = Map<String, dynamic>.from(payment['planMember'] as Map? ?? {});
    final memberName = member['name']?.toString() ?? 'Member';
    final memberPhone = member['phone']?.toString() ?? '';
    final amount = _formatMoney(payment['amount']);
    final method = payment['method']?.toString() ?? 'CASH';
    final status = payment['status']?.toString() ?? 'PAID';
    final paidAt = payment['paidAt']?.toString() ?? '';
    final dateStr = paidAt.length >= 10 ? paidAt.substring(0, 10) : paidAt;
    final proofUrl = payment['proofUrl']?.toString();
    final receiptNumber = payment['receiptNumber']?.toString();
    final isPending = status == 'PENDING';

    Color statusColor;
    switch (status) {
      case 'PAID':
        statusColor = AppColors.success;
        break;
      case 'PENDING':
        statusColor = Colors.blue;
        break;
      case 'REJECTED':
        statusColor = AppColors.emergency;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(memberName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('$memberPhone · Method: $method',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(amount, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Date: $dateStr ${receiptNumber != null ? '· Rec: $receiptNumber' : ''}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                if (proofUrl != null && proofUrl.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _showProofDialog(proofUrl),
                    icon: const Icon(Icons.image_outlined, size: 14),
                    label: const Text('View Proof', style: TextStyle(fontSize: 11)),
                  ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _reviewProof(payment, false),
                    child: const Text('Reject', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _reviewProof(payment, true),
                    child: const Text('Approve', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
