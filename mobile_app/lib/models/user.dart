class User {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String role; // 'passenger', 'company', 'staff', 'ADMIN'
  final int? companyId;
  final String? companyName;
  final String? staffRole; // 'STATION_STAFF', 'TICKET_OFFICE', 'DRIVER', 'ASSISTANT'

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.role = 'passenger',
    this.companyId,
    this.companyName,
    this.staffRole,
  });

  bool get isCompany => role == 'company' || role == 'admin';
  bool get isStaff => role == 'staff';
  bool get isDriver => staffRole == 'DRIVER' || role == 'driver';
  bool get isAssistant => staffRole == 'ASSISTANT';
  bool get isStationStaff => staffRole == 'STATION_STAFF';
  bool get isDispatcher => staffRole == 'DISPATCHER' || isStationStaff;
  bool get isOperator => isCompany || isStaff || isDriver;

  // Chi tiết quyền hạn theo nghiệp vụ vận tải
  bool get canCreateTrip => isCompany || isDispatcher;
  bool get canManageFleet => isCompany;
  bool get canManageStaff => isCompany;
  bool get canManageRoutes => isCompany;
  bool get canViewRevenue => isCompany;
  bool get canDispatchRescue => isCompany || isDispatcher;
  bool get canManageCargo => isCompany || isStationStaff || isDriver || isAssistant;

  String get roleDisplayName {
    if (isCompany) return 'QUẢN TRỊ VIÊN NHÀ XE';
    if (isDriver) return 'TÀI XẾ';
    if (isAssistant) return 'PHỤ XE';
    if (isStationStaff) return 'ĐIỀU HÀNH BẾN';
    if (staffRole == 'TICKET_OFFICE') return 'NHÂN VIÊN VÉ';
    return staffRole ?? 'NHÂN VIÊN VẬN HÀNH';
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: (json['role'] ?? 'passenger').toString().toLowerCase(),
      companyId: json['company_id'] != null
          ? (json['company_id'] is int ? json['company_id'] : int.tryParse(json['company_id'].toString()))
          : null,
      companyName: json['company_name'],
      staffRole: json['staff_role']?.toString().toUpperCase(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'company_id': companyId,
      'company_name': companyName,
      'staff_role': staffRole,
    };
  }
}
