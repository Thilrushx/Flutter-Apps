import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_litert/flutter_litert.dart';

import '../models/prediction_result.dart';

/// How pixels are scaled before being fed to a FLOAT model.
/// Must match the preprocessing used during training.
enum Normalization {
  /// pixel / 255            -> [0, 1]   (Rescaling(1/255), most custom CNNs)
  zeroToOne,

  /// pixel / 127.5 - 1      -> [-1, 1]  (MobileNetV2 / InceptionV3 preprocess_input)
  minusOneToOne,

  /// raw 0..255             (EfficientNet in Keras, preprocessing is in-model)
  raw255,
}

/// Singleton TFLite inference service.
/// Call [initialise] once before using [predict].
class TFLiteService {
  TFLiteService._();
  static final TFLiteService instance = TFLiteService._();

  // ── Config ───────────────────────────────────────────────────
  // Match the files in assets/models/ (declare the folder in pubspec.yaml).
  static const String _modelAsset =
      'assets/models/1_best_low_dataset_model.tflite';
  static const String _labelsAsset = 'assets/models/labels.txt';

  /// CHANGE THIS to match your training pipeline.
  static const Normalization normalization = Normalization.zeroToOne;

  // ── State ────────────────────────────────────────────────────
  Interpreter? _interpreter;
  List<String> _labels = [];
  int _inputH = 224;
  int _inputW = 224;
  bool _inputIsFloat = true;
  bool _isInitialised = false;
  bool _modelMissing = false;
  bool _timedOut = false;
  String? _modelLoadError;

  bool get isReady => _isInitialised && !_modelMissing;
  bool get isModelMissing => _modelMissing;
  bool get isInitialised => _isInitialised;
  bool get isPlatformSupported => !kIsWeb;
  String? get modelLoadError => _modelLoadError;
  List<String> get labels => List.unmodifiable(_labels);

  // ── Init ─────────────────────────────────────────────────────

  Future<void> initialise() async {
    if (_isInitialised) return;

    if (kIsWeb) {
      // Real inference is not available in the browser. No fake results.
      _modelMissing = true;
      _modelLoadError =
          'On-device inference is not supported on web. '
          'Run the app on Android, iOS, or desktop.';
      _isInitialised = true;
      return;
    }

    await _loadLabels();

    try {
      await _loadModel().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _timedOut = true;
          _modelMissing = true;
          _modelLoadError = 'Model load timed out.';
        },
      );
    } catch (e) {
      _modelMissing = true;
      _modelLoadError = e.toString();
    }
    _isInitialised = true;
  }

  Future<void> _loadLabels() async {
    try {
      final raw = await rootBundle.loadString(_labelsAsset);
      _labels = raw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Could not load $_labelsAsset: $e');
      _labels = [];
    }
  }

  Future<void> _loadModel() async {
    Interpreter? interp;
    try {
      final byteData = await rootBundle.load(_modelAsset);
      final bytes = byteData.buffer.asUint8List();

      interp = await Interpreter.fromBytes(
        bytes,
        options: InterpreterOptions()..threads = 2,
      );

      if (_timedOut) {
        interp.close();
        return;
      }

      final inTensor = interp.getInputTensor(0);
      final inShape = inTensor.shape; // [1, H, W, 3]
      final outShape = interp.getOutputTensor(0).shape; // [1, numClasses]

      if (inShape.length != 4 || inShape[3] != 3) {
        _fail(interp, 'Unexpected input shape $inShape. Expected [1,H,W,3].');
        return;
      }
      if (outShape.length != 2) {
        _fail(interp, 'Unexpected output shape $outShape. Expected [1,N].');
        return;
      }

      final numClasses = outShape[1];

      if (_labels.isEmpty) {
        // Labels missing: generic names so the real model still runs.
        _labels = List<String>.generate(numClasses, (i) => 'Class $i');
      } else if (_labels.length != numClasses) {
        _fail(
          interp,
          'Label count (${_labels.length}) does not match model output '
          '($numClasses classes). Check labels.txt.',
        );
        return;
      }

      _inputIsFloat = inTensor.type.toString().toLowerCase().contains('float');
      _inputH = inShape[1];
      _inputW = inShape[2];
      _interpreter = interp;
      _modelMissing = false;
      _modelLoadError = null;
      debugPrint(
        'TFLite ready: input $inShape (${inTensor.type}), '
        'classes=$numClasses, labels=$_labels',
      );
    } on Exception catch (e) {
      interp?.close();
      _modelMissing = true;
      _modelLoadError = e.toString();
    }
  }

  void _fail(Interpreter interp, String reason) {
    interp.close();
    _modelMissing = true;
    _modelLoadError = reason;
  }

  // ── Inference ────────────────────────────────────────────────

  Future<PredictionResult> predict(Uint8List imageBytes) async {
    if (!_isInitialised) await initialise();

    if (_modelMissing || _interpreter == null) {
      throw StateError(_modelLoadError ?? 'Model unavailable.');
    }

    final sw = Stopwatch()..start();

    // 1. Decode, fix EXIF rotation, resize.
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) throw ArgumentError('Cannot decode image.');
    final original = img.bakeOrientation(decoded);
    final resized = img.copyResize(
      original,
      width: _inputW,
      height: _inputH,
      interpolation: img.Interpolation.linear,
    );

    // 2. Build nested input [1][H][W][3] in the model's expected type.
    final Object input = _inputIsFloat
        ? [
            List.generate(
              _inputH,
              (y) => List.generate(_inputW, (x) {
                final p = resized.getPixel(x, y);
                return [
                  _norm(p.r.toDouble()),
                  _norm(p.g.toDouble()),
                  _norm(p.b.toDouble()),
                ];
              }),
            ),
          ]
        : [
            List.generate(
              _inputH,
              (y) => List.generate(_inputW, (x) {
                final p = resized.getPixel(x, y);
                return [p.r.toInt(), p.g.toInt(), p.b.toInt()];
              }),
            ),
          ];

    // 3. Run inference into a REAL output buffer (not a reshaped copy).
    final numClasses = _labels.length;
    final output = [List<double>.filled(numClasses, 0.0)];
    _interpreter!.run(input, output);
    sw.stop();

    // 4. Convert to probabilities if the model returned logits.
    var probs = List<double>.from(output[0]);
    final sum = probs.fold<double>(0, (a, b) => a + b);
    final looksLikeProbs =
        probs.every((v) => v >= 0 && v <= 1) && (sum - 1.0).abs() < 0.05;
    if (!looksLikeProbs) probs = _softmax(probs);

    final scores = <ClassScore>[
      for (int i = 0; i < numClasses; i++)
        ClassScore(label: _labels[i], score: probs[i].clamp(0.0, 1.0)),
    ]..sort();

    return PredictionResult(
      predictedClass: scores.first.label,
      confidence: scores.first.score,
      allScores: scores,
      inferenceTimeMs: sw.elapsedMilliseconds,
    );
  }

  double _norm(double v) {
    switch (normalization) {
      case Normalization.zeroToOne:
        return v / 255.0;
      case Normalization.minusOneToOne:
        return v / 127.5 - 1.0;
      case Normalization.raw255:
        return v;
    }
  }

  List<double> _softmax(List<double> x) {
    final m = x.reduce(math.max);
    final e = x.map((v) => math.exp(v - m)).toList();
    final s = e.fold<double>(0, (a, b) => a + b);
    return e.map((v) => v / s).toList();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialised = false;
    _timedOut = false;
  }
}
