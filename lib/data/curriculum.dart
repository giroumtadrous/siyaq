import 'package:flutter/material.dart';

/// Placeholder: replace with the platform's real WhatsApp number (international format, no +).
const whatsappNumber = '201000000000';

class Subject {
  const Subject(this.name, this.description, this.icon);
  final String name;
  final String description;
  final IconData icon;
}

class Grade {
  const Grade(this.name, this.description, this.subjects);
  final String name;
  final String description;
  final List<Subject> subjects;
}

class Stage {
  const Stage(this.id, this.name, this.icon, this.grades);

  /// Stable key stored in Firestore (primary | prep | secondary).
  final String id;
  final String name;
  final IconData icon;
  final List<Grade> grades;
}

const _quran = Subject('القرآن الكريم',
    'حفظ متقن بالتلقين وتثبيت ومراجعة بالسند', Icons.menu_book_rounded);
const _tajweed = Subject('التجويد وأحكام التلاوة',
    'مخارج الحروف وأحكام النون والمدود عملياً', Icons.record_voice_over_rounded);
const _arabic = Subject('اللغة العربية',
    'النحو، الإعراب، البلاغة، النصوص وتأسيس الإملاء', Icons.translate_rounded);
const _math = Subject('الرياضيات',
    'الجبر، الهندسة، الحساب الذهني وتدريبات الامتحانات', Icons.calculate_rounded);
const _english = Subject('اللغة الإنجليزية',
    'القواعد، المفردات، الاستيعاب وتنمية المحادثة', Icons.language_rounded);
const _science = Subject('العلوم',
    'شرح مبسط للمفاهيم مع تجارب وتطبيقات عملية', Icons.science_rounded);

const _core = [_quran, _tajweed, _arabic, _math, _english];

const stages = [
  Stage('primary', 'المرحلة الابتدائية', Icons.child_care_rounded, [
    Grade('الصف الأول الابتدائي', 'تأسيس القراءة والكتابة والحساب',
        [_quran, _tajweed, _arabic, _math]),
    Grade('الصف الثاني الابتدائي', 'تثبيت المهارات الأساسية وبناء الثقة',
        [_quran, _tajweed, _arabic, _math, _english]),
    Grade('الصف الثالث الابتدائي', 'الانتقال إلى القراءة الحرة والمسائل',
        [_quran, _tajweed, _arabic, _math, _english]),
    Grade('الصف الرابع الابتدائي', 'تعميق الفهم وحل المشكلات',
        [_quran, _arabic, _math, _english, _science]),
    Grade('الصف الخامس الابتدائي', 'استعداد للمرحلة الأعلى بخطوات ثابتة',
        [_quran, _arabic, _math, _english, _science]),
    Grade('الصف السادس الابتدائي', 'مراجعة شاملة ونماذج امتحانات',
        [_quran, _arabic, _math, _english, _science]),
  ]),
  Stage('prep', 'المرحلة الإعدادية', Icons.auto_stories_rounded, [
    Grade('الصف الأول الإعدادي', 'تأسيس النحو والتحليل ومبادئ الجبر والهندسة', _core),
    Grade('الصف الثاني الإعدادي',
        'تطوير التحصيل وحل التدريبات ونماذج الامتحانات المعمقة', _core),
    Grade('الصف الثالث الإعدادي (الشهادة)',
        'استعداد مكثف للشهادة الإعدادية وتدريب على نماذج الامتحانات', _core),
  ]),
  Stage('secondary', 'المرحلة الثانوية', Icons.school_rounded, [
    Grade('الصف الأول الثانوي', 'بناء قاعدة قوية للثانوية العامة',
        [_arabic, _math, _english, _science]),
    Grade('الصف الثاني الثانوي', 'التعمق في المقررات وحل المسائل',
        [_arabic, _math, _english, _science]),
    Grade('الصف الثالث الثانوي', 'تدريب مكثف على نماذج الثانوية العامة',
        [_arabic, _math, _english, _science]),
  ]),
];

/// Every distinct subject across all stages. The names are also listed in
/// firestore.rules (tutor applications), so keep both in sync.
List<Subject> allSubjects() {
  final seen = <String>{};
  return [
    for (final stage in stages)
      for (final grade in stage.grades)
        for (final s in grade.subjects)
          if (seen.add(s.name)) s,
  ];
}
