import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/generation_outcome.dart';
import '../../domain/entities/generation_quota.dart';
import '../../domain/entities/generation_request.dart';
import '../../domain/entities/generation_result.dart';
import '../../domain/repositories/generation_repository.dart';

class SupabaseGenerationRepository implements GenerationRepository {
  SupabaseGenerationRepository(this._client);

  static const _functionName = 'generate-document';

  final SupabaseClient _client;

  @override
  Future<GenerationOutcome> generate(GenerationRequest request) async {
    try {
      final response = await _client.functions.invoke(
        _functionName,
        body: request.toApiJson(),
      );
      final data = response.data;

      if (data is! Map) {
        throw const FormatException('Generation service returned an invalid response.');
      }

      final payload = Map<String, dynamic>.from(data);
      final quota = GenerationQuota.fromApiJson(payload);

      if (!quota.allowed) {
        return GenerationOutcome(quota: quota);
      }

      final rawResult = payload['result'];
      if (rawResult is! Map) {
        throw const FormatException('Generation service returned no document.');
      }

      return GenerationOutcome(
        quota: quota,
        result: GenerationResult.fromApiJson(Map<String, dynamic>.from(rawResult)),
      );
    } on GenerationRemoteException {
      rethrow;
    } catch (error, stackTrace) {
      throw GenerationRemoteException(
        'Unable to generate your document. Please try again.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}

/// A safe, user-presentable error from the remote generation boundary.
class GenerationRemoteException implements Exception {
  const GenerationRemoteException(
    this.message, {
    this.cause,
    this.stackTrace,
  });

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => message;
}
