enum UserRole { student, tutor, parent, admin }

class AppUser {
  final String uid;
  final String name;
  final String email;
  final UserRole role;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.student,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'email': email, 'role': role.name};
  }
}
