class StoreUserPermissions {
  const StoreUserPermissions({
    required this.uid,
    this.email,
    required this.moduleRoles,
  });

  final String uid;
  final String? email;
  final List<String> moduleRoles;

  static StoreUserPermissions fromMap(String uid, Map<String, dynamic> map) {
    final raw = map['moduleRoles'];
    final roles = <String>[];
    if (raw is Iterable) {
      for (final item in raw) {
        if (item is String && item.trim().isNotEmpty) {
          roles.add(item.trim());
        }
      }
    } else if (raw is String && raw.trim().isNotEmpty) {
      roles.add(raw.trim());
    }
    final emailRaw = map['email'] as String?;
    return StoreUserPermissions(
      uid: uid,
      email: emailRaw != null && emailRaw.trim().isEmpty
          ? null
          : emailRaw?.trim(),
      moduleRoles: roles,
    );
  }

  String summaryLabel() {
    if (moduleRoles.isEmpty) return '（権限なし）';
    if (moduleRoles.contains('both')) return '両方';
    final hasAcc = moduleRoles.contains('accounting');
    final hasExp = moduleRoles.contains('expense');
    if (hasAcc && hasExp) return '会計・経費';
    if (hasAcc) return '会計のみ';
    if (hasExp) return '経費のみ';
    return moduleRoles.join(', ');
  }
}
