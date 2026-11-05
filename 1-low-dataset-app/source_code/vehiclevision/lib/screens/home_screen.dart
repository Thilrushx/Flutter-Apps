import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/detection_store.dart';
import '../theme/app_theme.dart';
import 'analytics_screen.dart';
import 'dashboard_screen.dart';
import 'gallery_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Home Screen  —  Feature Hub
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── nav helper ───────────────────────────────────────────────

  void _push(Widget screen) {
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) => SlideTransition(
        position: Tween<Offset>(
                begin: const Offset(1, 0), end: Offset.zero)
            .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.isNotEmpty == true
        ? user!.displayName!.split(' ').first
        : (user?.email?.split('@').first ?? 'there');
    final initials = name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
    final detections = DetectionStore.instance.totalScans;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background gradient + blobs
          _buildBg(MediaQuery.of(context).size),

          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ── App bar
                    SliverToBoxAdapter(child: _buildAppBar(initials, name, user?.email ?? '')),

                    // ── Stats row
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: _buildStatsRow(detections),
                      ),
                    ),

                    // ── Section label
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
                        child: Text('FEATURES',
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: AppColors.primary, letterSpacing: 2.5)),
                      ),
                    ),

                    // ── Feature grid
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      sliver: SliverGrid(
                        delegate: SliverChildListDelegate([
                          _FeatureCard(
                            icon: Icons.search_rounded,
                            label: 'Detect',
                            description: 'AI vehicle identification',
                            color: AppColors.primary,
                            onTap: () => _push(const DashboardScreen()),
                          ),
                          _FeatureCard(
                            icon: Icons.bar_chart_rounded,
                            label: 'Analytics',
                            description: 'Detection statistics',
                            color: const Color(0xFF4CAF50),
                            onTap: () => _push(const AnalyticsScreen()),
                          ),
                          _FeatureCard(
                            icon: Icons.photo_library_rounded,
                            label: 'Gallery',
                            description: 'Browse saved images',
                            color: const Color(0xFF9C27B0),
                            onTap: () => _push(const GalleryScreen()),
                          ),
                          _FeatureCard(
                            icon: Icons.history_rounded,
                            label: 'History',
                            description: 'Past detections',
                            color: const Color(0xFFFF9800),
                            onTap: () => _push(const HistoryScreen()),
                          ),
                          _FeatureCard(
                            icon: Icons.settings_rounded,
                            label: 'Settings',
                            description: 'Account & preferences',
                            color: AppColors.primaryLight,
                            onTap: () => _push(const SettingsScreen()),
                          ),
                          _FeatureCard(
                            icon: Icons.info_outline_rounded,
                            label: 'About',
                            description: 'App info & version',
                            color: const Color(0xFFE91E63),
                            onTap: () => _showAbout(),
                          ),
                        ]),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 1.05,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Background ────────────────────────────────────────────────

  Widget _buildBg(Size size) => Stack(children: [
    Container(
      width: size.width, height: size.height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [AppColors.backgroundLight, AppColors.background,
                   AppColors.backgroundDark],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    ),
    Positioned(top: -80, right: -60,
      child: Container(width: 260, height: 260,
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: AppColors.primary.withValues(alpha: 0.05)))),
    Positioned(bottom: -60, left: -40,
      child: Container(width: 200, height: 200,
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: AppColors.primaryLight.withValues(alpha: 0.04)))),
  ]);

  // ── App bar ───────────────────────────────────────────────────

  Widget _buildAppBar(String initials, String name, String email) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 14, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight.withValues(alpha: 0.9),
        border: Border(bottom: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.12), width: 1)),
      ),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Image.asset('assets/images/logo.png', width: 18, height: 18),
              const SizedBox(width: 6),
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ).createShader(b),
                child: const Text('VehicleVision', style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 0.5)),
              ),
            ]),
            const SizedBox(height: 2),
            Text('Welcome back, $name!', style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis),
          ],
        )),
        const SizedBox(width: 14),
        // User Logo / Avatar (moved to the right)
        GestureDetector(
          onTap: () => _push(const SettingsScreen()),
          child: Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Center(child: Text(initials, style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))),
          ),
        ),
      ]),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────

  Widget _buildStatsRow(int detections) {
    return Row(children: [
      Expanded(child: _StatPill(
        icon: Icons.radar_rounded, color: AppColors.primary,
        label: 'Detections', value: '$detections')),
      const SizedBox(width: 12),
      Expanded(child: _StatPill(
        icon: Icons.check_circle_rounded, color: AppColors.success,
        label: 'Model', value: 'Ready')),
      const SizedBox(width: 12),
      Expanded(child: _StatPill(
        icon: Icons.bolt_rounded, color: const Color(0xFFFF9800),
        label: 'AI', value: 'Active')),
    ]);
  }

  // ── About ─────────────────────────────────────────────────────

  void _showAbout() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/images/logo.png', width: 64, height: 64),
            const SizedBox(height: 16),
            const Text('VehicleVision', style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            const Text('Version 1.0.0', style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            const Text(
              'AI-powered vehicle classification using on-device TFLite inference.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('Close',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: Colors.white))),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Stat pill ─────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatPill({required this.icon, required this.color,
      required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
            color: color)),
        Text(label, style: const TextStyle(fontSize: 10,
            color: AppColors.textSecondary)),
      ]),
    );
  }
}

// ── Feature card ──────────────────────────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({required this.icon, required this.label,
      required this.description, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: color.withValues(alpha: 0.12),
        highlightColor: color.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.25)),
            boxShadow: [BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon box + green dot
              Stack(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 22)),
                Positioned(top: 0, right: 0,
                  child: Container(width: 8, height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success))),
              ]),
              // Label + description
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(description, style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
