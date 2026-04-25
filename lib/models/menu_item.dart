class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.priceTaxIncluded,
    required this.isActive,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String category;
  final int priceTaxIncluded;
  final bool isActive;
  final int sortOrder;

  factory MenuItem.fromMap(String id, Map<String, dynamic> map) {
    return MenuItem(
      id: id,
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? 'その他',
      priceTaxIncluded: (map['priceTaxIncluded'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] as bool? ?? true,
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 9999,
    );
  }
}
