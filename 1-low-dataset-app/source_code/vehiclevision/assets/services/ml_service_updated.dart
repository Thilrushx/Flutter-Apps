import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';


// ── Preprocessing strategy ──────────────────────────────────────────────────
enum PreprocessingMode {
  /// pixel / 255.0  (default for EfficientNet / MobileNet models)
  normalizeDiv255,

  /// ResNet-50 BGR mean-subtraction (used by Low Dataset / Cats model)
  resnet50BgrMean,

  /// Raw uint8 — no normalisation
  uint8Raw,
}

// ── Model-specific config ────────────────────────────────────────────────────
class _ModelConfig {
  final PreprocessingMode mode;
  final bool xrayValidation;
  const _ModelConfig(this.mode, {this.xrayValidation = false});
}

/// Returns the preprocessing config for a given model asset path.
_ModelConfig _configForModel(String modelPath) {
  if (modelPath.contains('best_low_dataset_model')) {
    // Low Dataset vehicle classifier from low_dataset_model_development.ipynb:
    // MobileNetV2 trained with ImageDataGenerator(rescale=1./255).
    return const _ModelConfig(PreprocessingMode.normalizeDiv255);
  }
  if (modelPath.contains('best_low_detail_dataset_model')) {
    // Low Detail Dataset model uses ResNet50 BGR mean subtraction.
    return const _ModelConfig(PreprocessingMode.resnet50BgrMean);
  }
  if (modelPath.contains('best_vehicle_model')) {
    // Vehicle model: MobileNetV2, trained with rescale=1/255 (NOT ResNet BGR).
    return const _ModelConfig(PreprocessingMode.normalizeDiv255);
  }
  if (modelPath.contains('best_medical_model')) {
    // Medical / X-ray — normalise + xray gate
    return const _ModelConfig(
      PreprocessingMode.normalizeDiv255,
      xrayValidation: true,
    );
  }
  // ── All other models use plain /255 normalisation ──────────────────────
  // Covers: large, multiclass, grayscale, imbalanced, tiny_object
  return const _ModelConfig(PreprocessingMode.normalizeDiv255);
}

class MLService {
  Interpreter? _interpreter;
  List<String>? _labels;
  bool _isLoading = false;

  String modelPath;
  String labelsPath;
  int inputSize;
  double mean;
  double std;

  bool enableXrayValidation;

  /// Below this top-1 probability the result is flagged 'lowConfidence'.
  double minConfidence = 0.60;

  MLService({
    this.modelPath = 'assets/models/best_medical_model.tflite',
    this.labelsPath = 'assets/labels/medical_dataset_labels.txt',
    this.inputSize = 224,
    this.mean = 0.0,
    this.std = 255.0,
    this.enableXrayValidation = false,
  });

  bool get isReady => _interpreter != null && _labels != null && !_isLoading;

  // ── Public config update ─────────────────────────────────────────────────
  Future<void> updateConfig(
    String newModelPath,
    String newLabelsPath,
    double newMean,
    double newStd, {
    bool xrayValidation = false,
  }) async {
    if (modelPath == newModelPath &&
        labelsPath == newLabelsPath &&
        _interpreter != null &&
        !_isLoading &&
        mean == newMean &&
        std == newStd) {
      return;
    }
    if (_isLoading) return;

    final oldInterpreter = _interpreter;
    _interpreter = null;
    _labels = null;
    oldInterpreter?.close();

    modelPath = newModelPath;
    labelsPath = newLabelsPath;
    mean = newMean;
    std = newStd;

    // Derive xray flag from the model path (ignores caller value for safety)
    final cfg = _configForModel(newModelPath);
    enableXrayValidation = cfg.xrayValidation;

    await initialize();
  }

  Future<void> initialize() async {
    _isLoading = true;
    try {
      await _loadModel();
      await _loadLabels();
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        modelPath,
        options: InterpreterOptions(),
      );
      final inShape = _interpreter!.getInputTensor(0).shape;
      final outShape = _interpreter!.getOutputTensor(0).shape;
      print('Model loaded: $modelPath');
      print('   Input: $inShape  Output: $outShape');
    } catch (e) {
      print('Error loading model: $e');
      _interpreter = null;
    }
  }

  Future<void> _loadLabels() async {
    try {
      final raw = await rootBundle.loadString(labelsPath);
      _labels = raw
          .split(RegExp(r'\r?\n'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      print('Labels: $_labels');
    } catch (e) {
      print(' Error loading labels: $e');
      _labels = null;
    }
  }

  // ── X-ray validator ──────────────────────────────────────────────────────
  bool _isXrayImage(img.Image image) {
    double rg = 0, rb = 0, gb = 0;
    int count = 0;
    for (int y = 0; y < image.height; y += 4) {
      for (int x = 0; x < image.width; x += 4) {
        final p = image.getPixel(x, y);
        rg += (p.r.toDouble() - p.g.toDouble()).abs();
        rb += (p.r.toDouble() - p.b.toDouble()).abs();
        gb += (p.g.toDouble() - p.b.toDouble()).abs();
        count++;
      }
    }
    final avgDiff = (rg + rb + gb) / (3 * count);
    print('   X-ray channel diff: ${avgDiff.toStringAsFixed(2)} (threshold=20)');
    return avgDiff < 20.0;
  }

  // ── Inference ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> runInference(File imageFile) async {
    if (_interpreter == null || _labels == null) {
      print('Model not ready');
      return null;
    }

    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? imageInput = img.decodeImage(bytes);
      if (imageInput == null) {
        print(' Failed to decode image');
        return null;
      }

      // X-ray gate
      if (enableXrayValidation && !_isXrayImage(imageInput)) {
        print(' Image rejected: not an X-ray');
        return {
          'label': 'Not Recognized',
          'confidence': 0.0,
          'notXray': true,
          'allResults': [],
        };
      }

      final inputTensor = _interpreter!.getInputTensor(0);
      final inputShape = inputTensor.shape;
      final inputType = inputTensor.type;

      final modelH = inputShape.length > 1 ? inputShape[1] : inputSize;
      final modelW = inputShape.length > 2 ? inputShape[2] : modelH;
      final channels = inputShape.length > 3 ? inputShape[3] : 3;

      final resized = img.copyResize(
        imageInput,
        width: modelW,
        height: modelH,
        interpolation: img.Interpolation.linear,
      );

      // ── Select preprocessing based on model ────────────────────────────
      final Object inputData;
      if (inputType == TensorType.uint8) {
        inputData = _preprocessUint8(resized, modelH, modelW, channels);
      } else {
        final cfg = _configForModel(modelPath);
        switch (cfg.mode) {
          case PreprocessingMode.resnet50BgrMean:
            inputData = _preprocessResNet50BgrMean(resized, modelH, modelW);
            break;
          case PreprocessingMode.normalizeDiv255:
          case PreprocessingMode.uint8Raw:
          // ignore: unreachable_switch_default
          default:
            inputData = _preprocessNormalizeDiv255(
                resized, modelH, modelW, channels, mean, std);
        }
      }

      final outputTensor = _interpreter!.getOutputTensor(0);
      final outputShape = outputTensor.shape;
      final outputType = outputTensor.type;
      final Object outputBuffer = _makeBuffer(outputShape, outputType);

      _interpreter!.run(inputData, outputBuffer);

      final List<num> rawProbs = _flatten(outputBuffer);

      double sum = 0.0;
      for (final v in rawProbs) {
        sum += outputType == TensorType.uint8 ? v / 255.0 : v.toDouble();
      }

      List<double> probs;
      if (sum < 0.98 || sum > 1.02) {
        final vals = rawProbs
            .map((v) =>
                outputType == TensorType.uint8 ? v / 255.0 : v.toDouble())
            .toList();
        final maxVal = vals.reduce(math.max);
        final exps = vals.map((v) => math.exp(v - maxVal)).toList();
        final expSum = exps.reduce((a, b) => a + b);
        probs = exps.map((e) => e / expSum).toList();
      } else {
        probs = rawProbs
            .map((v) =>
                outputType == TensorType.uint8 ? v / 255.0 : v.toDouble())
            .toList();
      }

      int bestIdx = 0;
      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > probs[bestIdx]) bestIdx = i;
      }

      if (bestIdx < _labels!.length) {
        // The model has no "not a vehicle" class, so flag weak predictions.
        final lowConfidence = probs[bestIdx] < minConfidence;
        print(
            '${_labels![bestIdx]} (${(probs[bestIdx] * 100).toStringAsFixed(1)}%)');
        return {
          'label': _labels![bestIdx],
          'confidence': probs[bestIdx],
          'lowConfidence': lowConfidence,
          'allResults': List.generate(
            math.min(probs.length, _labels!.length),
            (i) => {'label': _labels![i], 'confidence': probs[i]},
          )..sort((a, b) =>
              (b['confidence'] as double).compareTo(a['confidence'] as double)),
        };
      }
      return null;
    } catch (e, stack) {
      print(' Inference error: $e\n$stack');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // PREPROCESSING FUNCTIONS
  // ════════════════════════════════════════════════════════════════════════

  /// Default: pixel / 255.0
  /// Used by: low_detail, large, multiclass, grayscale, imbalanced, tiny_object
  List<List<List<List<double>>>> _preprocessNormalizeDiv255(
      img.Image image, int h, int w, int channels, double mean, double std) {
    return List.generate(
      1,
      (_) => List.generate(
        h,
        (y) => List.generate(w, (x) {
          final p = image.getPixel(x, y);
          if (channels == 1) {
            final gray = p.r.toDouble() * 0.299 +
                p.g.toDouble() * 0.587 +
                p.b.toDouble() * 0.114;
            return [(gray - mean) / std];
          }
          return [
            (p.r.toDouble() - mean) / std,
            (p.g.toDouble() - mean) / std,
            (p.b.toDouble() - mean) / std,
          ];
        }),
      ),
    );
  }

  /// ResNet-50 BGR mean subtraction: subtract ImageNet channel means in BGR order.
  /// Used by: Low Dataset (Cats)
  List<List<List<List<double>>>> _preprocessResNet50BgrMean(
      img.Image image, int h, int w) {
    return List.generate(
      1,
      (_) => List.generate(
        h,
        (y) => List.generate(w, (x) {
          final p = image.getPixel(x, y);
          return [
            p.b.toDouble() - 103.939, // B
            p.g.toDouble() - 116.779, // G
            p.r.toDouble() - 123.68,  // R
          ];
        }),
      ),
    );
  }

  /// uint8 passthrough — no normalisation.
  List<List<List<List<int>>>> _preprocessUint8(
      img.Image image, int h, int w, int channels) {
    return List.generate(
      1,
      (_) => List.generate(
        h,
        (y) => List.generate(w, (x) {
          final p = image.getPixel(x, y);
          if (channels == 1) {
            final gray = (p.r.toDouble() * 0.299 +
                    p.g.toDouble() * 0.587 +
                    p.b.toDouble() * 0.114)
                .round()
                .clamp(0, 255);
            return [gray];
          }
          return [
            p.r.toInt().clamp(0, 255),
            p.g.toInt().clamp(0, 255),
            p.b.toInt().clamp(0, 255),
          ];
        }),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  Object _makeBuffer(List<int> shape, TensorType type) {
    if (shape.isEmpty) return type == TensorType.uint8 ? 0 : 0.0;
    if (shape.length == 1) {
      return type == TensorType.uint8
          ? List.filled(shape[0], 0)
          : List.filled(shape[0], 0.0);
    }
    return List.generate(shape[0], (_) => _makeBuffer(shape.sublist(1), type));
  }

  List<num> _flatten(Object obj) {
    if (obj is List) return obj.expand((e) => _flatten(e)).toList();
    return [obj as num];
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _labels = null;
  }
}
