import 'generation_quota.dart';
import 'generation_result.dart';

/// The full outcome of one authenticated generation request.
///
/// A generated document exists only when the server authorized the request.
class GenerationOutcome {
  GenerationOutcome({
    required this.quota,
    this.result,
  }) : assert(
          quota.allowed ? result != null : result == null,
          'Allowed requests require a result; denied requests must not include one.',
        );

  final GenerationQuota quota;
  final GenerationResult? result;

  bool get isSuccessful => quota.allowed && result != null;
}
