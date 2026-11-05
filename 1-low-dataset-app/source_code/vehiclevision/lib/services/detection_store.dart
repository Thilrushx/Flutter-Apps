import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DetectionRecord {
  final String vehicleClass;
  final double confidence;
  final DateTime timestamp;
  final int inferenceTimeMs;

  const DetectionRecord({
    required this.vehicleClass,
    required this.confidence,
    required this.timestamp,
    required this.inferenceTimeMs,
  });

  Map<String, dynamic> toJson() => {
        'vehicleClass': vehicleClass,
        'confidence': confidence,
        'timestamp': timestamp.toIso8601String(),
        'inferenceTimeMs': inferenceTimeMs,
      };

  factory DetectionRecord.fromJson(Map<String, dynamic> json) =>
      DetectionRecord(
        vehicleClass: json['vehicleClass'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        inferenceTimeMs: (json['inferenceTimeMs'] as num).toInt(),
      );
}

class DayStat {
  final DateTime day;
  final int count;
  const DayStat(this.day, this.count);
}

class DetectionStore extends ChangeNotifier {
  DetectionStore._() {
    _load();
  }

  static final DetectionStore instance = DetectionStore._();
  static const String _prefsKey = 'detection_records';

  final List<DetectionRecord> _records = [];

  List<DetectionRecord> get records => List.unmodifiable(_records);

  int get totalScans => _records.length;

  double get averageConfidence {
    if (_records.isEmpty) return 0.0;
    final sum = _records.fold(0.0, (acc, r) => acc + r.confidence);
    return sum / _records.length;
  }

  Map<String, int> get classCounts {
    final counts = <String, int>{};
    for (final r in _records) {
      counts[r.vehicleClass] = (counts[r.vehicleClass] ?? 0) + 1;
    }
    return counts;
  }

  List<DayStat> dailyStats({int days = 7}) {
    final now = DateTime.now();
    final stats = <DayStat>[];

    for (int i = days - 1; i >= 0; i--) {
      final targetDate = now.subtract(Duration(days: i));
      int count = 0;
      for (final r in _records) {
        if (r.timestamp.year == targetDate.year &&
            r.timestamp.month == targetDate.month &&
            r.timestamp.day == targetDate.day) {
          count++;
        }
      }
      stats.add(DayStat(targetDate, count));
    }
    return stats;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_prefsKey);
      if (data != null) {
        final List<dynamic> jsonList = jsonDecode(data);
        _records.clear();
        for (var item in jsonList) {
          _records.add(DetectionRecord.fromJson(item as Map<String, dynamic>));
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading records: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String data = jsonEncode(_records.map((e) => e.toJson()).toList());
      await prefs.setString(_prefsKey, data);
    } catch (e) {
      debugPrint('Error saving records: $e');
    }
  }

  Future<void> add(DetectionRecord record) async {
    _records.insert(0, record);
    notifyListeners();
    await _save();
  }

  Future<void> removeAt(int index) async {
    if (index >= 0 && index < _records.length) {
      _records.removeAt(index);
      notifyListeners();
      await _save();
    }
  }

  Future<void> clearAll() async {
    _records.clear();
    notifyListeners();
    await _save();
  }
}
