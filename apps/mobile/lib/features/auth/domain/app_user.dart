/// الأدوار نفس enum user_role في قاعدة البيانات
enum UserRole {
  client('client', 'عميل'),
  driver('driver', 'سائق'),
  storeOwner('store_owner', 'صاحب متجر'),
  admin('admin', 'مدير');

  const UserRole(this.value, this.label);

  final String value;
  final String label;

  static UserRole parse(String? v) => UserRole.values.firstWhere((r) => r.value == v, orElse: () => UserRole.client);
}

class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    required this.fullName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.status = 'active',
  });

  final String id;
  final UserRole role;
  final String fullName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String status;

  bool get isActive => status == 'active';

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        role: UserRole.parse(j['role'] as String?),
        fullName: (j['full_name'] as String?) ?? '',
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        status: (j['status'] as String?) ?? 'active',
      );
}
