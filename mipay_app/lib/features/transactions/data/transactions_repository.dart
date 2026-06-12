import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_client.dart';
import '../models/category.dart';
import '../models/transaction.dart';

class TransactionsRepository {
  const TransactionsRepository(this._dio);
  final Dio _dio;

  Future<List<Transaction>> list(TransactionFilter filter, {int page = 1, int pageSize = 100}) async {
    final r = await _dio.get('/transactions', queryParameters: {
      ...filter.toQuery(),
      'page': page,
      'page_size': pageSize,
    });
    final data = r.data as Map<String, dynamic>;
    return (data['items'] as List)
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Transaction> create(TransactionDraft draft) async {
    final r = await _dio.post('/transactions', data: draft.toJson());
    return Transaction.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Transaction> update(String id, TransactionDraft draft) async {
    // PATCH accepts partial bodies; sending the full draft is fine too.
    final r = await _dio.patch('/transactions/$id', data: draft.toJson()..remove('source')..remove('transcript'));
    return Transaction.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _dio.delete('/transactions/$id');
  }

  Future<List<Category>> categories() async {
    final r = await _dio.get('/categories');
    return (r.data as List)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final transactionsRepositoryProvider = Provider<TransactionsRepository>(
  (ref) => TransactionsRepository(ref.watch(dioProvider)),
);
