import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_service.dart';

typedef NoticeSaveCallback = Future<void> Function(
  String title,
  String message, {
  String? imageUrl,
  String? audioUrl,
  int? audioDuration,
});

class NoticeEditorScreen extends StatefulWidget {
  final NoticeSaveCallback onSave;

  const NoticeEditorScreen({super.key, required this.onSave});

  @override
  State<NoticeEditorScreen> createState() => _NoticeEditorScreenState();
}

class _NoticeEditorScreenState extends State<NoticeEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  // Media state
  File? _selectedImage;
  File? _recordedAudioFile;
  int _audioDurationSeconds = 0;

  // Recording state
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  Timer? _recordTimer;
  int _recordElapsedSeconds = 0;

  // Audio preview player
  late final AudioPlayer _previewPlayer;
  bool _isPlayingPreview = false;
  Duration _previewPosition = Duration.zero;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;

  // Status state
  bool _saving = false;
  String? _statusMessage;
  String? _error;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _previewPlayer = AudioPlayer();

    _playerStateSub = _previewPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingPreview = state.playing &&
              state.processingState != ProcessingState.completed;
          if (state.processingState == ProcessingState.completed) {
            _previewPosition = Duration.zero;
          }
        });
      }
    });

    _positionSub = _previewPlayer.positionStream.listen((pos) {
      if (mounted) {
        setState(() => _previewPosition = pos);
      }
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _previewPlayer.dispose();
    _audioRecorder.dispose();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // --- Image Handling ---

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Attach Image',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.primary),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeImage() {
    setState(() => _selectedImage = null);
  }

  // --- Audio Recording Handling ---

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path =
            '${tempDir.path}/notice_rec_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordElapsedSeconds = 0;
          _error = null;
        });

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() => _recordElapsedSeconds = timer.tick);
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Microphone permission is required to record.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not start recording: $e');
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordTimer?.cancel();
      final path = await _audioRecorder.stop();
      if (path != null) {
        final file = File(path);
        final seconds = _recordElapsedSeconds;
        setState(() {
          _isRecording = false;
          _recordedAudioFile = file;
          _audioDurationSeconds = seconds;
        });
        await _previewPlayer.setFilePath(path);
      } else {
        setState(() => _isRecording = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _error = 'Could not stop recording: $e';
        });
      }
    }
  }

  Future<void> _deleteAudio() async {
    await _previewPlayer.stop();
    setState(() {
      _recordedAudioFile = null;
      _audioDurationSeconds = 0;
      _previewPosition = Duration.zero;
    });
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // --- Submission ---

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    if (_isRecording) {
      await _stopRecording();
    }

    setState(() {
      _saving = true;
      _error = null;
      _statusMessage = 'Preparing notice…';
    });

    try {
      String? uploadedImageUrl;
      String? uploadedAudioUrl;

      // 1. Upload Image if present
      if (_selectedImage != null) {
        setState(() => _statusMessage = 'Uploading image…');
        uploadedImageUrl =
            await ApiService.instance.uploadFile(_selectedImage!.path);
      }

      // 2. Upload Audio if present
      if (_recordedAudioFile != null) {
        setState(() => _statusMessage = 'Uploading voice message…');
        uploadedAudioUrl =
            await ApiService.instance.uploadFile(_recordedAudioFile!.path);
      }

      // 3. Save Announcement
      setState(() => _statusMessage = 'Sending notice…');
      await widget.onSave(
        _titleController.text.trim(),
        _messageController.text.trim(),
        imageUrl: uploadedImageUrl,
        audioUrl: uploadedAudioUrl,
        audioDuration: _audioDurationSeconds > 0 ? _audioDurationSeconds : null,
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _statusMessage = null;
        _error = 'Notice could not be sent: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        title: const Text('New Notice'),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  const Text(
                    'Share an update with your connected members. You can attach an image and record a voice message.',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4),
                  ),
                  const SizedBox(height: 20),

                  // 1. Heading Input
                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Heading *',
                      hintText: 'Enter a clear notice heading',
                      prefixIcon: Icon(Icons.title_rounded),
                      filled: true,
                      fillColor: AppColors.surfaceCard,
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.outline),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: AppColors.primary, width: 1.5),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a heading'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // 2. Message / Content Input
                  TextFormField(
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    minLines: 4,
                    maxLines: 7,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Description / Message *',
                      hintText: 'Write the notice content or details…',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_rounded),
                      filled: true,
                      fillColor: AppColors.surfaceCard,
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.outline),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: AppColors.primary, width: 1.5),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter the notice message'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  // 3. Image Attachment Section
                  _buildImageSection(),
                  const SizedBox(height: 20),

                  // 4. Voice Note Recording Section
                  _buildAudioSection(),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.emergency.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.emergency, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color: AppColors.emergency, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                    _saving ? (_statusMessage ?? 'Sending…') : 'Send Notice'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Widget: Image Attachment Box ---
  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Image Attachment',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            if (_selectedImage != null)
              TextButton.icon(
                onPressed: _removeImage,
                icon: const Icon(Icons.close, size: 16, color: Colors.red),
                label: const Text('Remove',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedImage == null)
          OutlinedButton.icon(
            onPressed: _showImagePickerSheet,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_photo_alternate_outlined,
                color: AppColors.primary),
            label: const Text('Add Photo / Image',
                style: TextStyle(color: AppColors.primary)),
          )
        else
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 12),
                      color: Colors.black54,
                      child: Row(
                        children: [
                          const Icon(Icons.image,
                              color: Colors.white70, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _selectedImage!.path.split('/').last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // --- Widget: Voice Note Recording Box ---
  Widget _buildAudioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Voice Message',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            if (_recordedAudioFile != null)
              TextButton.icon(
                onPressed: _deleteAudio,
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: Colors.red),
                label: const Text('Discard',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // 1. Not Recording and No Audio Recorded yet
        if (!_isRecording && _recordedAudioFile == null)
          OutlinedButton.icon(
            onPressed: _startRecording,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.mic_none_rounded, color: AppColors.primary),
            label: const Text('Record Voice Message',
                style: TextStyle(color: AppColors.primary)),
          ),

        // 2. Currently Recording
        if (_isRecording)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.fiber_manual_record,
                    color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Recording… ${_formatTime(_recordElapsedSeconds)}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: _stopRecording,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.stop_rounded, size: 18),
                  label: const Text('Done'),
                ),
              ],
            ),
          ),

        // 3. Audio Recorded - Playback Preview
        if (!_isRecording && _recordedAudioFile != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F432B).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF0F432B).withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPlayingPreview
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        color: AppColors.primary,
                        size: 36,
                      ),
                      onPressed: () {
                        if (_isPlayingPreview) {
                          _previewPlayer.pause();
                        } else {
                          _previewPlayer.play();
                        }
                      },
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Voice Message Preview',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                '${_formatTime(_previewPosition.inSeconds)} / ${_formatTime(_audioDurationSeconds)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 10),
                              activeTrackColor: AppColors.primary,
                              inactiveTrackColor: Colors.grey.shade300,
                              thumbColor: AppColors.primary,
                            ),
                            child: Slider(
                              min: 0.0,
                              max: _audioDurationSeconds > 0
                                  ? _audioDurationSeconds.toDouble()
                                  : 1.0,
                              value:
                                  _previewPosition.inSeconds.toDouble().clamp(
                                        0.0,
                                        _audioDurationSeconds > 0
                                            ? _audioDurationSeconds.toDouble()
                                            : 1.0,
                                      ),
                              onChanged: (val) {
                                _previewPlayer
                                    .seek(Duration(seconds: val.toInt()));
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
