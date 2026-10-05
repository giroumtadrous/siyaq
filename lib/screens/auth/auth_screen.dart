import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

/// Combined sign-in / sign-up screen. Sign-up lets the user pick a role.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.startOnSignUp = false});
  final bool startOnSignUp;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  late bool _signUp = widget.startOnSignUp;
  UserRole _role = UserRole.student;
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _setMode(bool signUp) => setState(() {
        _signUp = signUp;
        _error = null;
      });

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthService>();
    try {
      if (_signUp) {
        await auth.signUp(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          role: _role,
        );
      } else {
        await auth.signIn(_email.text.trim(), _password.text);
      }
      // AuthGate (the app home) swaps to the right dashboard once signed in.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _arabicError(e.code));
    } catch (_) {
      if (mounted) setState(() => _error = 'حدث خطأ غير متوقع، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'أدخل بريدك الإلكتروني أولاً لإرسال رابط الاستعادة');
      return;
    }
    try {
      await context.read<AuthService>().resetPassword(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال رابط استعادة كلمة المرور إلى بريدك')));
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _arabicError(e.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final form = _FormCard(
      child: Form(key: _formKey, child: _buildForm()),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: wide
          ? Row(children: [
              const Expanded(flex: 5, child: _BrandPanel()),
              Expanded(
                flex: 6,
                child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(40), child: form)),
              ),
            ])
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_forward_rounded)),
                  ),
                  const _MiniLogo(),
                  const SizedBox(height: 24),
                  form,
                ]),
              ),
            ),
    );
  }

  Widget _buildForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _ModeToggle(signUp: _signUp, onChanged: _setMode),
      const SizedBox(height: 28),
      Text(_signUp ? 'أنشئ حسابك في سياق' : 'مرحباً بعودتك 👋',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(
        _signUp
            ? 'اختر نوع حسابك ثم أكمل بياناتك للبدء.'
            : 'سجّل دخولك لمتابعة حصصك وتقاريرك.',
        style: const TextStyle(color: AppColors.muted, height: 1.6),
      ),
      const SizedBox(height: 24),
      AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: _signUp
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _RolePicker(
                  role: _role,
                  onChanged: (r) => setState(() => _role = r),
                ),
                if (_role == UserRole.tutor) const _TutorNote(),
                const SizedBox(height: 20),
                _field(
                  controller: _name,
                  label: _role == UserRole.parent ? 'اسم ولي الأمر' : 'الاسم الكامل',
                  icon: Icons.person_outline_rounded,
                  action: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.trim().length < 3) ? 'أدخل اسمك الكامل' : null,
                ),
                const SizedBox(height: 14),
              ])
            : const SizedBox(width: double.infinity),
      ),
      _field(
        controller: _email,
        label: 'البريد الإلكتروني',
        icon: Icons.mail_outline_rounded,
        keyboard: TextInputType.emailAddress,
        action: TextInputAction.next,
        validator: (v) {
          final t = v?.trim() ?? '';
          return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
              ? null
              : 'أدخل بريداً إلكترونياً صحيحاً';
        },
      ),
      const SizedBox(height: 14),
      _field(
        controller: _password,
        label: 'كلمة المرور',
        icon: Icons.lock_outline_rounded,
        obscure: _obscure,
        action: TextInputAction.done,
        onSubmit: (_) => _submit(),
        suffix: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        ),
        validator: (v) =>
            (v == null || v.length < 6) ? 'كلمة المرور 6 أحرف على الأقل' : null,
      ),
      if (!_signUp)
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
              onPressed: _forgotPassword, child: const Text('نسيت كلمة المرور؟')),
        ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(_error!,
                    style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13))),
          ]),
        ),
      ],
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _loading ? null : _submit,
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(_signUp ? 'إنشاء الحساب' : 'تسجيل الدخول'),
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_signUp ? 'لديك حساب بالفعل؟' : 'ليس لديك حساب؟',
            style: const TextStyle(color: AppColors.muted)),
        TextButton(
            onPressed: () => _setMode(!_signUp),
            child: Text(_signUp ? 'سجّل الدخول' : 'أنشئ حساباً')),
      ]),
    ]);
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboard,
    TextInputAction? action,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onSubmit,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboard,
      textInputAction: action,
      obscureText: obscure,
      onFieldSubmitted: onSubmit,
      autofillHints: obscure
          ? const [AutofillHints.password]
          : keyboard == TextInputType.emailAddress
              ? const [AutofillHints.email]
              : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.muted),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.indigo, 2),
        errorBorder: border(const Color(0xFFDC2626)),
        focusedErrorBorder: border(const Color(0xFFDC2626), 2),
      ),
    );
  }
}

String _arabicError(String code) {
  switch (code) {
    case 'invalid-email':
      return 'صيغة البريد الإلكتروني غير صحيحة';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    case 'email-already-in-use':
      return 'هذا البريد مسجّل بالفعل، جرّب تسجيل الدخول';
    case 'weak-password':
      return 'كلمة المرور ضعيفة، استخدم 6 أحرف على الأقل';
    case 'too-many-requests':
      return 'محاولات كثيرة، انتظر قليلاً ثم حاول مرة أخرى';
    case 'network-request-failed':
      return 'تعذّر الاتصال بالإنترنت';
    case 'user-disabled':
      return 'تم إيقاف هذا الحساب';
    default:
      return 'حدث خطأ، حاول مرة أخرى';
  }
}

// ───────────────────────── Pieces ─────────────────────────

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                  color: AppColors.indigo.withValues(alpha: 0.08),
                  blurRadius: 40,
                  offset: const Offset(0, 16))
            ],
          ),
          child: child,
        ),
      );
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.signUp, required this.onChanged});
  final bool signUp;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool value) {
      final selected = signUp == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: selected
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)]
                  : null,
            ),
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.indigo : AppColors.muted)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [tab('تسجيل الدخول', false), tab('حساب جديد', true)]),
    );
  }
}

class _RolePicker extends StatelessWidget {
  const _RolePicker({required this.role, required this.onChanged});
  final UserRole role;
  final ValueChanged<UserRole> onChanged;

  static const _roles = [
    (UserRole.student, 'طالب', Icons.school_rounded),
    (UserRole.parent, 'ولي أمر', Icons.family_restroom_rounded),
    (UserRole.tutor, 'معلم', Icons.cast_for_education_rounded),
  ];

  @override
  Widget build(BuildContext context) => Row(children: [
        for (final (i, r) in _roles.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              button: true,
              selected: role == r.$1,
              label: r.$2,
              child: GestureDetector(
                onTap: () => onChanged(r.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: role == r.$1 ? AppColors.brandGradient : null,
                    color: role == r.$1 ? null : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: role == r.$1 ? Colors.transparent : AppColors.border),
                  ),
                  child: Column(children: [
                    Icon(r.$3,
                        size: 28, color: role == r.$1 ? Colors.white : AppColors.indigo),
                    const SizedBox(height: 8),
                    Text(r.$2,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: role == r.$1 ? Colors.white : AppColors.ink)),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ]);
}

class _TutorNote extends StatelessWidget {
  const _TutorNote();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.indigo.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          Icon(Icons.verified_user_outlined, color: AppColors.indigo, size: 20),
          SizedBox(width: 8),
          Expanded(
              child: Text('حسابات المعلمين تخضع لمراجعة المؤهلات قبل التفعيل.',
                  style: TextStyle(fontSize: 13, color: AppColors.indigo))),
        ]),
      );
}

class _MiniLogo extends StatelessWidget {
  const _MiniLogo();

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(12)),
          child: const Text('س',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        const Text('سياق', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      ]);
}

/// Left/right brand panel shown beside the form on wide screens.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    const points = [
      (Icons.card_giftcard_rounded, 'حصة أولى تجريبية مجانية بدون التزام'),
      (Icons.verified_rounded, 'معلمون معتمدون ومفحوصون تربوياً'),
      (Icons.insights_rounded, 'تقرير واضح بعد كل حصة لمتابعة المستوى'),
    ];
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      padding: const EdgeInsets.all(56),
      child: Stack(children: [
        Positioned(
            bottom: -120,
            left: -120,
            child: CircleAvatar(
                radius: 200, backgroundColor: Colors.white.withValues(alpha: 0.07))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: const Text('س',
                    style: TextStyle(
                        color: AppColors.indigo, fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              const Text('سياق',
                  style: TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            ]),
          ),
          const Spacer(),
          const Text('تعليم خصوصي\nبثقة وبمتابعة حقيقية',
              style: TextStyle(
                  color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, height: 1.4)),
          const SizedBox(height: 32),
          for (final p in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(p.$1, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Text(p.$2,
                        style: const TextStyle(color: Colors.white, fontSize: 16))),
              ]),
            ),
          const Spacer(),
        ]),
      ]),
    );
  }
}
