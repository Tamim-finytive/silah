import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:masjid_namaz_app/core/constants/app_colors.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class MasjidInviteQrScreen extends StatefulWidget {
  final String masjidId;
  final String masjidName;
  final String? masjidNameTa;
  final String city;
  final String address;
  final String qrToken;

  const MasjidInviteQrScreen({
    super.key,
    required this.masjidId,
    required this.masjidName,
    this.masjidNameTa,
    required this.city,
    required this.address,
    required this.qrToken,
  });

  @override
  State<MasjidInviteQrScreen> createState() => _MasjidInviteQrScreenState();
}

class _MasjidInviteQrScreenState extends State<MasjidInviteQrScreen> {
  bool _isGeneratingPdf = false;

  String get _locationText {
    final parts = [
      if (widget.address.trim().isNotEmpty) widget.address.trim(),
      if (widget.city.trim().isNotEmpty) widget.city.trim(),
    ];
    return parts.join(', ');
  }

  String get _inviteMessage {
    final location = _locationText;
    final buffer = StringBuffer();
    buffer.writeln('🕌 *Join ${widget.masjidName} on Silah App!*');
    if (widget.masjidNameTa != null && widget.masjidNameTa!.trim().isNotEmpty) {
      buffer.writeln(widget.masjidNameTa!.trim());
    }
    if (location.isNotEmpty) {
      buffer.writeln('📍 $location');
    }
    buffer.writeln();
    buffer.writeln(
        'Scan our Masjid QR code or use the join token in the Silah app to connect instantly and receive live Prayer Times, Jamaah schedules & Announcements.');
    buffer.writeln();
    buffer.writeln('🔑 *Masjid Token:* `${widget.qrToken}`');
    buffer.writeln();
    buffer.writeln('📲 *Download Silah App:*');
    buffer.writeln('https://play.google.com/store/apps/details?id=com.finytive.silah');
    return buffer.toString();
  }

  Future<Uint8List> _generatePdfDoc() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColor.fromInt(0xFF0F4A3C),
                  width: 2.5,
                ),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
              ),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'SILAH - பள்ளிவாசல் செயலி',
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColor.fromInt(0xFFC59A27),
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    widget.masjidName,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF0F4A3C),
                    ),
                  ),
                  if (widget.masjidNameTa != null &&
                      widget.masjidNameTa!.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      widget.masjidNameTa!.trim(),
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 16),
                    ),
                  ],
                  if (_locationText.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Text(
                      _locationText,
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 20),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(14),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(
                        color: PdfColors.grey400,
                        width: 1.5,
                      ),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(12),
                      ),
                    ),
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: widget.qrToken,
                      width: 200,
                      height: 200,
                      color: PdfColor.fromInt(0xFF0F4A3C),
                    ),
                  ),
                  pw.SizedBox(height: 14),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Text(
                      'TOKEN: ${widget.qrToken}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 18),
                  pw.Text(
                    'Scan this QR code with the Silah App to connect instantly!',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF0F4A3C),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Stay connected with live prayer times, jamaah schedules & masjid announcements.',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Powered by Silah • www.silah.app',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _handlePrint() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final docBytes = await _generatePdfDoc();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => docBytes,
        name: '${widget.masjidName.replaceAll(' ', '_')}_QR.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _handleExportPdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final docBytes = await _generatePdfDoc();
      final filename = '${widget.masjidName.replaceAll(' ', '_')}_QR.pdf';
      await Printing.sharePdf(bytes: docBytes, filename: filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export PDF failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _handleWhatsAppShare() async {
    final text = _inviteMessage;
    final whatsappUri =
        Uri.parse("whatsapp://send?text=${Uri.encodeComponent(text)}");
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
      } else {
        final webWhatsappUri = Uri.parse(
            "https://api.whatsapp.com/send?text=${Uri.encodeComponent(text)}");
        await launchUrl(webWhatsappUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Fallback to generic share
      await Share.share(text);
    }
  }

  Future<void> _handleGenericShare() async {
    await Share.share(_inviteMessage);
  }

  void _copyToken() {
    Clipboard.setData(ClipboardData(text: widget.qrToken));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Token copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final qrSize = (screenWidth * 0.65).clamp(200.0, 300.0);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(
          'Masjid Invite QR',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Invite',
            onPressed: _handleGenericShare,
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print QR Code',
            onPressed: _isGeneratingPdf ? null : _handlePrint,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export as PDF',
            onPressed: _isGeneratingPdf ? null : _handleExportPdf,
          ),
        ],
      ),
      body: _isGeneratingPdf
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Preparing PDF document…',
                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    children: [
                      // Full Screen QR Card
                      Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(
                              color: AppColors.outline, width: 1.2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              // Top Icon & Masjid Name
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.mosque,
                                    color: AppColors.primary, size: 28),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.masjidName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (widget.masjidNameTa != null &&
                                  widget.masjidNameTa!.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  widget.masjidNameTa!.trim(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                              if (_locationText.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 15, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        _locationText,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 20),

                              // High-Resolution Large QR Code
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: Colors.grey.shade300, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: QrImageView(
                                  data: widget.qrToken,
                                  version: QrVersions.auto,
                                  size: qrSize,
                                  backgroundColor: Colors.white,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: AppColors.primary,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Token display with Copy button
                              InkWell(
                                onTap: _copyToken,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.key,
                                          size: 16, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Token: ${widget.qrToken}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.copy,
                                          size: 15, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              const Text(
                                'Musallis can scan this QR code with the Silah app to join instantly and receive live prayer times & announcements.',
                                textAlign: TextAlign.center,
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Action Buttons Row (WhatsApp, Print, Export PDF)
                      Row(
                        children: [
                          // WhatsApp Share Button
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.chat, size: 18),
                                label: const Text(
                                  'WhatsApp',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                                onPressed: _handleWhatsAppShare,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Print Option
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.print, size: 18),
                                label: const Text(
                                  'Print',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                                onPressed: _handlePrint,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Export PDF Option
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(
                                      color: AppColors.primary, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.picture_as_pdf, size: 18),
                                label: const Text(
                                  'PDF',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                                onPressed: _handleExportPdf,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
