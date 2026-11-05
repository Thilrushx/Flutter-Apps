import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'login_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Settings Screen
// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  // ── Entry animation ─────────────────────────────────────────
  late final AnimationController _entryCtrl;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _setupAnimations();
    _entryCtrl.forward();
  }

  void _setupAnimations() {
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _headerFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryCtrl,
            curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
          ),
        );

    _contentFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOut),
      ),
    );
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entryCtrl,
            curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
          ),
        );
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────

  void _onResetPassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ResetPasswordSheet(),
    );
  }

  void _onNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notifications settings not implemented yet.')),
    );
  }

  void _onPrivacy() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Privacy settings not implemented yet.')),
    );
  }

  Future<void> _onLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => const _LogoutConfirmationDialog(),
    );

    if (confirmed == true && mounted) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeIn,
                ),
                child: child,
              ),
        ),
        (route) => false,
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildBackground(size),
          SafeArea(
            child: Column(
              children: [
                // ── Top bar
                FadeTransition(
                  opacity: _headerFade,
                  child: SlideTransition(
                    position: _headerSlide,
                    child: _buildTopBar(),
                  ),
                ),
                // ── Scrollable body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    physics: const BouncingScrollPhysics(),
                    child: FadeTransition(
                      opacity: _contentFade,
                      child: SlideTransition(
                        position: _contentSlide,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 24),
                            _buildProfileCard(),
                            const SizedBox(height: 28),
                            _buildSectionLabel('ACCOUNT'),
                            const SizedBox(height: 10),
                            _buildAccountSection(),
                            const SizedBox(height: 28),
                            _buildSectionLabel('SESSION'),
                            const SizedBox(height: 10),
                            _buildSessionSection(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Background ───────────────────────────────────────────────

  Widget _buildBackground(Size size) {
    return Stack(
      children: [
        Container(
          width: size.width,
          height: size.height,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.backgroundLight,
                AppColors.background,
                AppColors.backgroundDark,
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.06),
            ),
          ),
        ),
        Positioned(
          bottom: -60,
          left: -40,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryLight.withValues(alpha: 0.04),
            ),
          ),
        ),
      ],
    );
  }

  // ── Top bar ──────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textSecondary,
                size: 15,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Logo + title
          Image.asset(
            'assets/images/logo.png',
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 10),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
            ).createShader(b),
            child: const Text(
              'Settings',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile card ─────────────────────────────────────────────

  Widget _buildProfileCard() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.email?.split('@').first ?? 'User');
    final email = user?.email ?? '';
    final initials = displayName.length >= 2
        ? displayName.substring(0, 2).toUpperCase()
        : displayName.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Verified badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: AppColors.success,
                  size: 12,
                ),
                SizedBox(width: 4),
                Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section label ────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
        letterSpacing: 2.5,
      ),
    );
  }

  // ── Account section ──────────────────────────────────────────

  Widget _buildAccountSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          _SettingsTile(
            icon: Icons.lock_reset_rounded,
            iconColor: AppColors.primary,
            label: 'Reset Password',
            description: 'Change your account password',
            onTap: _onResetPassword,
            showDivider: true,
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            iconColor: const Color(0xFFFF9800),
            label: 'Notifications',
            description: 'Manage push alerts',
            onTap: _onNotifications,
            showDivider: true,
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            iconColor: AppColors.primaryLight,
            label: 'Privacy',
            description: 'Data usage and permissions',
            onTap: _onPrivacy,
            showDivider: false,
          ),
        ],
      ),
    );
  }

  // ── Session section ──────────────────────────────────────────

  Widget _buildSessionSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: _SettingsTile(
        icon: Icons.logout_rounded,
        iconColor: AppColors.error,
        label: 'Log Out',
        description: 'Sign out of your account',
        labelColor: AppColors.error,
        onTap: _onLogout,
        showDivider: false,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Settings Tile
// ═══════════════════════════════════════════════════════════════════════════

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String description;
  final Color? labelColor;
  final VoidCallback onTap;
  final bool showDivider;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.description,
    required this.onTap,
    required this.showDivider,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: iconColor.withValues(alpha: 0.08),
            highlightColor: iconColor.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  // Icon container
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  // Labels
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: labelColor ?? AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Chevron
                  Icon(
                    Icons.chevron_right_rounded,
                    color: iconColor.withValues(alpha: 0.6),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: 72,
            endIndent: 0,
            color: AppColors.surfaceBorder,
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Logout Confirmation Dialog
// ═══════════════════════════════════════════════════════════════════════════

class _LogoutConfirmationDialog extends StatelessWidget {
  const _LogoutConfirmationDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 28,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Log Out?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            // Body
            const Text(
              'You will be signed out of your account. You can sign back in at any time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 28),

            // Buttons
            Row(
              children: [
                // Cancel
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: const Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Confirm
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD32F2F), AppColors.error],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.error.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Reset Password Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════

class _ResetPasswordSheet extends StatefulWidget {
  const _ResetPasswordSheet();

  @override
  State<_ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends State<_ResetPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _currentVisible = false;
  bool _newVisible = false;
  bool _confirmVisible = false;
  bool _isLoading = false;
  bool _success = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _validateCurrent(String? v) {
    if (v == null || v.isEmpty) return 'Current password is required';
    if (v.length < 6) return 'Must be at least 6 characters';
    return null;
  }

  String? _validateNew(String? v) {
    if (v == null || v.isEmpty) return 'New password is required';
    if (v.length < 8) return 'Must be at least 8 characters';
    if (v == _currentCtrl.text) return 'Must differ from current password';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    if (v != _newCtrl.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      // Re-authenticate with current password then update
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentCtrl.text,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newCtrl.text);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _success = true;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final msg = switch (e.code) {
        'wrong-password' => 'Current password is incorrect.',
        'weak-password' => 'New password is too weak.',
        'requires-recent-login' =>
          'Please log out and log in again before changing your password.',
        _ => 'Could not update password. Try again.',
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: AppColors.surfaceBorder, width: 1),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _success ? _buildSuccessState() : _buildFormState(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormState() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('form'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Reset Password',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.only(left: 2),
            child: Text(
              'Choose a strong password with at least 8 characters.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Current password
          _SheetFieldLabel(label: 'Current Password'),
          const SizedBox(height: 8),
          _PasswordFormField(
            controller: _currentCtrl,
            hintText: '••••••••',
            visible: _currentVisible,
            onToggle: () => setState(() => _currentVisible = !_currentVisible),
            validator: _validateCurrent,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),

          // New password
          _SheetFieldLabel(label: 'New Password'),
          const SizedBox(height: 8),
          _PasswordFormField(
            controller: _newCtrl,
            hintText: 'Min. 8 characters',
            visible: _newVisible,
            onToggle: () => setState(() => _newVisible = !_newVisible),
            validator: _validateNew,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),

          // Confirm password
          _SheetFieldLabel(label: 'Confirm New Password'),
          const SizedBox(height: 8),
          _PasswordFormField(
            controller: _confirmCtrl,
            hintText: 'Repeat new password',
            visible: _confirmVisible,
            onToggle: () => setState(() => _confirmVisible = !_confirmVisible),
            validator: _validateConfirm,
            textInputAction: TextInputAction.done,
            onSubmit: _onSubmit,
          ),
          const SizedBox(height: 28),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text(
                      'Update Password',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Column(
      key: const ValueKey('success'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.success.withValues(alpha: 0.12),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.success,
            size: 34,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Password Updated',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your password has been changed successfully.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Done',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sheet helpers ─────────────────────────────────────────────────────────

class _SheetFieldLabel extends StatelessWidget {
  final String label;
  const _SheetFieldLabel({required this.label});

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

class _PasswordFormField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool visible;
  final VoidCallback onToggle;
  final FormFieldValidator<String> validator;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmit;

  const _PasswordFormField({
    required this.controller,
    required this.hintText,
    required this.visible,
    required this.onToggle,
    required this.validator,
    required this.textInputAction,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      textInputAction: textInputAction,
      style: const TextStyle(
        fontSize: 15,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w400,
      ),
      onFieldSubmitted: onSubmit != null ? (_) => onSubmit!() : null,
      validator: validator,
      decoration: _inputDecoration(
        hintText: hintText,
        prefixIcon: Icons.lock_outline_rounded,
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              visible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              key: ValueKey(visible),
              color: AppColors.textHint,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared input decoration (matches login_screen.dart) ───────────────────

InputDecoration _inputDecoration({
  required String hintText,
  required IconData prefixIcon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      fontSize: 14,
      color: AppColors.textHint,
      fontWeight: FontWeight.w400,
    ),
    prefixIcon: Icon(prefixIcon, color: AppColors.textHint, size: 20),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.backgroundLight,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.surfaceBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.surfaceBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
    errorStyle: const TextStyle(fontSize: 12, color: AppColors.error),
  );
}
