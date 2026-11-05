import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  // ── Form ─────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _passwordVisible = false;
  bool _confirmVisible = false;
  bool _isLoading = false;
  bool _agreedToTerms = false;

  // ── Password strength ─────────────────────────────────────────
  double _passwordStrength = 0;
  String _passwordStrengthLabel = '';
  Color _passwordStrengthColor = AppColors.textHint;

  // ── Entry animation ───────────────────────────────────────────
  late final AnimationController _entryController;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _formFade;
  late final Animation<Offset> _formSlide;
  late final Animation<double> _footerFade;

  // ── Button animation ──────────────────────────────────────────
  late final AnimationController _buttonController;
  late final Animation<double> _buttonScale;

  // ── Shimmer ───────────────────────────────────────────────────
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _passwordController.addListener(_updatePasswordStrength);
    _setupAnimations();
    _entryController.forward();
  }

  void _setupAnimations() {
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _headerFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
          ),
        );

    _formFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
          ),
        );

    _footerFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
      ),
    );

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _buttonScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _shimmer = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  // ── Password strength meter ───────────────────────────────────

  void _updatePasswordStrength() {
    final p = _passwordController.text;
    double strength = 0;
    if (p.length >= 6) strength += 0.25;
    if (p.length >= 10) strength += 0.15;
    if (RegExp(r'[A-Z]').hasMatch(p)) strength += 0.2;
    if (RegExp(r'[0-9]').hasMatch(p)) strength += 0.2;
    if (RegExp(r'[!@#\$&*~%^()_\-+=<>?]').hasMatch(p)) strength += 0.2;

    String label;
    Color color;
    if (strength <= 0) {
      label = '';
      color = AppColors.textHint;
    } else if (strength < 0.4) {
      label = 'Weak';
      color = AppColors.error;
    } else if (strength < 0.7) {
      label = 'Fair';
      color = const Color(0xFFFF9800);
    } else if (strength < 1.0) {
      label = 'Good';
      color = const Color(0xFF4CAF50);
    } else {
      label = 'Strong';
      color = AppColors.primaryLight;
    }

    setState(() {
      _passwordStrength = strength.clamp(0.0, 1.0);
      _passwordStrengthLabel = label;
      _passwordStrengthColor = color;
    });
  }

  // ── Validation ────────────────────────────────────────────────

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Full name is required';
    if (v.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final r = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
    if (!r.hasMatch(v.trim())) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    if (v != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  // ── Sign-up action ────────────────────────────────────────────

  Future<void> _onSignUpPressed() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please agree to the Terms & Privacy Policy'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    await _buttonController.forward();
    await _buttonController.reverse();

    setState(() => _isLoading = true);
    _shimmerController.repeat();

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      // Persist display name
      await credential.user?.updateDisplayName(_nameController.text.trim());

      if (!mounted) return;
      setState(() => _isLoading = false);
      _shimmerController.stop();
      _shimmerController.reset();

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeIn,
                ),
                child: child,
              ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _shimmerController.stop();
      _shimmerController.reset();

      final msg = switch (e.code) {
        'email-already-in-use' => 'An account already exists for this email.',
        'invalid-email' => 'The email address is not valid.',
        'weak-password' => 'Password is too weak. Use at least 6 characters.',
        'operation-not-allowed' => 'Email sign-up is not enabled.',
        _ => 'Sign up failed. Please try again.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _shimmerController.stop();
      _shimmerController.reset();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('An unexpected error occurred.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    _entryController.dispose();
    _buttonController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          _buildBackground(size),
          _buildDecorativeBlobs(size),
          SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 48),
                        _buildHeader(),
                        const SizedBox(height: 36),
                        _buildForm(),
                        const Spacer(),
                        _buildFooter(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Background ────────────────────────────────────────────────

  Widget _buildBackground(Size size) {
    return Container(
      width: size.width,
      height: size.height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.backgroundDark,
            AppColors.background,
            AppColors.backgroundLight,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
    );
  }

  Widget _buildDecorativeBlobs(Size size) {
    return Stack(
      children: [
        Positioned(
          top: -size.width * 0.25,
          left: -size.width * 0.2,
          child: _blob(
            size.width * 0.65,
            AppColors.primaryDark.withValues(alpha: 0.08),
          ),
        ),
        Positioned(
          bottom: -size.width * 0.15,
          right: -size.width * 0.15,
          child: _blob(
            size.width * 0.55,
            AppColors.primary.withValues(alpha: 0.06),
          ),
        ),
      ],
    );
  }

  Widget _blob(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  // ── Header ────────────────────────────────────────────────────

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _headerFade,
      child: SlideTransition(
        position: _headerSlide,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back + logo row
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textSecondary,
                      size: 16,
                    ),
                  ),
                ),
                const Spacer(),
                Image.asset(
                  'assets/images/logo.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.contain,
                ),
              ],
            ),

            const SizedBox(height: 32),

            const Text(
              'Create account',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Join VehicleVision and start detecting',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Form ──────────────────────────────────────────────────────

  Widget _buildForm() {
    return FadeTransition(
      opacity: _formFade,
      child: SlideTransition(
        position: _formSlide,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Full name
              _FormLabel(label: 'Full Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                focusNode: _nameFocus,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                style: _fieldTextStyle,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_emailFocus),
                validator: _validateName,
                decoration: _inputDecoration(
                  hintText: 'John Doe',
                  prefixIcon: Icons.person_outline_rounded,
                ),
              ),

              const SizedBox(height: 20),

              // Email
              _FormLabel(label: 'Email Address'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                style: _fieldTextStyle,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_passwordFocus),
                validator: _validateEmail,
                decoration: _inputDecoration(
                  hintText: 'you@example.com',
                  prefixIcon: Icons.email_outlined,
                ),
              ),

              const SizedBox(height: 20),

              // Password + strength meter
              _FormLabel(label: 'Password'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                obscureText: !_passwordVisible,
                textInputAction: TextInputAction.next,
                style: _fieldTextStyle,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_confirmFocus),
                validator: _validatePassword,
                decoration: _inputDecoration(
                  hintText: '••••••••',
                  prefixIcon: Icons.lock_outline_rounded,
                  suffixIcon: _visibilityButton(
                    visible: _passwordVisible,
                    onToggle: () =>
                        setState(() => _passwordVisible = !_passwordVisible),
                  ),
                ),
              ),

              // Strength meter
              if (_passwordStrength > 0) ...[
                const SizedBox(height: 10),
                _buildStrengthMeter(),
              ],

              const SizedBox(height: 20),

              // Confirm password
              _FormLabel(label: 'Confirm Password'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirmController,
                focusNode: _confirmFocus,
                obscureText: !_confirmVisible,
                textInputAction: TextInputAction.done,
                style: _fieldTextStyle,
                onFieldSubmitted: (_) => _onSignUpPressed(),
                validator: _validateConfirm,
                decoration: _inputDecoration(
                  hintText: '••••••••',
                  prefixIcon: Icons.lock_outline_rounded,
                  suffixIcon: _visibilityButton(
                    visible: _confirmVisible,
                    onToggle: () =>
                        setState(() => _confirmVisible = !_confirmVisible),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Terms checkbox
              GestureDetector(
                onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: _agreedToTerms
                            ? AppColors.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: _agreedToTerms
                              ? AppColors.primary
                              : AppColors.surfaceBorder,
                          width: 1.5,
                        ),
                      ),
                      child: _agreedToTerms
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 13,
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(text: 'I agree to the '),
                            TextSpan(
                              text: 'Terms of Service',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Sign Up button
              _buildSignUpButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStrengthMeter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 3,
            child: LinearProgressIndicator(
              value: _passwordStrength,
              backgroundColor: AppColors.surfaceBorder,
              valueColor: AlwaysStoppedAnimation(_passwordStrengthColor),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Text(
              'Password strength: ',
              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
            Text(
              _passwordStrengthLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _passwordStrengthColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignUpButton() {
    return AnimatedBuilder(
      animation: Listenable.merge([_buttonController, _shimmerController]),
      builder: (context, child) {
        return GestureDetector(
          onTapDown: (_) => _buttonController.forward(),
          onTapUp: (_) {
            _buttonController.reverse();
            _onSignUpPressed();
          },
          onTapCancel: () => _buttonController.reverse(),
          child: Transform.scale(
            scale: _buttonScale.value,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [
                    AppColors.primaryDark,
                    AppColors.primary,
                    AppColors.primaryLight,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isLoading)
                      Positioned.fill(
                        child: ShaderMask(
                          shaderCallback: (rect) => LinearGradient(
                            begin: Alignment(_shimmer.value - 1, 0),
                            end: Alignment(_shimmer.value + 1, 0),
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.25),
                              Colors.transparent,
                            ],
                          ).createShader(rect),
                          blendMode: BlendMode.srcATop,
                          child: Container(color: Colors.white),
                        ),
                      ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _isLoading
                          ? const SizedBox(
                              key: ValueKey('spinner'),
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Row(
                              key: ValueKey('label'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Footer ────────────────────────────────────────────────────

  Widget _buildFooter() {
    return FadeTransition(
      opacity: _footerFade,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Already have an account? ',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Text(
              'Sign In',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared helpers
// ═══════════════════════════════════════════════════════════════════════════

const TextStyle _fieldTextStyle = TextStyle(
  fontSize: 15,
  color: AppColors.textPrimary,
  fontWeight: FontWeight.w400,
);

Widget _visibilityButton({
  required bool visible,
  required VoidCallback onToggle,
}) {
  return IconButton(
    onPressed: onToggle,
    icon: AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Icon(
        visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        key: ValueKey(visible),
        color: AppColors.textHint,
        size: 20,
      ),
    ),
  );
}

class _FormLabel extends StatelessWidget {
  final String label;
  const _FormLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.4,
      ),
    );
  }
}

InputDecoration _inputDecoration({
  required String hintText,
  required IconData prefixIcon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
    prefixIcon: Icon(prefixIcon, color: AppColors.textHint, size: 20),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.surfaceBorder, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
    errorStyle: const TextStyle(
      color: AppColors.error,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
  );
}
