import '../entities/generation_outcome.dart';
import '../entities/generation_request.dart';

/// The only generation boundary available to presentation code.
abstract interface class GenerationRepository {
  /// Sends an authenticated request to the server for quota enforcement and
  /// GPT-5.6 processing. The client must never perform quota checks itself.
  Future<GenerationOutcome> generate(GenerationRequest request);
}
