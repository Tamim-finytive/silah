import 'package:flutter/material.dart';
import 'package:masjid_namaz_app/core/constants/app_colors.dart';
import 'package:masjid_namaz_app/core/constants/app_spacing.dart';
import 'package:masjid_namaz_app/core/network/api_service.dart';

class ContactUsScreen extends StatefulWidget {
  final String initialPhone;

  const ContactUsScreen({super.key, required this.initialPhone});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _phoneController =
      TextEditingController(text: widget.initialPhone);
  final _nameController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ApiService.instance.submitContactRequest(
        name: _nameController.text,
        phone: _phoneController.text,
        subject: _subjectController.text,
        message: _messageController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Your message was sent to the Silah support team.'),
      ));
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = ApiService.getErrorMessage(
          error,
          fallback: 'Could not send your message. Please try again.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Contact Us'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: AppSpacing.screenPadding,
                  children: [
                    const Icon(Icons.support_agent,
                        size: 42, color: AppColors.primary),
                    const SizedBox(height: 12),
                    Text(
                      'Send a message to the Silah Super Admin team.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Your name *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contact mobile number *',
                        prefixIcon: Icon(Icons.phone_outlined),
                        hintText: '10-digit number or +country code',
                      ),
                      validator: (value) {
                        final digits =
                            (value ?? '').replaceAll(RegExp(r'\D'), '');
                        return digits.length < 10 || digits.length > 15
                            ? 'Enter a valid contact number.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _subjectController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 160,
                      decoration: const InputDecoration(
                        labelText: 'Heading / reason *',
                        prefixIcon: Icon(Icons.subject),
                        hintText: 'For example, request masjid admin access',
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 4,
                      maxLines: 7,
                      maxLength: 4000,
                      decoration: const InputDecoration(
                        labelText: 'Message *',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.message_outlined),
                      ),
                      validator: _required,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: const TextStyle(color: AppColors.emergency)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send),
                      label:
                          Text(_sending ? 'Sending…' : 'Send to Super Admin'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;
}
