import 'package:flutter/material.dart';

import '../../core/admin_auth_service.dart';
import '../../data/repositories/check_repository.dart';
import '../../data/repositories/menu_repository.dart';
import 'order_flow_sheet.dart';
import 'order_flow_state.dart';

/// 注文フロー（対象者選択 → メニュー → 数量 → 確認）をポップアップで開く。
Future<OrderFlowResult?> openOrderFlow(
  BuildContext context, {
  Map<String, DraftOrderLine>? existingDraft,
}) {
  return showOrderFlowSheet(
    context,
    checkRepository: CheckRepository(),
    menuRepository: MenuRepository(),
    adminAuthService: AdminAuthService(),
    initialState: OrderFlowState(draftOrders: existingDraft),
  );
}

/// 注文確定後のスナックバー表示用。
void showOrderFlowResultSnackBar(
  BuildContext context,
  OrderFlowResult? result,
) {
  if (result == null || !result.submitted) return;
  final name = result.person?.displayName;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        name == null ? '注文を登録しました' : '$name さんの注文を登録しました',
      ),
    ),
  );
}
