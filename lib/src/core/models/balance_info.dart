class BalanceInfo {
  final double totalBalance;
  final String totalBalanceFormatted;
  final double pendingBalance;
  final String pendingBalanceFormatted;
  final double withdrawableBalance;
  final String withdrawableBalanceFormatted;

  const BalanceInfo({
    required this.totalBalance,
    required this.totalBalanceFormatted,
    required this.pendingBalance,
    required this.pendingBalanceFormatted,
    required this.withdrawableBalance,
    required this.withdrawableBalanceFormatted,
  });

  factory BalanceInfo.fromJson(Map<String, dynamic> json) {
    return BalanceInfo(
      totalBalance: (json['total_balance'] ?? 0).toDouble(),
      totalBalanceFormatted: json['total_balance_formatted'] ?? '0 ₫',
      pendingBalance: (json['pending_balance'] ?? 0).toDouble(),
      pendingBalanceFormatted: json['pending_balance_formatted'] ?? '0 ₫',
      withdrawableBalance: (json['withdrawable_balance'] ?? 0).toDouble(),
      withdrawableBalanceFormatted: json['withdrawable_balance_formatted'] ?? '0 ₫',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_balance': totalBalance,
      'total_balance_formatted': totalBalanceFormatted,
      'pending_balance': pendingBalance,
      'pending_balance_formatted': pendingBalanceFormatted,
      'withdrawable_balance': withdrawableBalance,
      'withdrawable_balance_formatted': withdrawableBalanceFormatted,
    };
  }
}

class ClaimInfo {
  final bool canClaim;
  final double claimableAmount;
  final String claimableAmountFormatted;
  final int claimableTransactionsCount;
  final int? earliestAvailableTime; // Unix timestamp
  final int? daysRemaining;
  final int? hoursRemaining;

  const ClaimInfo({
    required this.canClaim,
    required this.claimableAmount,
    required this.claimableAmountFormatted,
    required this.claimableTransactionsCount,
    this.earliestAvailableTime,
    this.daysRemaining,
    this.hoursRemaining,
  });

  factory ClaimInfo.fromJson(Map<String, dynamic> json) {
    return ClaimInfo(
      canClaim: json['can_claim'] ?? false,
      claimableAmount: (json['claimable_amount'] ?? 0).toDouble(),
      claimableAmountFormatted: json['claimable_amount_formatted'] ?? '0 ₫',
      claimableTransactionsCount: json['claimable_transactions_count'] ?? 0,
      earliestAvailableTime: json['earliest_available_time'] != null ? int.tryParse(json['earliest_available_time'].toString()) : null,
      daysRemaining: json['days_remaining'] != null ? int.tryParse(json['days_remaining'].toString()) : null,
      hoursRemaining: json['hours_remaining'] != null ? int.tryParse(json['hours_remaining'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'can_claim': canClaim,
      'claimable_amount': claimableAmount,
      'claimable_amount_formatted': claimableAmountFormatted,
      'claimable_transactions_count': claimableTransactionsCount,
      'earliest_available_time': earliestAvailableTime,
      'days_remaining': daysRemaining,
      'hours_remaining': hoursRemaining,
    };
  }

  /// Format thời gian còn lại
  String get formattedTimeRemaining {
    if (daysRemaining == null || daysRemaining! < 0) return '';
    if (daysRemaining == 0 && hoursRemaining != null && hoursRemaining! > 0) {
      return ' $hoursRemaining giờ';
    } else if (daysRemaining! > 0) {
      if (hoursRemaining != null && hoursRemaining! > 0) {
        return ' $daysRemaining ngày $hoursRemaining giờ';
      }
      return ' $daysRemaining ngày';
    }
    return 'Có thể rút ngay';
  }
}
