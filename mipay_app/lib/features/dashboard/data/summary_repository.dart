import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_client.dart';
import '../models/summary.dart';

class SummaryRepository {
  const SummaryRepository(this._dio);
  final Dio _dio;

  Future<Summary> getSummary(String month) async {
    final r = await _dio.get('/summary', queryParameters: {'month': month});
    return Summary.fromJson(r.data as Map<String, dynamic>);
  }
}

final summaryRepositoryProvider = Provider<SummaryRepository>(
  (ref) => SummaryRepository(ref.watch(dioProvider)),
);
