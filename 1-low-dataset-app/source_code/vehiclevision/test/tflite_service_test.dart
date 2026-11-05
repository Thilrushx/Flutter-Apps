import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehiclevision/screens/history_screen.dart';
import 'package:vehiclevision/services/detection_store.dart';
import 'package:vehiclevision/services/tflite_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the vehicle model and predicts four classes', () async {
    final service = TFLiteService.instance;
    addTearDown(service.dispose);
    await service.initialise();

    expect(service.isReady, isTrue, reason: service.modelLoadError);

    final imageData = await rootBundle.load('assets/images/logo.png');
    final imageBytes = Uint8List.sublistView(imageData);
    final result = await service.predict(imageBytes);

    expect(result.allScores.map((score) => score.label).toSet(), {
      'Bus',
      'Car',
      'Motorcycle',
      'Truck',
    });
    expect(result.confidence, inInclusiveRange(0.0, 1.0));
  });

  test(
    'keeps the legacy history list synchronized with detection records',
    () async {
      final store = DetectionStore.instance;
      HistoryScreen.entries.clear();
      await store.clearAll();

      addTearDown(() async {
        await store.clearAll();
        HistoryScreen.entries.clear();
      });

      await store.add(
        DetectionRecord(
          vehicleClass: 'Car',
          confidence: 0.91,
          timestamp: DateTime.now(),
          inferenceTimeMs: 120,
        ),
      );

      HistoryScreen.syncFromStore();

      expect(store.totalScans, 1);
      expect(HistoryScreen.entries.length, 1);
      expect(HistoryScreen.entries.first.vehicleClass, 'Car');
    },
  );
}
