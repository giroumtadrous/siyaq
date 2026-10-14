import 'tutor_application.dart';

/// A tutor's public listing in the directory students search. Stored in
/// `tutor_profiles/{tutorUid}`; created by an admin from the approved
/// application, counters moved by the rules-checked batches in
/// [BookingService] and [TutorDirectoryService].
class TutorProfile {
  final String tutorId;
  final String name;
  final List<String> subjects;

  /// Stage ids: primary | prep | secondary.
  final List<String> stages;
  final String qualification;
  final int experienceYears;
  final String bio;

  /// False while the tutor is suspended; only active tutors are listed.
  final bool active;
  final int ratingSum;
  final int ratingCount;
  final int completedSessions;

  /// Sessions the tutor cancelled after being assigned.
  final int cancelledSessions;

  const TutorProfile({
    required this.tutorId,
    required this.name,
    required this.subjects,
    required this.stages,
    required this.qualification,
    required this.experienceYears,
    required this.bio,
    this.active = true,
    this.ratingSum = 0,
    this.ratingCount = 0,
    this.completedSessions = 0,
    this.cancelledSessions = 0,
  });

  /// Average of all ratings (1–5), or null before the first one.
  double? get averageRating => ratingCount == 0 ? null : ratingSum / ratingCount;

  bool teaches({String? stageId, String? subject}) =>
      (stageId == null || stages.contains(stageId)) &&
      (subject == null || subjects.contains(subject));

  factory TutorProfile.fromMap(String tutorId, Map<String, dynamic> map) {
    int count(String key) => ((map[key] ?? 0) as num).toInt();
    return TutorProfile(
      tutorId: tutorId,
      name: map['name'] ?? '',
      subjects: List<String>.from(map['subjects'] ?? const []),
      stages: List<String>.from(map['stages'] ?? const []),
      qualification: map['qualification'] ?? '',
      experienceYears: count('experienceYears'),
      bio: map['bio'] ?? '',
      active: map['active'] ?? false,
      ratingSum: count('ratingSum'),
      ratingCount: count('ratingCount'),
      completedSessions: count('completedSessions'),
      cancelledSessions: count('cancelledSessions'),
    );
  }

  /// The exact document the rules accept when an admin lists a tutor.
  /// Sessions finished before the listing are carried over once.
  static Map<String, dynamic> newListing({
    required String name,
    required TutorApplication application,
    int completedSessions = 0,
    int cancelledSessions = 0,
  }) =>
      {
        'name': name,
        'subjects': application.subjects,
        'stages': application.stages,
        'qualification': application.qualification,
        'experienceYears': application.experienceYears,
        'bio': application.bio,
        'active': true,
        'ratingSum': 0,
        'ratingCount': 0,
        'completedSessions': completedSessions,
        'cancelledSessions': cancelledSessions,
        'lastSessionId': '',
        'lastReviewId': '',
      };
}
