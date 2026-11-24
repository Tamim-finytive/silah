import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/constants/app_colors.dart';

class NoticeAudioPlayer extends StatefulWidget {
  final String audioUrl;
  final bool autoPlay;

  const NoticeAudioPlayer({
    super.key,
    required this.audioUrl,
    this.autoPlay = false,
  });

  @override
  State<NoticeAudioPlayer> createState() => _NoticeAudioPlayerState();
}

class _NoticeAudioPlayerState extends State<NoticeAudioPlayer> {
  late final AudioPlayer _player;
  bool _isInit = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _player.setUrl(widget.audioUrl);
      if (mounted) {
        setState(() => _isInit = true);
        if (widget.autoPlay) {
          _player.play();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '--:--';
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.error_outline, size: 18, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'Could not load voice message',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F432B).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF0F432B).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snapshot) {
                  final state = snapshot.data;
                  final isPlaying = state?.playing == true;
                  final isCompleted =
                      state?.processingState == ProcessingState.completed;

                  return Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F432B),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        isCompleted
                            ? Icons.replay
                            : isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: !_isInit
                          ? null
                          : () {
                              if (isCompleted) {
                                _player.seek(Duration.zero);
                                _player.play();
                              } else if (isPlaying) {
                                _player.pause();
                              } else {
                                _player.play();
                              }
                            },
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final total = _player.duration ?? Duration.zero;
                    final maxSec = total.inMilliseconds > 0
                        ? total.inMilliseconds.toDouble()
                        : 1.0;
                    final curSec = position.inMilliseconds.toDouble().clamp(
                          0.0,
                          maxSec,
                        );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            activeTrackColor: const Color(0xFF0F432B),
                            inactiveTrackColor: Colors.grey.shade300,
                            thumbColor: const Color(0xFF0F432B),
                            overlayShape: SliderComponentShape.noOverlay,
                          ),
                          child: Slider(
                            value: curSec,
                            max: maxSec,
                            onChanged: (val) {
                              _player.seek(
                                Duration(milliseconds: val.toInt()),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(position),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.mic,
                                    size: 13,
                                    color: Color(0xFF0F432B),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _formatDuration(total),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F432B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
