enum BusinessMode { event, normal }

extension BusinessModeCodec on BusinessMode {
  String get firestoreValue => switch (this) {
    BusinessMode.event => 'event',
    BusinessMode.normal => 'normal',
  };

  String get label => switch (this) {
    BusinessMode.event => 'イベント営業',
    BusinessMode.normal => '通常営業',
  };

  String get description => switch (this) {
    BusinessMode.event => '注文制（時間料金なし）',
    BusinessMode.normal => '時間制（例外ドリンクのみ追加注文）',
  };
}

BusinessMode businessModeFromFirestore(String? raw) {
  switch (raw) {
    case 'normal':
      return BusinessMode.normal;
    case 'event':
    default:
      return BusinessMode.event;
  }
}
