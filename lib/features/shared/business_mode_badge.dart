import 'package:flutter/material.dart';

import '../../core/business_mode.dart';

/// 通常営業・イベント営業ラベルの枠・文字色。
class BusinessModeBadgeColors {
  BusinessModeBadgeColors._();

  static const normal = Color(0xFF0F766E);
  static const event = Color(0xFFEA580C);

  /// 枠・背景は [billingMode]、イベント→通常は文字だけイベント色。
  static Color frameColor({
    required BusinessMode billingMode,
    required bool switchedFromEvent,
  }) {
    return billingMode == BusinessMode.normal ? normal : event;
  }

  static Color textColor({
    required BusinessMode billingMode,
    required bool switchedFromEvent,
  }) {
    if (switchedFromEvent && billingMode == BusinessMode.normal) {
      return event;
    }
    return frameColor(
      billingMode: billingMode,
      switchedFromEvent: switchedFromEvent,
    );
  }
}

/// 左上はみ出し等で使う営業モードラベル。
class BusinessModeBadge extends StatelessWidget {
  const BusinessModeBadge({
    super.key,
    required this.label,
    required this.billingMode,
    this.switchedFromEvent = false,
    this.style,
  });

  final String label;
  final BusinessMode billingMode;
  final bool switchedFromEvent;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final frame = BusinessModeBadgeColors.frameColor(
      billingMode: billingMode,
      switchedFromEvent: switchedFromEvent,
    );
    final text = BusinessModeBadgeColors.textColor(
      billingMode: billingMode,
      switchedFromEvent: switchedFromEvent,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          frame.withValues(alpha: 0.14),
          Theme.of(context).colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: frame.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            style ??
            Theme.of(context).textTheme.labelLarge?.copyWith(
              color: text,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
