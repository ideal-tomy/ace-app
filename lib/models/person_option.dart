import '../core/business_mode.dart';

class PersonOption {
  const PersonOption({
    required this.customerId,
    required this.displayName,
    required this.openCheckId,
    required this.createdAtMillis,
    this.billingMode = BusinessMode.event,
    this.switchedFromEvent = false,
    this.totalTaxIncluded = 0,
    this.peopleCount = 1,
    this.nomihodaiStartedAtMillis,
  });

  final String customerId;
  final String displayName;
  final String openCheckId;
  final int createdAtMillis;
  final BusinessMode billingMode;
  final bool switchedFromEvent;
  final int totalTaxIncluded;
  final int peopleCount;
  final int? nomihodaiStartedAtMillis;

  String get modeBadgeLabel {
    if (switchedFromEvent && billingMode == BusinessMode.normal) {
      return 'イベント→通常';
    }
    return billingMode.label;
  }

  DateTime get createdAt =>
      DateTime.fromMillisecondsSinceEpoch(createdAtMillis);
}
