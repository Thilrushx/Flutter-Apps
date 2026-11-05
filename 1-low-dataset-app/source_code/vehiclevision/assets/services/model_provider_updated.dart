import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class AIModel {
  final String name;
  final String modelPath;
  final String labelsPath;
  final Color primaryColor;
  final Color secondaryColor;
  final double mean;
  final double std;
  final bool xrayValidation;
  final double confidenceThreshold;

  const AIModel({
    required this.name,
    required this.modelPath,
    required this.labelsPath,
    this.primaryColor = Colors.deepPurple,
    this.secondaryColor = Colors.purpleAccent,
    this.mean = 0.0,
    this.std = 255.0,
    this.xrayValidation = false,
    this.confidenceThreshold = 0.70,
  });
}

class ModelProvider extends ChangeNotifier {
  static const String _modelPrefKey = 'selected_model_name';

  final List<AIModel> availableModels = const [
    // ── Vehicle Detection (Bus / Car / Truck / Motorcycle) ─────────────────
    // MobileNetV2 transfer-learning model, 128x128 input, trained with
    // rescale=1/255  ->  ml_service uses plain (pixel - 0) / 255.
    // Export from notebook (1.6) and copy as best_vehicle_model.tflite.
    AIModel(
      name: 'Vehicle Detection',
      modelPath: 'assets/models/best_vehicle_model.tflite',
      labelsPath: 'assets/labels/vehicle_labels.txt',
      primaryColor: Colors.indigo,
      secondaryColor: Colors.indigoAccent,
      mean: 0.0,
      std: 255.0,
      confidenceThreshold: 0.60,
    ),

    // ── Low Detail Dataset ─────────────────────────────────────────────────
    // ResNet50 + preprocess_input baked inside model graph.
    // Expects raw [0–255] float32 — ml_service uses BGR mean subtraction.
    AIModel(
      name: 'Low Detail Dataset',
      modelPath: 'assets/models/best_low_detail_dataset_model.tflite',
      labelsPath: 'assets/labels/low_detail_dataset_labels.txt',
      primaryColor: Colors.red,
      secondaryColor: Colors.redAccent,
      mean: 0.0,
      std: 1.0,
      confidenceThreshold: 0.70,
    ),

    // ── Low Dataset (Vehicle Type Recognition) ─────────────────────────────
    // MobileNetV2 model trained in the low-dataset notebook; input is RGB / 255.
    AIModel(
      name: 'Low Dataset (Cats)',
      modelPath: 'assets/models/best_low_dataset_model.tflite',
      labelsPath: 'assets/labels/low_dataset_labels.txt',
      primaryColor: Colors.blue,
      secondaryColor: Colors.lightBlueAccent,
      mean: 0.0,
      std: 255.0,
      confidenceThreshold: 0.70,
    ),

    // ── Large Dataset ──────────────────────────────────────────────────────
    AIModel(
      name: 'Large Dataset',
      modelPath: 'assets/models/best_large_dataset_model.tflite',
      labelsPath: 'assets/labels/large_dataset_labels.txt',
      primaryColor: Colors.green,
      secondaryColor: Colors.lightGreenAccent,
      mean: 0.0,
      std: 255.0,
      confidenceThreshold: 0.70,
    ),

    // ── Multiclass Dataset (CIFAR-10, 8 classes) ───────────────────────────
    // EfficientNetB0 — raw [0–255] float32, no /255
    AIModel(
      name: 'Multiclass Dataset',
      modelPath: 'assets/models/best_multiclass_model.tflite',
      labelsPath: 'assets/labels/multiclass_dataset_labels.txt',
      primaryColor: Colors.purple,
      secondaryColor: Colors.purpleAccent,
      mean: 0.0,
      std: 1.0,
      confidenceThreshold: 0.70,
    ),

    // ── Grayscale Dataset ──────────────────────────────────────────────────
    AIModel(
      name: 'Grayscale Dataset',
      modelPath: 'assets/models/best_grayscale_model.tflite',
      labelsPath: 'assets/labels/grayscale_dataset_labels.txt',
      primaryColor: Colors.grey,
      secondaryColor: Colors.blueGrey,
      mean: 0.0,
      std: 255.0,
      confidenceThreshold: 0.70,
    ),

    // ── Medical Dataset (X-ray) ────────────────────────────────────────────
    AIModel(
      name: 'Medical Dataset',
      modelPath: 'assets/models/best_medical_model.tflite',
      labelsPath: 'assets/labels/medical_dataset_labels.txt',
      primaryColor: Colors.teal,
      secondaryColor: Colors.tealAccent,
      mean: 0.0,
      std: 255.0,
      xrayValidation: true,
      confidenceThreshold: 0.70,
    ),

    // ── Imbalanced Dataset (Flowers, 5 classes) ────────────────────────────
    // EfficientNetB0 preprocess_input baked inside model graph
    AIModel(
      name: 'Imbalanced Dataset',
      modelPath: 'assets/models/best_imbalanced_dataset_model.tflite',
      labelsPath: 'assets/labels/imbalanced_dataset_labels.txt',
      primaryColor: Colors.orange,
      secondaryColor: Colors.orangeAccent,
      mean: 0.0,
      std: 1.0,
      confidenceThreshold: 0.70,
    ),

    // ── Tiny Object Dataset (Tiny-ImageNet, 10 classes) ────────────────────
    // MobileNetV2 — images trained with /255 normalisation
    AIModel(
      name: 'Tiny Object Dataset',
      modelPath: 'assets/models/best_tiny_object_dataset.tflite',
      labelsPath: 'assets/labels/tiny_object_dataset_labels.txt',
      primaryColor: Colors.brown,
      secondaryColor: Colors.amberAccent,
      mean: 0.0,
      std: 255.0,
      confidenceThreshold: 0.70,
    ),
  ];

  late AIModel _currentModel;

  ModelProvider() {
    _currentModel = availableModels.first;
    _loadSavedModel();
  }

  AIModel get currentModel => _currentModel;

  Future<void> _loadSavedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString(_modelPrefKey);
      if (savedName != null) {
        final match = availableModels.where((m) => m.name == savedName);
        if (match.isNotEmpty) {
          _currentModel = match.first;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error loading saved model: $e');
    }
  }

  Future<void> setModel(AIModel model) async {
    if (_currentModel.modelPath == model.modelPath) return;
    _currentModel = model;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modelPrefKey, model.name);
    } catch (e) {
      debugPrint('Error saving model choice: $e');
    }
  }
}
