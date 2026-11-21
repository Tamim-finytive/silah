import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';

class SandhaScreen extends StatelessWidget {
  final VoidCallback? onBack;
  const SandhaScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    final months = [
      {'name': 'ஜன (Jan)', 'status': 'PAID'},
      {'name': 'பிப் (Feb)', 'status': 'PAID'},
      {'name': 'மார் (Mar)', 'status': 'PAID'},
      {'name': 'ஏப் (Apr)', 'status': 'PAID'},
      {'name': 'மே (May)', 'status': 'PAID'},
      {'name': 'ஜூன் (Jun)', 'status': 'PAID'},
      {'name': 'ஜூலை (Jul)', 'status': 'PAID'},
      {'name': 'ஆக (Aug)', 'status': 'PAID'},
      {'name': 'செப் (Sep)', 'status': 'PAID'},
      {'name': 'அக் (Oct)', 'status': 'PAID'},
      {'name': 'நவ (Nov)', 'status': 'PAID'},
      {'name': 'டிச (Dec)', 'status': 'PENDING'},
    ];

    return Scaffold(
      appBar: AppBar(
        leading: (onBack != null || Navigator.canPop(context))
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: () {
                  if (onBack != null) {
                    onBack!();
                  } else if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              )
            : null,
        title: const Text('சந்தா விவரம் / Sandha Status'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current Plan Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outline),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'மாதாந்திர சந்தா',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'இணைக்கப்பட்டது / Auto-linked',
                          style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Jamia Masjid Maintenance Fund • ₹200 / Month', style: TextStyle(color: AppColors.textSecondary)),
                  const Divider(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('2026 செலுத்திய தொகை (Total Paid)', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('₹2,200', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.success)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 12-Month Grid Tracker
            const Text(
              '2026 மாத நிலுவை விபரம் / Yearly Tracker',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.2,
              ),
              itemCount: months.length,
              itemBuilder: (context, index) {
                final m = months[index];
                final isPaid = m['status'] == 'PAID';
                return Container(
                  decoration: BoxDecoration(
                    color: isPaid ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isPaid ? AppColors.success : AppColors.warning),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        m['name']!,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Icon(
                        isPaid ? Icons.check_circle : Icons.schedule,
                        size: 18,
                        color: isPaid ? AppColors.success : AppColors.warning,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 28),

            // Recent Payment History
            const Text(
              'சமீபத்திய ரசீதுகள் / Recent Receipts',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryContainer,
                  child: Icon(Icons.receipt_long, color: AppColors.primary),
                ),
                title: const Text('நவம்பர் 2026 (November 2026)'),
                subtitle: const Text('ரசீது: REC-2026-1102 • ரொக்கம் (Cash)'),
                trailing: const Text(
                  '₹200',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.success),
                ),
                onTap: () {
                  // View digital receipt
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
