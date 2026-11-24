import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_service.dart';

class SandhaSettingsScreen extends StatefulWidget {
  final String masjidId;
  const SandhaSettingsScreen({super.key, required this.masjidId});

  @override
  State<SandhaSettingsScreen> createState() => _SandhaSettingsScreenState();
}

class _SandhaSettingsScreenState extends State<SandhaSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  final _payeeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _frequency = 'MONTHLY';
  String? _planId;
  bool _isLoading = true;
  bool _isSaving = false;
  List<dynamic> _existingPlans = [];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _upiCtrl.dispose();
    _payeeCtrl.dispose();
    _phoneCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final plans =
          await ApiService.instance.getMasjidSandhaPlans(widget.masjidId);
      if (!mounted) return;
      setState(() {
        _existingPlans = plans;
        _isLoading = false;
        if (plans.isNotEmpty) {
          _populatePlan(Map<String, dynamic>.from(plans.first as Map));
        } else {
          _nameCtrl.text = 'மாதாந்திர சந்தா / Monthly Sandha';
          _amountCtrl.text = '200';
          _frequency = 'MONTHLY';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiService.getErrorMessage(e))),
      );
    }
  }

  void _populatePlan(Map<String, dynamic> plan) {
    _planId = plan['id']?.toString();
    _nameCtrl.text = plan['name']?.toString() ?? '';
    _amountCtrl.text = plan['amount']?.toString() ?? '';
    _frequency = plan['frequency']?.toString() ?? 'MONTHLY';
    _upiCtrl.text = plan['upiId']?.toString() ?? '';
    _payeeCtrl.text = plan['payeeName']?.toString() ?? '';
    _phoneCtrl.text = plan['contactPhone']?.toString() ?? '';
    _descCtrl.text = plan['description']?.toString() ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid monthly amount.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final body = {
      'name': _nameCtrl.text.trim(),
      'amount': amount,
      'frequency': _frequency,
      'description':
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'upiId': _upiCtrl.text.trim().isEmpty ? null : _upiCtrl.text.trim(),
      'payeeName':
          _payeeCtrl.text.trim().isEmpty ? null : _payeeCtrl.text.trim(),
      'contactPhone':
          _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
    };

    try {
      if (_planId == null) {
        final created =
            await ApiService.instance.createSandhaPlan(widget.masjidId, body);
        _planId = created['id']?.toString();
      } else {
        await ApiService.instance
            .updateSandhaPlan(widget.masjidId, _planId!, body);
      }
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sandha settings saved successfully! / சந்தா அமைப்புகள் சேமிக்கப்பட்டன!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiService.getErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Sandha Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Banner Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: AppColors.primary, size: 24),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Configure your masjid Sandha subscription details. Members assigned to Sandha will see these details to pay their monthly dues.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                  height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_existingPlans.length > 1) ...[
                      DropdownButtonFormField<String>(
                        value: _planId,
                        decoration: const InputDecoration(
                          labelText: 'Select Plan to Edit',
                          prefixIcon: Icon(Icons.list_alt_rounded),
                        ),
                        items: _existingPlans
                            .map((p) => DropdownMenuItem(
                                  value: p['id'].toString(),
                                  child: Text(p['name'].toString()),
                                ))
                            .toList(),
                        onChanged: (id) {
                          final selected = _existingPlans.firstWhere(
                              (p) => p['id'].toString() == id,
                              orElse: () => null);
                          if (selected != null) {
                            setState(() => _populatePlan(
                                Map<String, dynamic>.from(selected as Map)));
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.outline),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Plan Details / திட்டம் விவரம்',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary)),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Plan Name *',
                                hintText: 'e.g. மாதாந்திர சந்தா / Monthly Sandha',
                                prefixIcon: Icon(Icons.label_outline),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Enter plan name'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _amountCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Monthly Amount (₹) *',
                                hintText: 'e.g. 200',
                                prefixIcon: Icon(Icons.currency_rupee),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Enter amount';
                                }
                                if (double.tryParse(v.trim()) == null) {
                                  return 'Enter valid number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _frequency,
                              decoration: const InputDecoration(
                                labelText: 'Frequency',
                                prefixIcon: Icon(Icons.repeat_rounded),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'MONTHLY',
                                    child: Text('Monthly / மாதாந்திரம்')),
                                DropdownMenuItem(
                                    value: 'QUARTERLY',
                                    child: Text('Quarterly / காலாண்டு')),
                                DropdownMenuItem(
                                    value: 'YEARLY',
                                    child: Text('Yearly / வருடாந்திரம்')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _frequency = val);
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _descCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Description (Optional)',
                                hintText:
                                    'e.g. Maintenance, electricity and staff fund',
                                prefixIcon: Icon(Icons.description_outlined),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // UPI & Bank Details Card
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.outline),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Payment Destination (UPI / GPay / PhonePe)',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary)),
                            const SizedBox(height: 4),
                            const Text(
                              'Members can pay directly to this UPI ID or QR from their phone.',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _upiCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Masjid UPI ID',
                                hintText: 'e.g. masjid@sbi or 9876543210@upi',
                                prefixIcon: Icon(Icons.qr_code_2_rounded),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _payeeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Payee / Account Name',
                                hintText: 'e.g. Jamia Masjid Trust',
                                prefixIcon: Icon(Icons.account_balance_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Admin Contact Phone (Optional)',
                                hintText: 'e.g. +91 9876543210',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _isSaving
                            ? 'Saving...'
                            : (_planId == null
                                ? 'Create Sandha Plan'
                                : 'Save Sandha Settings'),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
