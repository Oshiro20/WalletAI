/// Entidad de dominio para Patrimonio Neto (Net Worth)
/// Lógica contable pura: Activos - Pasivos = Patrimonio Neto
class NetWorthEntity {
  final double totalAssets;
  final double totalLiabilities;
  final List<AccountBreakdown> assetAccounts;
  final List<AccountBreakdown> liabilityAccounts;
  final DateTime calculatedAt;

  NetWorthEntity({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.assetAccounts,
    required this.liabilityAccounts,
    DateTime? calculatedAt,
  }) : calculatedAt = calculatedAt ?? DateTime.now();

  double get netWorth => totalAssets - totalLiabilities;

  /// Porcentaje de activos sobre el total
  double get assetsPercentage => (totalAssets + totalLiabilities) > 0
      ? totalAssets / (totalAssets + totalLiabilities) * 100
      : 50.0;

  /// Porcentaje de pasivos sobre el total
  double get liabilitiesPercentage => 100 - assetsPercentage;

  /// Ratio de endeudamiento (deuda/activos)
  double get debtToAssetRatio =>
      totalAssets > 0 ? totalLiabilities / totalAssets : 0.0;

  /// Salud financiera (0-100)
  /// Basada en: ratio de endeudamiento, proporción activos/pasivos
  double get financialHealthScore {
    if (totalAssets == 0 && totalLiabilities == 0) return 50.0;
    if (totalAssets == 0) return 0.0;

    // Factor 1: Ratio de endeudamiento (0-40 puntos)
    final debtRatioScore = (1 - debtToAssetRatio).clamp(0.0, 1.0) * 40;

    // Factor 2: Proporción activos (0-30 puntos)
    final assetPropScore = assetsPercentage.clamp(0.0, 100.0) / 100 * 30;

    // Factor 3: Patrimonio positivo (0-30 puntos)
    final netWorthScore = netWorth > 0
        ? 30.0
        : (30 + netWorth / totalAssets * 30).clamp(0.0, 30.0);

    return (debtRatioScore + assetPropScore + netWorthScore).clamp(0.0, 100.0);
  }

  /// Estado financiero
  String get financialStatus {
    final score = financialHealthScore;
    if (score >= 80) return 'Excelente';
    if (score >= 60) return 'Buena';
    if (score >= 40) return 'Regular';
    if (score >= 20) return 'Precaución';
    return 'Crítico';
  }
}

/// Desglose de una cuenta individual
class AccountBreakdown {
  final String id;
  final String name;
  final String type;
  final String? institution;
  final double balance;
  final double? creditLimit;
  final String? currency;
  final double percentage;

  const AccountBreakdown({
    required this.id,
    required this.name,
    required this.type,
    this.institution,
    required this.balance,
    this.creditLimit,
    this.currency,
    required this.percentage,
  });

  /// Para tarjetas de crédito: porcentaje de límite utilizado
  double get creditUtilization => creditLimit != null && creditLimit! > 0
      ? balance.abs() / creditLimit! * 100
      : 0.0;

  bool get isOverutilized => creditUtilization > 80;
}

/// Historial de patrimonio neto para sparkline
class NetWorthSnapshot {
  final DateTime date;
  final double netWorth;
  final double assets;
  final double liabilities;

  const NetWorthSnapshot({
    required this.date,
    required this.netWorth,
    required this.assets,
    required this.liabilities,
  });
}
