import 'package:flutter/material.dart';

/// TODO: upload and list files via Firebase Storage, path like
/// 'portfolios/{studentId}/{fileName}', store metadata in Firestore.
class PortfolioScreen extends StatelessWidget {
  final String studentId;

  const PortfolioScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المحفظة الأكاديمية')),
      body: const Center(child: Text('لا توجد ملفات بعد')),
    );
  }
}
