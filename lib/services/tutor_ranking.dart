import 'dart:math' as math;

import '../models/tutor_profile.dart';

/// Orders tutors from best to worst. Each signal is scaled to 0–1 and the
/// score is their weighted sum:
///
/// * **Rating (50%)**: a Bayesian average, i.e. the tutor's ratings plus
///   [priorWeight] imaginary ratings of [priorRating]. A single 5★ review
///   can't beat a tutor with 4.8★ from forty students, and a new tutor starts
///   near the middle instead of at zero.
/// * **Completed sessions (20%)**: log-scaled and capped at
///   [sessionsForFullCredit], so the first sessions count most and veterans
///   don't run away with it forever.
/// * **Reliability (15%)**: completed / (completed + cancelled), smoothed with
///   [reliabilityPrior] completed sessions so one early cancellation isn't
///   fatal.
/// * **Teaching experience (15%)**: years from the application, capped at
///   [yearsForFullCredit].
class TutorRanking {
  static const priorRating = 4.0;
  static const priorWeight = 5;
  static const sessionsForFullCredit = 100;
  static const reliabilityPrior = 5;
  static const yearsForFullCredit = 15;

  static const ratingWeight = 0.50;
  static const sessionsWeight = 0.20;
  static const reliabilityWeight = 0.15;
  static const experienceWeight = 0.15;

  static double bayesianRating(TutorProfile t) =>
      (priorRating * priorWeight + t.ratingSum) / (priorWeight + t.ratingCount);

  static double score(TutorProfile t) {
    final rating = (bayesianRating(t) - 1) / 4;
    final sessions = math.min(
        1.0,
        math.log(1 + t.completedSessions) / math.log(1 + sessionsForFullCredit));
    final reliability = (t.completedSessions + reliabilityPrior) /
        (t.completedSessions + t.cancelledSessions + reliabilityPrior);
    final experience = math.min(t.experienceYears, yearsForFullCredit) / yearsForFullCredit;
    return ratingWeight * rating +
        sessionsWeight * sessions +
        reliabilityWeight * reliability +
        experienceWeight * experience;
  }
}

/// [tutors] sorted best first. Ties go to the tutor with more ratings, then
/// more sessions, then by name so the order is stable.
List<TutorProfile> rankTutors(Iterable<TutorProfile> tutors) {
  final scored = [for (final t in tutors) (t, TutorRanking.score(t))];
  scored.sort((a, b) {
    final byScore = b.$2.compareTo(a.$2);
    if (byScore != 0) return byScore;
    final byRatings = b.$1.ratingCount.compareTo(a.$1.ratingCount);
    if (byRatings != 0) return byRatings;
    final bySessions = b.$1.completedSessions.compareTo(a.$1.completedSessions);
    if (bySessions != 0) return bySessions;
    return a.$1.name.compareTo(b.$1.name);
  });
  return [for (final (t, _) in scored) t];
}
