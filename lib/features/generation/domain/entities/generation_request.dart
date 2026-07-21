import 'generation_mode.dart';

/// A validated request to transform source text into a Syncless document.
class GenerationRequest {
  GenerationRequest({
    required String sourceText,
    required this.mode,
  }) : sourceText = sourceText.trim() {
    if (this.sourceText.isEmpty) {
      throw ArgumentError.value(
        sourceText,
        'sourceText',
        'A conversation or set of notes is required.',
      );
    }
  }

  final String sourceText;
  final GenerationMode mode;

  int get characterCount => sourceText.length;

  Map<String, dynamic> toApiJson() {
    return {
      'sourceText': sourceText,
      'mode': mode.apiValue,
    };
  }
}
