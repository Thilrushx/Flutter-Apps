# 📱 Flutter Apps

![Flutter](https://img.shields.io/badge/Flutter-Framework-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-Language-0175C2?logo=dart&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-Thilrushx-181717?logo=github&logoColor=white)

A collection of Flutter and Dart application projects, experiments, and mobile UI implementations. This repository documents practical learning in cross-platform app development, interface design, and integrating machine-learning models into applications.

**Repository:** [Thilrushx/Flutter-Apps](https://github.com/Thilrushx/Flutter-Apps)

## 🚀 Project Highlight: Vehicle Classification App

A Flutter-based image classification application designed to identify vehicle categories using a TensorFlow Lite model.

### Features

- Select a vehicle image and request a prediction.
- Display the predicted vehicle category and its confidence score.
- Show class-by-class scores for **Bus**, **Car**, **Truck**, and **Motorcycle**.
- Run on-device inference through a TensorFlow Lite model on supported mobile platforms.
- Display recent prediction results through a mobile-friendly interface.

### Machine Learning

| Component | Details |
| --- | --- |
| Model architecture | MobileNetV2-based image classifier |
| Deployment format | TensorFlow Lite (`.tflite`) |
| Image input | RGB, resized to 128 × 128 (training notebook configuration) |
| Vehicle classes | Bus, Car, Truck, Motorcycle |
| Frameworks | TensorFlow / Keras, Flutter / Dart |

> **Important:** The app performs **image classification**, not object detection with bounding boxes. Confidence scores reflect model output, not guaranteed accuracy. The training preprocessing and class-label ordering must exactly match the deployed model. Flutter Web requires its own real-inference implementation; simulated predictions should not be presented as model results.

## 🛠️ Technologies

- **Flutter** — cross-platform UI framework
- **Dart** — application programming language
- **TensorFlow / Keras** — machine-learning model development
- **TensorFlow Lite / LiteRT** — mobile model inference
- **Android Studio or VS Code** — development environment

## ⚙️ Getting Started

### Prerequisites

- Flutter SDK installed and configured
- Android Studio or VS Code
- An Android emulator or a connected Android device

### Clone the repository

```bash
git clone https://github.com/Thilrushx/Flutter-Apps.git
cd Flutter-Apps
```

### Find and run a Flutter project

If the repository contains multiple project folders, change into the folder that contains the app's `pubspec.yaml` file.

```bash
flutter doctor
flutter pub get
flutter devices
flutter run
```

If an Android device is listed, you may specify its device ID:

```bash
flutter run -d <device-id>
```

> If `pubspec.yaml` is not at the repository root, run the Flutter commands inside the relevant application folder.

### Vehicle classification model assets

For the vehicle classifier, verify that the project contains model and label files and that their paths match the Dart service and `pubspec.yaml` configuration.

Example asset declaration:

```yaml
flutter:
  assets:
    - assets/models/best_low_dataset_model.tflite
    - assets/models/labels.txt
```

Do not assume the paths above match every project; adjust them to the actual files.

## 🧪 Testing and Troubleshooting

- Run `flutter doctor -v` if Flutter or Android tooling is not detected.
- Start an emulator in **Android Studio → Device Manager**, or connect a physical device with USB debugging enabled.
- Confirm the `labels.txt` order matches the model's training-time class indices.
- Confirm the input tensor shape, input data type, and image normalization match the exported `.tflite` model.
- Test real TensorFlow Lite inference on an Android device before trusting confidence scores.
- Avoid hard-coded or simulated predictions in production.

## 📁 Repository Organization

This repository can hold multiple independent Flutter projects. Each project should keep its own `pubspec.yaml`, source code, assets, and optional project-specific README.

## 🔮 Future Improvements

- Improve model evaluation on unseen vehicle photos.
- Add a confusion matrix and per-class performance report.
- Expand test coverage and error handling.
- Add platform-appropriate web inference if browser deployment is needed.
- Document each app with screenshots and setup instructions.

