/// The centrally managed entitlement tiers exposed by Syncless.
///
/// A plan is determined by Supabase-backed subscription state, never by the
/// Flutter client or the payment channel that originated the purchase.
enum SubscriptionPlan {
  free(apiValue: 'free', displayName: 'Free'),
  pro(apiValue: 'pro', displayName: 'Pro');

  const SubscriptionPlan({
    required this.apiValue,
    required this.displayName,
  });

  final String apiValue;
  final String displayName;

  bool get isPro => this == SubscriptionPlan.pro;

  static SubscriptionPlan fromApiValue(String value) {
    return SubscriptionPlan.values.firstWhere(
      (plan) => plan.apiValue == value,
      orElse: () => throw ArgumentError.value(
        value,
        'value',
        'Unsupported subscription plan',
      ),
    );
  }
}
