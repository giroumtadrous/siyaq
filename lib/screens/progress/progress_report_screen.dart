import 'package:flutter/material.dart';

/// TODO: pull progress entries from Firestore, e.g. collection
/// 'progress_reports' keyed by studentId, with fields like subject,
/// score, tutorNotes, date. Render as a list or simple chart.
class ProgressReportScreen extends StatelessWidget {
  final String studentId;

  const ProgressReportScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقرير التقدم')),
      body: const Center(child: Text('لا توجد تقارير بعد')),
    );
  }
}
