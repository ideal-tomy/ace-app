import 'package:flutter/foundation.dart';

enum BusinessMode { event, normal }

class BusinessModeState {
  BusinessModeState._();

  static final ValueNotifier<BusinessMode> notifier = ValueNotifier(BusinessMode.event);
}

extension BusinessModeCodec on BusinessMode {
  String get firestoreValue => switch (this) {
        BusinessMode.event => 'event',
        BusinessMode.normal => 'normal',
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
