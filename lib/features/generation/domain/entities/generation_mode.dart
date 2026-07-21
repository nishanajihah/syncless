/// The document types Syncless can generate from a source conversation.
///
/// The API identifier is intentionally stable: it is the value persisted in
/// Supabase and passed to the generation Edge Function.
enum GenerationMode {
  workSpecification(
    apiValue: 'work_specification',
    label: 'Work Spec',
    requiresPro: false,
  ),
  sprintPlan(
    apiValue: 'sprint_plan',
    label: 'Sprint Plan',
    requiresPro: true,
  ),
  executiveBrief(
    apiValue: 'executive_brief',
    label: 'Executive Brief',
    requiresPro: true,
  );

  const GenerationMode({
    required this.apiValue,
    required this.label,
    required this.requiresPro,
  });

  final String apiValue;
  final String label;
  final bool requiresPro;

  static GenerationMode fromApiValue(String value) {
    return GenerationMode.values.firstWhere(
      (mode) => mode.apiValue == value,
      orElse: () => throw ArgumentError.value(
        value,
        'value',
        'Unsupported generation mode',
      ),
    );
  }
}
