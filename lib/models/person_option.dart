class PersonOption {
  const PersonOption({
    required this.customerId,
    required this.displayName,
    required this.openCheckId,
    required this.createdAtMillis,
  });

  final String customerId;
  final String displayName;
  final String openCheckId;
  final int createdAtMillis;
}
