import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/providers/current_user_provider.dart';
import '../data/voice_repository.dart';
import '../models/voice_extraction.dart';

const int kMaxRecordSeconds = 30; // mirror of backend MAX_AUDIO_SECONDS

// ── States: idle → recording(elapsed) → processing → result | error ─────────

sealed class RecordingState {
  const RecordingState();
}

class RecordingIdle extends RecordingState {
  const RecordingIdle();
}

class RecordingActive extends RecordingState {
  const RecordingActive(this.elapsedSeconds);
  final int elapsedSeconds;

  int get remainingSeconds => kMaxRecordSeconds - elapsedSeconds;
}

class RecordingProcessing extends RecordingState {
  const RecordingProcessing();
}

class RecordingResult extends RecordingState {
  const RecordingResult(this.result);
  final VoiceExtractionResult result;
}

class RecordingError extends RecordingState {
  const RecordingError({this.apiException, this.permissionDenied = false});
  final ApiException? apiException;
  final bool permissionDenied;
}

// ── Controller ──────────────────────────────────────────────────────────────

class RecordingController extends StateNotifier<RecordingState> {
  RecordingController(this._repo) : super(const RecordingIdle());

  final VoiceRepository _repo;
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> startRecording() async {
    if (state is RecordingActive || state is RecordingProcessing) return;

    if (!await _recorder.hasPermission()) {
      state = const RecordingError(permissionDenied: true);
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/mipay_${DateTime.now().millisecondsSinceEpoch}.m4a';

    // §7.1: AAC-LC m4a, 16 kHz, mono, ~64 kbps
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 64000,
      ),
      path: path,
    );

    state = const RecordingActive(0);
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = state;
      if (current is! RecordingActive) {
        timer.cancel();
        return;
      }
      final elapsed = current.elapsedSeconds + 1;
      if (elapsed >= kMaxRecordSeconds) {
        stopAndProcess(locale: _lastLocale); // auto-stop at the cap
      } else {
        state = RecordingActive(elapsed);
      }
    });
  }

  String _lastLocale = 'en';

  Future<void> stopAndProcess({required String locale}) async {
    _lastLocale = locale;
    if (state is! RecordingActive) return;
    _ticker?.cancel();
    state = const RecordingProcessing();

    String? path;
    try {
      path = await _recorder.stop();
      if (path == null) {
        state = const RecordingError();
        return;
      }
      final result = await _repo.extractFromAudio(path, locale: locale);
      state = RecordingResult(result);
    } catch (e) {
      state = RecordingError(apiException: _toApiException(e));
    } finally {
      if (path != null) {
        File(path).delete().ignore(); // clip never persists on device either
      }
    }
  }

  Future<void> cancelRecording() async {
    _ticker?.cancel();
    final path = await _recorder.stop();
    if (path != null) File(path).delete().ignore();
    state = const RecordingIdle();
  }

  /// Mode B (FEATURES.md): typed text — skips recording entirely.
  Future<void> submitText(String text, {required String locale}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state is RecordingProcessing) return;
    state = const RecordingProcessing();
    try {
      final result = await _repo.extractFromText(trimmed, locale: locale);
      state = RecordingResult(result);
    } catch (e) {
      state = RecordingError(apiException: _toApiException(e));
    }
  }

  void reset() {
    _ticker?.cancel();
    state = const RecordingIdle();
  }

  static ApiException? _toApiException(Object e) {
    if (e is DioException && e.error is ApiException) return e.error as ApiException;
    return null;
  }
}

final recordingControllerProvider =
    StateNotifierProvider.autoDispose<RecordingController, RecordingState>(
        (ref) {
  ref.watch(currentUserIdProvider); // reset when user changes
  return RecordingController(ref.watch(voiceRepositoryProvider));
});
