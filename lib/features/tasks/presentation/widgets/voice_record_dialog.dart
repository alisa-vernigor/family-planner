import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/logging/app_logger.dart';
import '../../domain/services/ai_task_service.dart';

class VoiceRecordDialog extends StatefulWidget {
  const VoiceRecordDialog({super.key});

  @override
  State<VoiceRecordDialog> createState() => _VoiceRecordDialogState();
}

class _VoiceRecordDialogState extends State<VoiceRecordDialog> with SingleTickerProviderStateMixin {
  late final AudioRecorder _audioRecorder;
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;

  StreamSubscription<Amplitude>? _amplitudeSubscription;
  String? _filePath;

  bool _isRecording = false;
  bool _isProcessing = false;
  String _statusText = 'Говорите...';

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _startRecording();
  }

  @override
  void dispose() {
    _amplitudeSubscription?.cancel();
    _audioRecorder.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        _filePath = '${dir.path}/task_audio.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
          path: _filePath!,
        );

        setState(() {
          _isRecording = true;
        });

        _amplitudeSubscription = _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) {
          if (mounted) {
            // Нормализация амплитуды для анимации (от -40 до 0 dB -> от 0.0 до 1.0)
            final amplitude = ((amp.current.clamp(-40.0, 0.0) + 40) / 40.0).clamp(0.0, 1.0);
            _animationController.animateTo(amplitude, duration: const Duration(milliseconds: 50));
          }
        });
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e, st) {
      AppLogger.error('Ошибка записи', error: e, stackTrace: st);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _stopAndProcess() async {
    if (!_isRecording || _isProcessing) return;

    setState(() {
      _isRecording = false;
      _isProcessing = true;
      _statusText = 'Распознавание...';
    });

    _animationController.animateTo(0.0);
    _amplitudeSubscription?.cancel();
    await _audioRecorder.stop();

    if (_filePath == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    try {
      final aiService = AITaskService();
      
      final text = await aiService.transcribeAudio(_filePath!);
      if (text.trim().isEmpty) {
        throw Exception('Пустая запись');
      }

      setState(() {
        _statusText = 'Создание задачи...';
      });

      final taskResult = await aiService.parseTaskFromText(text);
      if (mounted) Navigator.pop(context, taskResult);
    } catch (e, st) {
      AppLogger.error('Ошибка AI', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось распознать голос')));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _statusText,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_isProcessing)
              const CircularProgressIndicator()
            else
              GestureDetector(
                onTap: _stopAndProcess,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primary,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.stop,
                      color: colorScheme.onPrimary,
                      size: 40,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 32),
            if (!_isProcessing)
              TextButton(
                onPressed: () async {
                  await _audioRecorder.stop();
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Отмена'),
              ),
          ],
        ),
      ),
    );
  }
}