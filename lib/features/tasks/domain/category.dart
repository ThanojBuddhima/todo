class Category {
  final String id;
  final String name;
  final int colorValue;
  final int? iconCode;

  const Category({
    required this.id,
    required this.name,
    required this.colorValue,
    this.iconCode,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      colorValue: map['color_value'] as int? ?? 0,
      iconCode: map['icon_code'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color_value': colorValue,
      'icon_code': iconCode,
    };
  }
}
