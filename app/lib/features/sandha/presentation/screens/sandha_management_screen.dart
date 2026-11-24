import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_service.dart';

class SandhaManagementScreen extends StatefulWidget {
  final String masjidId;
  const SandhaManagementScreen({super.key, required this.masjidId});

  @override
  State<SandhaManagementScreen> createState() => _SandhaManagementScreenState();
}

class _SandhaManagementScreenState extends State<SandhaManagementScreen> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _upi = TextEditingController();
  final _payee = TextEditingController();
  final _phone = TextEditingController();
  final _scroll = ScrollController();
  List<dynamic> _plans = [], _payments = [];
  Map<String, dynamic> _summary = {};
  String? _planId;
  String _month = _monthFor(DateTime.now());
  String _status = 'ALL';
  bool _busy = false;
  int _page = 1;
  bool _hasMore = false;

  static String _monthFor(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  void _onScroll() {
    if (_hasMore && !_busy && _scroll.position.extentAfter < 360) {
      _load(more: true);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _name.dispose();
    _amount.dispose();
    _upi.dispose();
    _payee.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    if (!more) {
      _page = 1;
      _hasMore = false;
    }
    setState(() => _busy = true);
    try {
      final plans =
          await ApiService.instance.getMasjidSandhaPlans(widget.masjidId);
      final requestedPage = more ? _page + 1 : 1;
      final result = await ApiService.instance.getAdminSandhaPayments(
        widget.masjidId,
        _month,
        status: _status,
        page: requestedPage,
      );
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _payments = more
            ? [..._payments, ...(result['items'] as List<dynamic>? ?? [])]
            : (result['items'] as List<dynamic>? ?? []);
        _page = requestedPage;
        _hasMore = result['hasMore'] == true;
        _summary = Map<String, dynamic>.from(result['summary'] as Map? ?? {});
        _busy = false;
      });
      if (_planId == null && plans.isNotEmpty)
        _selectPlan(Map<String, dynamic>.from(plans.first as Map));
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        _toast(ApiService.getErrorMessage(error));
      }
    }
  }

  void _selectPlan(Map<String, dynamic> plan) {
    setState(() {
      _planId = plan['id']?.toString();
      _name.text = plan['name']?.toString() ?? '';
      _amount.text = plan['amount']?.toString() ?? '';
      _upi.text = plan['upiId']?.toString() ?? '';
      _payee.text = plan['payeeName']?.toString() ?? '';
      _phone.text = plan['contactPhone']?.toString() ?? '';
    });
  }

  Future<void> _savePlan() async {
    final amount = double.tryParse(_amount.text.trim());
    if (_name.text.trim().isEmpty ||
        amount == null ||
        amount <= 0 ||
        _upi.text.trim().isEmpty) {
      _toast('Enter a plan name, monthly amount, and valid UPI ID.');
      return;
    }
    setState(() => _busy = true);
    try {
      final body = {
        'name': _name.text.trim(),
        'amount': amount,
        'frequency': 'MONTHLY',
        'upiId': _upi.text.trim(),
        'payeeName': _payee.text.trim().isEmpty ? null : _payee.text.trim(),
        'contactPhone': _phone.text.trim().isEmpty ? null : _phone.text.trim()
      };
      if (_planId == null) {
        final created =
            await ApiService.instance.createSandhaPlan(widget.masjidId, body);
        _planId = created['id']?.toString();
      } else {
        await ApiService.instance
            .updateSandhaPlan(widget.masjidId, _planId!, body);
      }
      _toast('Sandha plan and UPI details saved.');
      if (mounted) setState(() => _busy = false);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _busy = false);
      _toast(ApiService.getErrorMessage(error));
    }
  }

  Future<void> _review(Map<String, dynamic> payment, bool approve) async {
    try {
      await ApiService.instance.reviewSandhaPayment(
          widget.masjidId, payment['id'].toString(),
          approve: approve);
      _toast(approve ? 'Payment marked as paid.' : 'Receipt rejected.');
      await _load();
    } catch (error) {
      _toast(ApiService.getErrorMessage(error));
    }
  }

  Future<void> _showProof(String url) async {
    await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
            child: InteractiveViewer(
                child: Image.network(url,
                    errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Receipt could not be opened.'))))));
  }

  void _toast(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _money(dynamic value) =>
      '₹${(double.tryParse('$value') ?? 0).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Sandha Management'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
            ]),
        body: _busy && _plans.isEmpty && _payments.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                        'Monthly plan and payment destination',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 17)),
                                    const SizedBox(height: 12),
                                    if (_plans.isNotEmpty)
                                      DropdownButtonFormField<String>(
                                          value: _planId,
                                          decoration: const InputDecoration(
                                              labelText: 'Plan'),
                                          items: _plans
                                              .map((p) => DropdownMenuItem(
                                                  value: p['id'].toString(),
                                                  child: Text(
                                                      p['name'].toString(),
                                                      overflow: TextOverflow
                                                          .ellipsis)))
                                              .toList(),
                                          onChanged: (id) {
                                            final selected = _plans
                                                .cast<Map>()
                                                .firstWhere((p) =>
                                                    p['id'].toString() == id);
                                            _selectPlan(
                                                Map<String, dynamic>.from(
                                                    selected));
                                          }),
                                    if (_plans.isNotEmpty)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: () => setState(() {
                                            _planId = null;
                                            _name.clear();
                                            _amount.clear();
                                            _upi.clear();
                                            _payee.clear();
                                            _phone.clear();
                                          }),
                                          icon: const Icon(Icons.add),
                                          label: const Text('Add another plan'),
                                        ),
                                      ),
                                    TextField(
                                        controller: _name,
                                        decoration: const InputDecoration(
                                            labelText: 'Plan name')),
                                    TextField(
                                        controller: _amount,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                            labelText: 'Monthly amount (₹)')),
                                    TextField(
                                        controller: _upi,
                                        keyboardType: TextInputType.text,
                                        decoration: const InputDecoration(
                                            labelText: 'UPI ID',
                                            hintText: 'masjid@bank')),
                                    TextField(
                                        controller: _payee,
                                        decoration: const InputDecoration(
                                            labelText: 'Payee name')),
                                    TextField(
                                        controller: _phone,
                                        keyboardType: TextInputType.phone,
                                        decoration: const InputDecoration(
                                            labelText:
                                                'Admin contact phone (optional)')),
                                    const SizedBox(height: 12),
                                    FilledButton.icon(
                                        onPressed: _busy ? null : _savePlan,
                                        icon: const Icon(Icons.save),
                                        label: Text(_planId == null
                                            ? 'Create plan'
                                            : 'Save payment details')),
                                  ]))),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _metric('Expected', _money(_summary['expected'])),
                        _metric('Collected', _money(_summary['collected'])),
                        _metric(
                            'Still due', _money(_summary['pendingBalance'])),
                        _metric('Receipts to review',
                            '${_summary['pendingProofCount'] ?? 0} · ${_money(_summary['pendingProofAmount'])}'),
                      ]),
                      const SizedBox(height: 12),
                      Card(
                          child: ListTile(
                              leading: const Icon(Icons.calendar_month),
                              title: Text('Month: $_month'),
                              subtitle: const Text(
                                  'Choose a month to view Sandha history'),
                              trailing: IconButton(
                                  icon: const Icon(Icons.edit_calendar),
                                  onPressed: () async {
                                    final initial =
                                        DateTime.tryParse('$_month-01') ??
                                            DateTime.now();
                                    final picked = await showDatePicker(
                                        context: context,
                                        initialDate: initial,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100),
                                        initialDatePickerMode:
                                            DatePickerMode.year);
                                    if (picked != null) {
                                      setState(
                                          () => _month = _monthFor(picked));
                                      _load();
                                    }
                                  }))),
                      DropdownButtonFormField<String>(
                          value: _status,
                          decoration: const InputDecoration(
                              labelText: 'Payment status'),
                          items: const [
                            'ALL',
                            'PENDING',
                            'PAID',
                            'PARTIAL',
                            'REJECTED',
                            'WAIVED'
                          ]
                              .map((s) =>
                                  DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _status = value);
                              _load();
                            }
                          }),
                      const SizedBox(height: 8),
                      if (_payments.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                                child: Text(
                                    'No Sandha payments recorded for this month.'))),
                      ..._payments.map((raw) {
                        final p = Map<String, dynamic>.from(raw as Map);
                        final member = Map<String, dynamic>.from(
                            p['planMember'] as Map? ?? {});
                        final plan =
                            Map<String, dynamic>.from(p['plan'] as Map? ?? {});
                        final pending = p['status'] == 'PENDING';
                        final proofUrl = p['proofUrl']?.toString();
                        return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                          member['name']?.toString() ??
                                              member['phone']?.toString() ??
                                              'Member',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      Text(
                                          '${plan['name'] ?? 'Sandha'} · ${p['periodStart']?.toString().substring(0, 7) ?? _month} · ${_money(p['amount'])}'),
                                      const SizedBox(height: 4),
                                      Text('Status: ${p['status']}'),
                                      if (proofUrl != null &&
                                          proofUrl.isNotEmpty)
                                        TextButton.icon(
                                            onPressed: () =>
                                                _showProof(proofUrl),
                                            icon: const Icon(Icons.image),
                                            label: const Text(
                                                'View payment screenshot')),
                                      if (pending)
                                        Wrap(spacing: 8, children: [
                                          FilledButton(
                                              onPressed: () => _review(p, true),
                                              child: const Text('Approve')),
                                          OutlinedButton(
                                              onPressed: () =>
                                                  _review(p, false),
                                              child: const Text('Reject'))
                                        ])
                                    ])));
                      }),
                      if (_busy && _payments.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ])),
      );

  Widget _metric(String title, String value) => SizedBox(
      width: 160,
      child: Card(
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(value,
                        style: const TextStyle(fontWeight: FontWeight.bold))
                  ]))));
}
