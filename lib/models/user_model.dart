enum UserRole { student, tutor, parent, admin }

class AppUser {
  final String uid;
  final String name;
  final String email;
  final UserRole role;

  /// Student uids linked to this account (only used for parents).
  final List<String> childIds;

  /// Tutors must be approved by an admin before they can use the app.
  /// Always true for other roles.
  final bool approved;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.childIds = const [],
    this.approved = true,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    final role = UserRole.values.firstWhere(
      (r) => r.name == map['role'],
      orElse: () => UserRole.student,
    );
    return AppUser(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: role,
      childIds: List<String>.from(map['childIds'] ?? const []),
      // A tutor profile without the flag counts as not yet approved.
      approved: map['approved'] ?? role != UserRole.tutor,
    );
  }

  AppUser withChildIds(List<String> ids) => AppUser(
        uid: uid,
        name: name,
        email: email,
        role: role,
        childIds: ids,
        approved: approved,
      );

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role.name,
      if (role == UserRole.parent) 'childIds': childIds,
      if (role == UserRole.tutor) 'approved': approved,
    };
  }
}
