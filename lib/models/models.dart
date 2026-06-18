class WorkerUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  String status;

  WorkerUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.role = 'Forest Worker',
    this.status = 'Active',
  });

  factory WorkerUser.fromFirestore(Map<String, dynamic> data, String id) {
    return WorkerUser(
      id: id,
      name: data['name'] ?? 'Không rõ',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'Forest Worker',
      status: data['status'] ?? 'Active',
    );
  }
}

class LogbookEntry {
  final String id;
  final DateTime date;
  final String activityType;
  final String description;
  final double latitude;
  final double longitude;
  final String location;
  final String project;
  final List<String> photos;
  bool synced;

  LogbookEntry({
    required this.id,
    required this.date,
    required this.activityType,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.location,
    required this.project,
    this.photos = const [],
    this.synced = false,
  });

  factory LogbookEntry.fromFirestore(Map<String, dynamic> data, String id) {
    return LogbookEntry(
      id: id,
      date: data['timestamp'] != null ? (data['timestamp'] as dynamic).toDate() : DateTime.now(),
      activityType: data['activity'] ?? 'Không rõ',
      description: data['description'] ?? '',
      latitude: data['location']?['lat']?.toDouble() ?? 0.0,
      longitude: data['location']?['lng']?.toDouble() ?? 0.0,
      location: '${data['location']?['lat']?.toStringAsFixed(4)}, ${data['location']?['lng']?.toStringAsFixed(4)}',
      project: data['project'] ?? 'Không rõ',
      photos: List<String>.from(data['photos'] ?? []),
      synced: data['synced'] ?? true,
    );
  }
}

class CheckInRecord {
  final String id;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String project;
  final String notes;

  CheckInRecord({
    required this.id,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.project,
    this.notes = '',
  });

  factory CheckInRecord.fromFirestore(Map<String, dynamic> data, String id) {
    return CheckInRecord(
      id: id,
      timestamp: data['timestamp'] != null ? (data['timestamp'] as dynamic).toDate() : DateTime.now(),
      latitude: data['latitude']?.toDouble() ?? 0.0,
      longitude: data['longitude']?.toDouble() ?? 0.0,
      project: data['project'] ?? 'Không rõ',
      notes: data['notes'] ?? '',
    );
  }
}

class ForestProject {
  final String id;
  final String name;
  final String province;
  final String status;
  final double areaHa;
  final String treeSpecies;

  ForestProject({
    required this.id,
    required this.name,
    required this.province,
    required this.status,
    required this.areaHa,
    required this.treeSpecies,
  });

  factory ForestProject.fromFirestore(Map<String, dynamic> data, String id) {
    return ForestProject(
      id: id,
      name: data['name'] ?? 'Không rõ',
      province: data['province'] ?? '',
      status: data['status'] ?? 'Active',
      areaHa: (data['areaHa'] ?? 0.0).toDouble(),
      treeSpecies: data['treeSpecies'] ?? '',
    );
  }
}

class TreeRecord {
  final String id;
  final String plotCode;
  final String species;
  final double dbhCm;
  final double heightM;
  final int quantity;
  final String project;
  final String createdBy;
  final DateTime timestamp;

  TreeRecord({
    required this.id,
    required this.plotCode,
    required this.species,
    required this.dbhCm,
    required this.heightM,
    required this.quantity,
    required this.project,
    this.createdBy = '',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory TreeRecord.fromFirestore(Map<String, dynamic> data, String id) {
    return TreeRecord(
      id: id,
      plotCode: data['plotCode'] ?? 'Không rõ',
      species: data['species'] ?? 'Không rõ',
      dbhCm: (data['dbhCm'] ?? 0.0).toDouble(),
      heightM: (data['heightM'] ?? 0.0).toDouble(),
      quantity: data['quantity'] ?? 0,
      project: data['project'] ?? 'Không rõ',
      createdBy: data['createdBy'] ?? '',
      timestamp: data['timestamp'] != null ? (data['timestamp'] as dynamic).toDate() : DateTime.now(),
    );
  }
}


