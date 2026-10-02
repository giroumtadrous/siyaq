import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../booking/trial_booking_screen.dart';
import '../../widgets/session_card.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final uid = auth.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الطالب'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TrialBookingScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('حجز حصة تجريبية'),
      ),
      body: StreamBuilder(
        stream: context.read<BookingService>().sessionsForUser(uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sessions = snapshot.data!;
          if (sessions.isEmpty) {
            return const Center(child: Text('لا توجد حصص محجوزة بعد'));
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
