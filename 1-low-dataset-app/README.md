# Vehicle Classification App 🚗🏍️🚌🚚

A Flutter-based vehicle image classification application powered by a **MobileNetV2-style TensorFlow Lite (TFLite) model**. Users can select a vehicle image and view the predicted vehicle type, confidence score, and class probabilities.

> **Project note:** This project performs **image classification**, not object detection. It predicts a single vehicle class for an image; it does not draw bounding boxes around vehicles.

## Features

- Classifies images into **Bus, Car, Truck, and Motorcycle**.
- Displays the top prediction and model confidence.
- Displays a score for each vehicle class.
- Runs on **Android** using an on-device TFLite interpreter (no prediction server required).
- Uses real model inference rather than placeholder/mock predictions.

## Model information

| Item | Details |
| --- | --- |
| Architecture | MobileNetV2-style CNN |
| Dataset | [Vehicle Type Recognition (Kaggle)](https://www.kaggle.com/datasets/kaggleashwin/vehicle-type-recognition) |
| Classes | 4 |
| Training subset | 80 images per class (320 total) |
| Validation subset | 10 images per class (40 total) |
| Test subset | 10 images per class (40 total) |
| Notebook image size | 128 × 128 pixels |
| Notebook preprocessing | RGB pixel values divided by 255 |
| Model format | `.tflite` |
| Output | Per-class classification scores (softmax in the training model) |

The Android service reads the actual input dimensions from the model tensor. **Maintain the same preprocessing as the training notebook.**

Label order matters: it must match the class indices used during training.

## Setup and installation

1. Install the Flutter SDK, Android SDK, and Android Studio.
2. Copy the provided model, labels, and Dart service into the matching paths in your Flutter project.
3. Make sure your `pubspec.yaml` includes the `flutter_litert` and `image` packages, using versions compatible with your project.
4. Register the model assets in `pubspec.yaml`:

   ```yaml
   flutter:
     assets:
       - assets/models/best_low_dataset_model.tflite
       - assets/models/labels.txt
   ```

5. Verify that `lib/models/prediction_result.dart` provides the `PredictionResult` and `ClassScore` APIs expected by the service.
6. Start an Android emulator or connect an Android phone with USB debugging enabled.
7. Run:

   ```bash
   flutter doctor
   flutter pub get
   flutter devices
   flutter run
   ```

If Flutter cannot find your device, open **Android Studio → Tools → Device Manager**, start an emulator, and run `flutter devices` again.

## How prediction works

1. The user selects or captures a photo.
2. The app decodes and resizes it to match the model's input shape.
3. Pixels are converted to RGB floating-point values and normalized to `[0, 1]`.
4. The TensorFlow Lite interpreter runs inference.
5. The app maps output indices to vehicle labels and displays the results.

**Confidence is not accuracy.** A prediction can have high confidence and still be wrong, especially on images unlike those in the training data.

## Important: Flutter Web

The supplied Android inference service **does not support real inference in Flutter Web (Chrome)**. Earlier versions of the project used an image-aspect-ratio-based mock predictor in the browser, producing misleading fixed results (such as 96% confidence and 38 ms inference time). That mock output is **not a trained-model prediction**.

To test real inference, run this implementation on **Android**. Browser inference requires a separate, compatible web implementation.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| Bus predicted as Car / Motorcycle predicted as Truck | Confirm the app is using real inference, the correct TFLite file, the correct label order, and training-matched preprocessing. |
| Repeated 96% confidence and 38 ms | Search the app for leftover mock/simulation prediction code and ensure the active service is the real implementation. |
| Device not listed | Run `flutter doctor -v` and `flutter devices`; start an emulator or enable USB debugging. |
| Model fails to load | Check `pubspec.yaml` paths, model file name, package compatibility, and error logs. |
| Scores do not add up to 100% | Check score conversion and whether the UI mixes mock scores with model outputs. |
| Low accuracy with real inference | Evaluate a separate test set, inspect the confusion matrix, add varied labeled images, and consider fine-tuning/retraining. |

## Limitations

- The training subset is small, so real-world performance can be limited.
- This package has **not been verified by an end-to-end Android inference test** in this environment.
- The provided service targets Android inference; Flutter Web requires separate support.
- This is a four-class image classifier, not a bounding-box detector or multi-object tracker.

