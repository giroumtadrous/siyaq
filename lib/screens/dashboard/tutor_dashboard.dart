import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../widgets/session_card.dart';

class TutorDashboard extends StatelessWidget {
  const TutorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final uid = auth.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة المعلم'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.signOut(),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: context.read<BookingService>().sessionsForUser(uid, asTutor: true),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sessions = snapshot.data!;
          if (sessions.isEmpty) {
            return const Center(child: Text('لا توجد حصص مجدولة'));
          }
          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, i) => SessionCard(session: sessions[i]),
          );
        },
      ),
    );
  }
}
