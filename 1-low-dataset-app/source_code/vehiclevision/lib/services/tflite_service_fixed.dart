import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_litert/flutter_litert.dart';

import '../models/prediction_result.dart';

/// Runs vehicle image classification with the bundled TensorFlow Lite model.
///
/// Expected model input:  [1, height, width, 3] RGB float values in [0, 1].
/// Expected model output: [1, numberOfClasses].
///
/// IMPORTANT:
/// The image preprocessing here must match the preprocessing used when the
/// model was trained. This implementation uses RGB / 255.0, matching the
/// preprocessing in the supplied service implementation.
class TFLiteService {
  TFLiteService._();

  static final TFLiteService instance = TFLiteService._();

  // Keep these paths in sync with the assets section of pubspec.yaml.
  static const String _modelAsset =
      'assets/models/best_low_dataset_model.tflite';
  static const String _labelsAsset = 'assets/models/labels.txt';

  Interpreter? _interpreter;
  List<String> _labels = <String>[];

  int _inputHeight = 128;
  int _inputWidth = 128;
  int _numClasses = 0;

  bool _isInitialised = false;
  bool _modelMissing = false;
  String? _modelLoadError;
  Future<void>? _initialisationFuture;

  bool get isReady => _isInitialised && !_modelMissing && _interpreter != null;
  bool get isModelMissing => _modelMissing;
  bool get isInitialised => _isInitialised;
  bool get isPlatformSupported => !kIsWeb;
  String? get modelLoadError => _modelLoadError;
  List<String> get labels => List<String>.unmodifiable(_labels);

  /// Loads labels and the TFLite model. Safe to call more than once.
  Future<void> initialise() {
    if (_isInitialised) return Future<void>.value();
    return _initialisationFuture ??= _initialiseInternal();
  }

  Future<void> _initialiseInternal() async {
    _modelMissing = false;
    _modelLoadError = null;

    if (kIsWeb) {
      _setLoadFailure(
        'TensorFlow Lite inference is not enabled for Flutter Web in this '
        'service. Run the application on Android or iOS.',
      );
      _isInitialised = true;
      return;
    }

    try {
      await _loadLabels();
      await _loadModel().timeout(const Duration(seconds: 30));
    } on TimeoutException {
      _setLoadFailure(
        'Loading the TensorFlow Lite model timed out after 30 seconds.',
      );
    } catch (error) {
      _setLoadFailure('Unable to initialise the vehicle model: $error');
    } finally {
      _isInitialised = true;
      _initialisationFuture = null;
    }
  }

  Future<void> _loadLabels() async {
    try {
      final raw = await rootBundle.loadString(_labelsAsset);
      _labels = raw
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);

      if (_labels.isEmpty) {
        throw const FormatException('The labels file is empty.');
      }
    } catch (error) {
      throw StateError('Could not load labels from $_labelsAsset: $error');
    }
  }

  Future<void> _loadModel() async {
    Interpreter? candidate;

    try {
      final data = await rootBundle.load(_modelAsset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      candidate = await Interpreter.fromBytes(
        bytes,
        options: InterpreterOptions()..threads = 2,
      );

      final inputTensor = candidate.getInputTensor(0);
      final outputTensor = candidate.getOutputTensor(0);
      final inputShape = inputTensor.shape;
      final outputShape = outputTensor.shape;

      if (inputShape.length != 4 ||
          inputShape[0] != 1 ||
          inputShape[3] != 3 ||
          inputShape[1] <= 0 ||
          inputShape[2] <= 0) {
        throw StateError(
          'Unsupported model input shape $inputShape. '
          'Expected [1, height, width, 3].',
        );
      }

      if (outputShape.length != 2 ||
          outputShape[0] != 1 ||
          outputShape[1] <= 0) {
        throw StateError(
          'Unsupported model output shape $outputShape. '
          'Expected [1, numberOfClasses].',
        );
      }

      final outputClasses = outputShape[1];
      if (_labels.length != outputClasses) {
        throw StateError(
          'The model returns $outputClasses classes, but '
          '${_labels.length} labels were found in $_labelsAsset. '
          'Make sure the label order and count match the training model.',
        );
      }

      // This service currently prepares Float32 RGB input. Fail clearly if
      // the model was exported with a different input tensor type.
      final inputType = inputTensor.type.toString().toLowerCase();
      if (!inputType.contains('float32')) {
        throw StateError(
          'The model input type is $inputType. This service currently '
          'supports float32 input models only.',
        );
      }

      _inputHeight = inputShape[1];
      _inputWidth = inputShape[2];
      _numClasses = outputClasses;
      _interpreter = candidate;
      candidate = null;
      _modelMissing = false;
      _modelLoadError = null;
    } finally {
      candidate?.close();
    }
  }

  void _setLoadFailure(String message) {
    _interpreter?.close();
    _interpreter = null;
    _modelMissing = true;
    _modelLoadError = message;
  }

  /// Classifies an image supplied as encoded bytes (JPEG, PNG, etc.).
  ///
  /// Throws [StateError] if the model has not loaded or the platform is
  /// unsupported, and [ArgumentError] if [imageBytes] is not a decodable image.
  Future<PredictionResult> predict(Uint8List imageBytes) async {
    if (!_isInitialised) {
      await initialise();
    }

    if (!isReady) {
      throw StateError(_modelLoadError ?? 'TensorFlow Lite model is unavailable.');
    }

    if (imageBytes.isEmpty) {
      throw ArgumentError.value(imageBytes, 'imageBytes', 'Image is empty.');
    }

    final stopwatch = Stopwatch()..start();

    final decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) {
      throw ArgumentError(
        'Could not decode the image. Please select a valid JPG or PNG image.',
      );
    }

    // Apply EXIF orientation before resizing so phone-camera photos are
    // processed in the correct orientation.
    final orientedImage = img.bakeOrientation(decodedImage);
    final resizedImage = img.copyResize(
      orientedImage,
      width: _inputWidth,
      height: _inputHeight,
      interpolation: img.Interpolation.linear,
    );

    // Build a flat NHWC RGB Float32 input tensor, normalized to [0, 1].
    final input = Float32List(_inputHeight * _inputWidth * 3);
    var index = 0;

    for (var y = 0; y < _inputHeight; y++) {
      for (var x = 0; x < _inputWidth; x++) {
        final pixel = resizedImage.getPixel(x, y);
        input[index++] = pixel.r.toDouble() / 255.0;
        input[index++] = pixel.g.toDouble() / 255.0;
        input[index++] = pixel.b.toDouble() / 255.0;
      }
    }

    // The interpreter writes the prediction scores into this output tensor.
    final outputBuffer = List<List<double>>.generate(
      1,
      (_) => List<double>.filled(_numClasses, 0.0),
    );
    _interpreter!.run(
      _reshapeInput(input, _inputHeight, _inputWidth),
      outputBuffer,
    );

    stopwatch.stop();

    final rawScores = outputBuffer.first;
    final probabilities = _toProbabilities(rawScores);

    final scores = <ClassScore>[
      for (var i = 0; i < _numClasses; i++)
        ClassScore(
          label: _labels[i],
          score: probabilities[i],
        ),
    ]..sort();

    if (scores.isEmpty) {
      throw StateError('The model returned no class scores.');
    }

    return PredictionResult(
      predictedClass: scores.first.label,
      confidence: scores.first.score,
      allScores: scores,
      inferenceTimeMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// If the model already returns probabilities, retain them. If it returns
  /// logits, apply softmax so the displayed confidence values are meaningful.
  List<double> _toProbabilities(List<double> values) {
    if (values.any((value) => !value.isFinite)) {
      throw StateError('The model returned invalid (NaN or infinite) scores.');
    }

    final allNonNegative = values.every((value) => value >= 0.0);
    final sum = values.fold<double>(0.0, (total, value) => total + value);

    if (allNonNegative && sum > 0.0 && (sum - 1.0).abs() < 0.05) {
      return values.map((value) => value / sum).toList(growable: false);
    }

    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final exponents = values
        .map((value) => math.exp(value - maxValue))
        .toList(growable: false);
    final denominator =
        exponents.fold<double>(0.0, (total, value) => total + value);

    if (denominator == 0.0 || !denominator.isFinite) {
      throw StateError('Could not convert model output into probabilities.');
    }

    return exponents
        .map((value) => value / denominator)
        .toList(growable: false);
  }

  List<List<List<List<double>>>> _reshapeInput(
    Float32List input,
    int height,
    int width,
  ) {
    var offset = 0;

    return <List<List<List<double>>>>[
      List<List<List<double>>>.generate(
        height,
        (_) => List<List<double>>.generate(
          width,
          (_) => List<double>.generate(
            3,
            (_) => input[offset++].toDouble(),
          ),
        ),
      ),
    ];
  }

  /// Releases native model resources. Call when the service is no longer used.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialised = false;
    _modelMissing = false;
    _modelLoadError = null;
    _numClasses = 0;
    _initialisationFuture = null;
  }
}
