import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';

class AnnouncementsScreen extends StatelessWidget {
  final VoidCallback? onBack;
  const AnnouncementsScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    final notices = [
      {
        'title': 'ஜனாஸா அறிவிப்பு (Janazah Announcement)',
        'time': 'இன்று மாலை 4:30 மணி (Today 4:30 PM)',
        'body': 'ஹாஜி முஹம்மது யூசுப் (வயது 78) அவர்கள் காலமானார்கள். ஜனாஸா தொழுகை இன்று அஸர் தொழுகைக்குப் பின் ஜாமியா பள்ளிவாசலில் நடைபெறும்.',
        'isEmergency': true,
        'category': 'EMERGENCY',
      },
      {
        'title': 'ஜும்ஆ தொழுகை நேரம் மாற்றம் (Jummah Timing)',
        'time': '22 நவம்பர் 2026',
        'body': 'இந்த வாரம் முதல் ஜும்ஆ முதல் பாங்கு 12:45 மணிக்கும், குத்பா 1:00 மணிக்கும் தொடங்கும்.',
        'isEmergency': false,
        'category': 'PRAYER_CHANGE',
      },
      {
        'title': 'மாதாந்திர சமுதாய கல்வி வகுப்பு (Islamic Study Circle)',
        'time': 'ஞாயிறு காலை 10:00 மணி',
        'body': 'அனைத்து சகோதரர்களும் தவறாமல் கலந்துகொள்ளுமாறு கேட்டுக்கொள்ளப்படுகிறார்கள்.',
        'isEmergency': false,
        'category': 'EVENT',
      },
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
        title: const Text('அறிவிப்புகள் / Notices'),
      ),
      body: ListView.builder(
        padding: AppSpacing.screenPadding,
        itemCount: notices.length,
        itemBuilder: (context, index) {
          final item = notices[index];
          final isEmergency = item['isEmergency'] as bool;

          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isEmergency ? AppColors.emergency : AppColors.outline,
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
                        isEmergency ? Icons.warning_amber_rounded : Icons.campaign_outlined,
                        color: isEmergency ? AppColors.emergency : AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item['title'] as String,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isEmergency ? AppColors.emergency : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['body'] as String,
                    style: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['time'] as String,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share, size: 20, color: AppColors.primary),
                        tooltip: 'பகிர் / Share',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
