import '../../../subscription/domain/entities/subscription_plan.dart';

/// The server-authoritative outcome of a generation permission check.
class GenerationQuota {
  const GenerationQuota({
    required this.allowed,
    required this.plan,
    this.remaining,
    this.resetAt,
  });

  final bool allowed;
  final SubscriptionPlan plan;
  final int? remaining;
  final DateTime? resetAt;

  bool get isExhausted => !allowed && remaining == 0;

  factory GenerationQuota.fromApiJson(Map<String, dynamic> json) {
    final rawAllowed = json['allowed'];
    final rawPlan = json['plan'];

    if (rawAllowed is! bool || rawPlan is! String) {
      throw const FormatException('Invalid generation quota response.');
    }

    final rawRemaining = json['remaining'];
    if (rawRemaining != null && rawRemaining is! num) {
      throw const FormatException('Invalid remaining quota value.');
    }

    final rawResetAt = json['resetAt'];
    if (rawResetAt != null && rawResetAt is! String) {
      throw const FormatException('Invalid quota reset timestamp.');
    }

    return GenerationQuota(
      allowed: rawAllowed,
      plan: SubscriptionPlan.fromApiValue(rawPlan),
      remaining: (rawRemaining as num?)?.toInt(),
      resetAt: rawResetAt == null ? null : DateTime.parse(rawResetAt).toUtc(),
    );
  }
}
