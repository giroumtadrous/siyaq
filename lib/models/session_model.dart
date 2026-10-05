enum SessionStatus { pending, confirmed, completed, cancelled }

/// `tutorId` of a booking that no tutor has accepted yet.
const unassignedTutorId = 'TBD';

class TutoringSession {
  final String id;
  final String studentId;
  final String tutorId;
  final String subject;
  final DateTime scheduledAt;
  final bool isTrial;
  final SessionStatus status;
  final String? googleMeetLink;

  TutoringSession({
    required this.id,
    required this.studentId,
    required this.tutorId,
    required this.subject,
    required this.scheduledAt,
    required this.isTrial,
    required this.status,
    this.googleMeetLink,
  });

  factory TutoringSession.fromMap(String id, Map<String, dynamic> map) {
    return TutoringSession(
      id: id,
      studentId: map['studentId'] ?? '',
      tutorId: map['tutorId'] ?? '',
      subject: map['subject'] ?? '',
      scheduledAt: DateTime.parse(map['scheduledAt']),
      isTrial: map['isTrial'] ?? false,
      status: SessionStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => SessionStatus.pending,
      ),
      googleMeetLink: map['googleMeetLink'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'tutorId': tutorId,
      'subject': subject,
      'scheduledAt': scheduledAt.toIso8601String(),
      'isTrial': isTrial,
      'status': status.name,
      'googleMeetLink': googleMeetLink,
    };
  }
}
