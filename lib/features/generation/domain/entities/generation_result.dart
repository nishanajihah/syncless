/// A completed, server-generated Syncless document and its decision support.
class GenerationResult {
  const GenerationResult({
    required this.title,
    required this.markdown,
    required this.confidence,
    required this.missingInformation,
    required this.potentialRisks,
    required this.followUpQuestions,
  });

  final String title;
  final String markdown;

  /// A normalized score in the inclusive range from 0.0 to 1.0.
  final double confidence;
  final List<String> missingInformation;
  final List<String> potentialRisks;
  final List<String> followUpQuestions;

  factory GenerationResult.fromApiJson(Map<String, dynamic> json) {
    final title = json['title'];
    final markdown = json['markdown'];
    final rawConfidence = json['confidence'];

    if (title is! String || title.trim().isEmpty) {
      throw const FormatException('Generation result is missing a title.');
    }
    if (markdown is! String || markdown.trim().isEmpty) {
      throw const FormatException('Generation result is missing Markdown content.');
    }
    if (rawConfidence is! num || rawConfidence < 0 || rawConfidence > 1) {
      throw const FormatException('Generation result has an invalid confidence score.');
    }

    return GenerationResult(
      title: title,
      markdown: markdown,
      confidence: rawConfidence.toDouble(),
      missingInformation: _readStringList(json, 'missingInformation'),
      potentialRisks: _readStringList(json, 'potentialRisks'),
      followUpQuestions: _readStringList(json, 'followUpQuestions'),
    );
  }

  static List<String> _readStringList(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! List || value.any((item) => item is! String)) {
      throw FormatException('Generation result has an invalid $key field.');
    }

    return List<String>.unmodifiable(value.cast<String>());
  }
}
