import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/booking_service.dart';

class TrialBookingScreen extends StatefulWidget {
  const TrialBookingScreen({super.key});

  @override
  State<TrialBookingScreen> createState() => _TrialBookingScreenState();
}

class _TrialBookingScreenState extends State<TrialBookingScreen> {
  final _subjectController = TextEditingController();
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    return Scaffold(
      appBar: AppBar(title: const Text('حجز حصة تجريبية')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: 'المادة'),
            ),
            const SizedBox(height: 12),
            ListTile(
              title: Text(_selectedDate == null
                  ? 'اختر الموعد'
                  : _selectedDate.toString()),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                  initialDate: DateTime.now(),
                );
                if (date != null) setState(() => _selectedDate = date);
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _selectedDate == null
                  ? null
                  : () async {
                      // Simple flow: tutor is matched and a Google Meet link
                      // is added manually afterward. Swap for the Calendar
                      // API call if you want the automated flow instead.
                      await context.read<BookingService>().bookSession(
                            studentId: auth.currentUser!.uid,
                            tutorId: 'TBD', // assign after matching
                            subject: _subjectController.text.trim(),
                            scheduledAt: _selectedDate!,
                            isTrial: true,
                          );
                      if (context.mounted) Navigator.of(context).pop();
                    },
              child: const Text('تأكيد الحجز'),
            ),
          ],
        ),
      ),
    );
  }
}
