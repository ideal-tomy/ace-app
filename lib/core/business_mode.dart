import 'package:flutter/foundation.dart';

enum BusinessMode { event, normal }

class BusinessModeState {
  BusinessModeState._();

  static final ValueNotifier<BusinessMode> notifier = ValueNotifier(BusinessMode.event);
}
