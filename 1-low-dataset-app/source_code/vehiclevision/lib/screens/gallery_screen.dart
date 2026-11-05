import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/detection_store.dart';
import '../services/tflite_service.dart';
import '../theme/app_theme.dart';
import 'history_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  final List<_GalleryItem> _items = [];
  final ImagePicker _picker = ImagePicker();
  int _detectingIndex = -1;
  static const double _threshold = 0.60;

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
    // pre-init model so detection is fast when tapped
    TFLiteService.instance.initialise();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  // ── Pick images ───────────────────────────────────────────────

  Future<void> _pickImages() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 85);
      if (picked.isEmpty) return;
      setState(() {
        _items.insertAll(0, picked.map((f) => _GalleryItem(file: f)).toList());
      });
    } on PlatformException {
      _snack('Permission denied. Please allow gallery access.');
    } catch (_) {
      _snack('Could not open gallery.');
    }
  }

  // ── Detect single image ───────────────────────────────────────

  Future<void> _detectImage(int index) async {
    if (_detectingIndex != -1) return; // already running
    final item = _items[index];

    if (!TFLiteService.instance.isReady) {
      _snack(
        TFLiteService.instance.modelLoadError ??
            'The vehicle detection model is unavailable.',
      );
      return;
    }

    setState(() => _detectingIndex = index);

    try {
      final bytes = await File(item.file.path).readAsBytes();
      final result = await TFLiteService.instance.predict(bytes);

      final label = result.confidence >= _threshold
          ? result.predictedClass
          : 'Not Recognized';

      // persist
      if (result.confidence >= _threshold) {
        await DetectionStore.instance.add(
          DetectionRecord(
            vehicleClass: result.predictedClass,
            confidence: result.confidence,
            timestamp: DateTime.now(),
            inferenceTimeMs: result.inferenceTimeMs,
          ),
        );
        HistoryScreen.syncFromStore();
      }

      if (!mounted) return;
      setState(() {
        _items[index] = item.copyWith(
          label: label,
          confidence: result.confidence,
          inferenceMs: result.inferenceTimeMs,
        );
        _detectingIndex = -1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _detectingIndex = -1);
      _snack('Detection failed: $e');
    }
  }

  void _removeImage(int index) => setState(() => _items.removeAt(index));

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────

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
                      child: _items.isEmpty ? _buildEmptyState() : _buildGrid(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // FAB
          Positioned(
            bottom: 28,
            right: 24,
            child: FadeTransition(
              opacity: _contentFade,
              child: GestureDetector(
                onTap: _pickImages,
                child: Container(
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
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_photo_alternate_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
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
              'Gallery',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const Spacer(),
          if (_items.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                '${_items.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.photo_library_rounded,
                color: AppColors.primary,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No images yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap + to browse your gallery.\nTap any image to run AI detection.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Grid ──────────────────────────────────────────────────────

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: _items.length,
      itemBuilder: (ctx, i) => _buildGridCell(i),
    );
  }

  Widget _buildGridCell(int i) {
    final item = _items[i];
    final isDetecting = _detectingIndex == i;
    final hasResult = item.label != null;
    final conf = item.confidence ?? 0.0;
    final labelColor = conf >= 0.75
        ? AppColors.success
        : conf >= 0.5
        ? const Color(0xFFFF9800)
        : AppColors.error;

    return GestureDetector(
      onTap: isDetecting ? null : () => _detectImage(i),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasResult
                ? labelColor.withValues(alpha: 0.5)
                : AppColors.surfaceBorder,
            width: hasResult ? 1.5 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              Image.file(
                File(item.file.path),
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  color: AppColors.surface,
                  child: const Icon(
                    Icons.broken_image_rounded,
                    color: AppColors.textHint,
                    size: 32,
                  ),
                ),
              ),

              // Dark overlay when detecting
              if (isDetecting)
                Container(color: Colors.black.withValues(alpha: 0.55)),

              // Detecting spinner
              if (isDetecting)
                const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ),

              // Scan hint (no result yet)
              if (!isDetecting && !hasResult)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.75),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.radar_rounded,
                          color: AppColors.primary,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Tap to detect',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Result label
              if (!isDetecting && hasResult)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.label!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${(conf * 100).toStringAsFixed(1)}%'
                          '  ·  ${item.inferenceMs}ms',
                          style: TextStyle(fontSize: 10, color: labelColor),
                        ),
                      ],
                    ),
                  ),
                ),

              // Delete button
              if (!isDetecting)
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => _removeImage(i),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.55),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground(Size size) => Container(
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
  );
}

// ── Gallery item model ────────────────────────────────────────────────────────

class _GalleryItem {
  final XFile file;
  final String? label;
  final double? confidence;
  final int inferenceMs;

  const _GalleryItem({
    required this.file,
    this.label,
    this.confidence,
    this.inferenceMs = 0,
  });

  _GalleryItem copyWith({
    String? label,
    double? confidence,
    int? inferenceMs,
  }) => _GalleryItem(
    file: file,
    label: label ?? this.label,
    confidence: confidence ?? this.confidence,
    inferenceMs: inferenceMs ?? this.inferenceMs,
  );
}
