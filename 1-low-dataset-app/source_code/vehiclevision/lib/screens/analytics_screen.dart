import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/detection_store.dart';
import '../theme/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  final _store = DetectionStore.instance;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
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
    _entryCtrl.forward();
    _store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _entryCtrl.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  // ── Derived data ─────────────────────────────────────────────

  static const _classConfig = [
    _ClassCfg('Car', Icons.directions_car_rounded, Color(0xFF4CAF50)),
    _ClassCfg('Bus', Icons.directions_bus_rounded, Color(0xFFFF9800)),
    _ClassCfg('Truck', Icons.local_shipping_rounded, Color(0xFFE91E63)),
    _ClassCfg('Motorcycle', Icons.two_wheeler_rounded, Color(0xFF9C27B0)),
  ];

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final total = _store.totalScans;
    final avgConf = _store.averageConfidence;
    final counts = _store.classCounts;
    final daily = _store.dailyStats(days: 7);
    final maxDay = daily.fold(0, (m, d) => d.count > m ? d.count : m);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildBackground(size),
          SafeArea(
            child: Column(
              children: [
                FadeTransition(
                  opacity: _headerFade,
                  child: SlideTransition(
                    position: _headerSlide,
                    child: _buildTopBar(),
                  ),
                ),
                Expanded(
                  child: FadeTransition(
                    opacity: _contentFade,
                    child: SlideTransition(
                      position: _contentSlide,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Summary banner
                            _buildSummaryBanner(total, avgConf),
                            const SizedBox(height: 22),

                            // Stat grid
                            _buildSectionLabel('DETECTION BREAKDOWN'),
                            const SizedBox(height: 12),
                            _buildStatsGrid(total, counts),
                            const SizedBox(height: 22),

                            // Class bar chart
                            if (total > 0) ...[
                              _buildSectionLabel('CLASS DISTRIBUTION'),
                              const SizedBox(height: 12),
                              _buildClassBars(total, counts),
                              const SizedBox(height: 22),
                            ],

                            // 7-day activity chart
                            _buildSectionLabel('7-DAY ACTIVITY'),
                            const SizedBox(height: 12),
                            _buildDailyChart(daily, maxDay),
                            const SizedBox(height: 22),

                            // Recent detections
                            if (_store.records.isNotEmpty) ...[
                              _buildSectionLabel('RECENT DETECTIONS'),
                              const SizedBox(height: 12),
                              _buildRecentList(),
                            ],
                            const SizedBox(height: 20),
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

  // ── Top bar ───────────────────────────────────────────────────

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
              'Analytics',
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

  // ── Summary banner ────────────────────────────────────────────

  Widget _buildSummaryBanner(int total, double avgConf) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.backgroundLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detection Analytics',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  total == 0
                      ? 'Run your first detection to see stats'
                      : '$total scan${total == 1 ? '' : 's'} · '
                            'avg ${(avgConf * 100).toStringAsFixed(1)}% confidence',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats grid ────────────────────────────────────────────────

  Widget _buildStatsGrid(int total, Map<String, int> counts) {
    final items = [
      _StatItem(
        'Total Scans',
        '$total',
        Icons.image_search_rounded,
        AppColors.primary,
      ),
      for (final c in _classConfig)
        _StatItem(c.label, '${counts[c.label] ?? 0}', c.icon, c.color),
      _StatItem(
        'Avg Confidence',
        total == 0
            ? '–'
            : '${(_store.averageConfidence * 100).toStringAsFixed(1)}%',
        Icons.percent_rounded,
        AppColors.primaryLight,
      ),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: items.map((s) => _StatCard(item: s)).toList(),
    );
  }

  // ── Class distribution bars ───────────────────────────────────

  Widget _buildClassBars(int total, Map<String, int> counts) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: _classConfig.map((c) {
          final n = counts[c.label] ?? 0;
          final pct = total > 0 ? n / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(c.icon, color: c.color, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          c.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$n  (${(pct * 100).toStringAsFixed(0)}%)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (ctx, bc) {
                    return Stack(
                      children: [
                        Container(
                          height: 6,
                          width: bc.maxWidth,
                          decoration: BoxDecoration(
                            color: c.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          height: 6,
                          width: bc.maxWidth * pct,
                          decoration: BoxDecoration(
                            color: c.color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── 7-day bar chart ───────────────────────────────────────────

  Widget _buildDailyChart(List<DayStat> daily, int maxDay) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Scans per day',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Last 7 days',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 90,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(daily.length, (i) {
                final d = daily[i];
                final ratio = maxDay > 0 ? d.count / maxDay : 0.0;
                final isToday = i == daily.length - 1;
                final barColor = isToday
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.45);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (d.count > 0)
                          Text(
                            '${d.count}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: barColor,
                            ),
                          ),
                        const SizedBox(height: 3),
                        AnimatedContainer(
                          duration: Duration(milliseconds: 600 + i * 60),
                          curve: Curves.easeOutCubic,
                          height: ratio == 0 ? 4 : (72 * ratio).clamp(4, 72),
                          decoration: BoxDecoration(
                            color: ratio == 0
                                ? AppColors.surfaceBorder
                                : barColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          days[d.day.weekday - 1],
                          style: TextStyle(
                            fontSize: 9,
                            color: isToday
                                ? AppColors.primary
                                : AppColors.textHint,
                            fontWeight: isToday
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── Recent detections list ────────────────────────────────────

  Widget _buildRecentList() {
    final recent = _store.records.take(5).toList();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recent.length,
        separatorBuilder: (ctx, i) =>
            Divider(height: 1, color: AppColors.surfaceBorder, indent: 64),
        itemBuilder: (ctx, i) {
          final r = recent[i];
          final cfg = _classConfig.firstWhere(
            (c) => c.label.toLowerCase() == r.vehicleClass.toLowerCase(),
            orElse: () => const _ClassCfg(
              'Unknown',
              Icons.directions_car_rounded,
              AppColors.primary,
            ),
          );
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cfg.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(cfg.icon, color: cfg.color, size: 20),
            ),
            title: Text(
              r.vehicleClass,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              _fmt(r.timestamp),
              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '${(r.confidence * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) => Text(
    label,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.primary,
      letterSpacing: 2.5,
    ),
  );

  Widget _buildBackground(Size size) => Stack(
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
    ],
  );

  String _fmt(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Data helpers ──────────────────────────────────────────────────────────────

class _ClassCfg {
  final String label;
  final IconData icon;
  final Color color;
  const _ClassCfg(this.label, this.icon, this.color);
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  const _StatCard({required this.item});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, color: item.color, size: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: item.color,
                ),
              ),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

