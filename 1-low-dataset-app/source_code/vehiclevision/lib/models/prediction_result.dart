/// Holds the output of one TFLite inference pass.
class PredictionResult {
  /// The class label with the highest confidence score.
  final String predictedClass;

  /// Confidence of [predictedClass] in the range [0.0, 1.0].
  final double confidence;

  /// Full ranked list of (label → confidence) for all classes.
  final List<ClassScore> allScores;

  /// Wall-clock time the inference took in milliseconds.
  final int inferenceTimeMs;

  const PredictionResult({
    required this.predictedClass,
    required this.confidence,
    required this.allScores,
    required this.inferenceTimeMs,
  });

  /// Convenience: confidence expressed as a percentage string.
  String get confidencePercent =>
      '${(confidence * 100).toStringAsFixed(1)}%';

  /// True when the model is reasonably confident (≥ 60 %).
  bool get isHighConfidence => confidence >= 0.60;
}

/// A single class name + its softmax score.
class ClassScore implements Comparable<ClassScore> {
  final String label;
  final double score;

  const ClassScore({required this.label, required this.score});

  @override
  int compareTo(ClassScore other) => other.score.compareTo(score);

  @override
  String toString() => '$label: ${(score * 100).toStringAsFixed(1)}%';
}
