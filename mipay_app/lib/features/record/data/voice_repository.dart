import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_client.dart';
import '../models/voice_extraction.dart';

class VoiceRepository {
  const VoiceRepository(this._dio);
  final Dio _dio;

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Mode A: upload the recorded clip → STT → extraction. Long timeout:
  /// CPU-only server takes ~10–15 s (§NFR-01).
  Future<VoiceExtractionResult> extractFromAudio(
    String filePath, {
    required String locale,
  }) async {
    final form = FormData.fromMap({
      'audio': await MultipartFile.fromFile(filePath, filename: 'voice.m4a'),
      'client_date': _today(),
      'client_locale': locale,
    });
    final r = await _dio.post(
      '/transactions/voice',
      data: form,
      options: Options(receiveTimeout: const Duration(seconds: 120)),
    );
    return VoiceExtractionResult.fromJson(r.data as Map<String, dynamic>);
  }

  /// Mode B: typed text — same pipeline, no STT (FEATURES.md §2).
  Future<VoiceExtractionResult> extractFromText(
    String text, {
    required String locale,
  }) async {
    final r = await _dio.post(
      '/transactions/extract-text',
      data: {'text': text, 'client_date': _today(), 'client_locale': locale},
      options: Options(receiveTimeout: const Duration(seconds: 120)),
    );
    return VoiceExtractionResult.fromJson(r.data as Map<String, dynamic>);
  }
}

final voiceRepositoryProvider = Provider<VoiceRepository>(
  (ref) => VoiceRepository(ref.watch(dioProvider)),
);
