import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/session_model.dart';

class SessionCard extends StatelessWidget {
  final TutoringSession session;

  const SessionCard({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(session.subject.isEmpty ? 'حصة' : session.subject),
        subtitle: Text(
          '${session.scheduledAt.toLocal()}'.split('.').first +
              (session.isTrial ? ' - تجريبية' : ''),
        ),
        trailing: session.googleMeetLink == null
            ? const Icon(Icons.hourglass_empty)
            : IconButton(
                icon: const Icon(Icons.video_call),
                tooltip: 'فتح Google Meet',
                onPressed: () =>
                    launchUrl(Uri.parse(session.googleMeetLink!)),
              ),
      ),
    );
  }
}
