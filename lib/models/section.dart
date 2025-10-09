class Section {
  final int? id;
  final String name;
  final int? sortOrder;

  Section({this.id, required this.name, this.sortOrder});

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'sortOrder': sortOrder,
  };

  factory Section.fromMap(Map<String, dynamic> map) {
    return Section(
      id: map['id'] as int?,
      name: map['name'] as String,
      sortOrder: map['sortOrder'] as int?,
    );
  }
}
