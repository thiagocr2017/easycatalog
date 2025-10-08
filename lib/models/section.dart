class Section {
  final int? id;
  final String name;

  Section({this.id, required this.name});

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
  };

  factory Section.fromMap(Map<String, dynamic> map) {
    return Section(
      id: map['id'] as int?,
      name: map['name'] as String,
    );
  }
}
