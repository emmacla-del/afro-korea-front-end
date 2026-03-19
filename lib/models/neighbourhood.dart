class Region {
  final String id;
  final String name;

  Region({required this.id, required this.name});

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(id: json['id'] as String, name: json['name'] as String);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Region && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Division {
  final String id;
  final String name;
  final Region region;

  Division({required this.id, required this.name, required this.region});

  factory Division.fromJson(Map<String, dynamic> json) {
    return Division(
      id: json['id'] as String,
      name: json['name'] as String,
      region: Region.fromJson(json['region']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Division && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Neighbourhood {
  final String id;
  final String name;
  final Division division;

  Neighbourhood({required this.id, required this.name, required this.division});

  factory Neighbourhood.fromJson(Map<String, dynamic> json) {
    return Neighbourhood(
      id: json['id'] as String,
      name: json['name'] as String,
      division: Division.fromJson(json['division']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Neighbourhood &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
