enum ApplicationStatus { submitted, approved, rejected }

/// What a tutor fills in before an admin approves them. Stored in
/// `tutor_applications/{tutorUid}`.
class TutorApplication {
  final String tutorId;
  final String phone;
  final String qualification;
  final int experienceYears;
  final List<String> subjects;

  /// Stage ids: primary | prep | secondary.
  final List<String> stages;
  final String bio;
  final String availability;
  final ApplicationStatus status;
  final DateTime submittedAt;

  /// Why an admin rejected it (only when [status] is rejected).
  final String? reviewNote;
  final DateTime? reviewedAt;

  const TutorApplication({
    required this.tutorId,
    required this.phone,
    required this.qualification,
    required this.experienceYears,
    required this.subjects,
    required this.stages,
    required this.bio,
    required this.availability,
    required this.status,
    required this.submittedAt,
    this.reviewNote,
    this.reviewedAt,
  });

  factory TutorApplication.fromMap(String tutorId, Map<String, dynamic> map) {
    return TutorApplication(
      tutorId: tutorId,
      phone: map['phone'] ?? '',
      qualification: map['qualification'] ?? '',
      experienceYears: (map['experienceYears'] ?? 0) as int,
      subjects: List<String>.from(map['subjects'] ?? const []),
      stages: List<String>.from(map['stages'] ?? const []),
      bio: map['bio'] ?? '',
      availability: map['availability'] ?? '',
      status: ApplicationStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => ApplicationStatus.submitted,
      ),
      submittedAt: DateTime.tryParse(map['submittedAt'] ?? '') ?? DateTime.now(),
      reviewNote: map['reviewNote'],
      reviewedAt: DateTime.tryParse(map['reviewedAt'] ?? ''),
    );
  }
}

/// The editable part of an application, before it is submitted.
class ApplicationDraft {
  final String phone;
  final String qualification;
  final int experienceYears;
  final List<String> subjects;
  final List<String> stages;
  final String bio;
  final String availability;

  const ApplicationDraft({
    required this.phone,
    required this.qualification,
    required this.experienceYears,
    required this.subjects,
    required this.stages,
    required this.bio,
    required this.availability,
  });

  /// The exact shape the security rules accept for a (re)submission.
  Map<String, dynamic> toSubmissionMap(DateTime now) => {
        'phone': phone,
        'qualification': qualification,
        'experienceYears': experienceYears,
        'subjects': subjects,
        'stages': stages,
        'bio': bio,
        'availability': availability,
        'status': ApplicationStatus.submitted.name,
        'submittedAt': now.toIso8601String(),
      };
}
