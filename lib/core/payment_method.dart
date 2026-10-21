enum PaymentMethod { cash, card, other }

extension PaymentMethodCodec on PaymentMethod {
  String get firestoreValue => switch (this) {
    PaymentMethod.cash => 'cash',
    PaymentMethod.card => 'card',
    PaymentMethod.other => 'other',
  };

  String get label => switch (this) {
    PaymentMethod.cash => '現金',
    PaymentMethod.card => 'カード',
    PaymentMethod.other => 'その他',
  };
}

PaymentMethod? paymentMethodFromFirestore(String? raw) {
  switch (raw) {
    case 'cash':
      return PaymentMethod.cash;
    case 'card':
      return PaymentMethod.card;
    case 'other':
      return PaymentMethod.other;
    default:
      return null;
  }
}
