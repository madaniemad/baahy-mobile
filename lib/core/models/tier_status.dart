class TierStatus {
  final String? tier;
  final int totalDelivered;
  final int ordersCount;
  final double spendAmount;
  final String? nextTier;
  final int ordersNeeded;
  final double spendNeeded;
  final int ordersRemaining;
  final double spendRemaining;
  final int? nextMilestoneOrder;
  final double? nextMilestoneReward;
  final int? nextMilestoneRemaining;
  final double cashbackRate;
  final double freeShippingThreshold;
  final int returnDays;
  final double pendingTotal;
  final List<Map<String, dynamic>> pendingMilestones;
  final int pendingReferralCount;
  final bool pendingReceiverReward;

  const TierStatus({
    required this.tier,
    required this.totalDelivered,
    required this.ordersCount,
    required this.spendAmount,
    required this.nextTier,
    required this.ordersNeeded,
    required this.spendNeeded,
    required this.ordersRemaining,
    required this.spendRemaining,
    this.nextMilestoneOrder,
    this.nextMilestoneReward,
    this.nextMilestoneRemaining,
    required this.cashbackRate,
    required this.freeShippingThreshold,
    required this.returnDays,
    this.pendingTotal = 0.0,
    this.pendingMilestones = const [],
    this.pendingReferralCount = 0,
    this.pendingReceiverReward = false,
  });

  factory TierStatus.fromJson(Map<String, dynamic> j) {
    final stats = j['stats'] as Map<String, dynamic>? ?? {};
    final progress = j['progress'] as Map<String, dynamic>?;
    final milestone = j['next_milestone'] as Map<String, dynamic>?;
    final benefits = j['benefits'] as Map<String, dynamic>? ?? {};
    return TierStatus(
      tier: j['tier'] as String?,
      totalDelivered: (j['total_delivered'] as num?)?.toInt() ?? 0,
      ordersCount: (stats['orders_count'] as num?)?.toInt() ?? 0,
      spendAmount: (stats['spend_amount'] as num?)?.toDouble() ?? 0.0,
      nextTier: progress?['next_tier'] as String?,
      ordersNeeded: (progress?['orders_needed'] as num?)?.toInt() ?? 0,
      spendNeeded: (progress?['spend_needed'] as num?)?.toDouble() ?? 0.0,
      ordersRemaining: (progress?['orders_remaining'] as num?)?.toInt() ?? 0,
      spendRemaining: (progress?['spend_remaining'] as num?)?.toDouble() ?? 0.0,
      nextMilestoneOrder: (milestone?['order_number'] as num?)?.toInt(),
      nextMilestoneReward: (milestone?['reward_amount'] as num?)?.toDouble(),
      nextMilestoneRemaining: (milestone?['orders_remaining'] as num?)?.toInt(),
      cashbackRate: (benefits['cashback_rate'] as num?)?.toDouble() ?? 2.0,
      freeShippingThreshold: (benefits['free_shipping_threshold'] as num?)?.toDouble() ?? 150.0,
      returnDays: (benefits['return_days'] as num?)?.toInt() ?? 7,
      pendingTotal: ((j['pending_rewards'] as Map?)?['total'] as num?)?.toDouble() ?? 0.0,
      pendingMilestones: ((j['pending_rewards'] as Map?)?['milestones'] as List?)
          ?.cast<Map<String, dynamic>>() ?? [],
      pendingReferralCount: ((j['pending_rewards'] as Map?)?['referral_count'] as num?)?.toInt() ?? 0,
      pendingReceiverReward: (j['pending_rewards'] as Map?)?['receiver_pending'] == true,
    );
  }

  static const TierStatus empty = TierStatus(
    tier: null,
    totalDelivered: 0,
    ordersCount: 0,
    spendAmount: 0,
    nextTier: 'silver',
    ordersNeeded: 5,
    spendNeeded: 500,
    ordersRemaining: 5,
    spendRemaining: 500,
    nextMilestoneOrder: 1,
    nextMilestoneReward: 5,
    nextMilestoneRemaining: 1,
    cashbackRate: 2.0,
    freeShippingThreshold: 150.0,
    returnDays: 7,
  );
}
