import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/detection_store.dart';
import '../theme/app_theme.dart';

class HistoryEntry {
  final String vehicleClass;
  final double confidence;
  final DateTime timestamp;

  const HistoryEntry({
    required this.vehicleClass,
    required this.confidence,
    required this.timestamp,
  });
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  static final List<HistoryEntry> entries = [];

  static void syncFromStore() {
    entries
      ..clear()
      ..addAll(
        DetectionStore.instance.records.map(
          (record) => HistoryEntry(
            vehicleClass: record.vehicleClass,
            confidence: record.confidence,
            timestamp: record.timestamp,
          ),
        ),
      );
  }

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _store = DetectionStore.instance;
  String _filterClass = 'All';
  String _search = '';

  static const _classes = ['All', 'Car', 'Bus', 'Truck', 'Motorcycle'];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    HistoryScreen.syncFromStore();
    _store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    HistoryScreen.syncFromStore();
    if (mounted) setState(() {});
  }

  List<DetectionRecord> get _filteredRecords {
    final query = _search.trim().toLowerCase();
    return _store.records.where((record) {
      final matchesClass =
          _filterClass == 'All' ||
          record.vehicleClass.toLowerCase() == _filterClass.toLowerCase();
      final matchesSearch =
          query.isEmpty || record.vehicleClass.toLowerCase().contains(query);
      return matchesClass && matchesSearch;
    }).toList();
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear detection history?'),
        content: const Text(
          'This will permanently remove all saved detections.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _store.clearAll();
      HistoryScreen.entries.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = _filteredRecords;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detection History'),
        actions: [
          if (_store.totalScans > 0)
            IconButton(
              tooltip: 'Clear history',
              onPressed: _confirmClear,
              icon: const Icon(Icons.delete_sweep_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => _search = value),
              decoration: InputDecoration(
                hintText: 'Search vehicle type',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemCount: _classes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final vehicleClass = _classes[index];
                return ChoiceChip(
                  label: Text(vehicleClass),
                  selected: _filterClass == vehicleClass,
                  onSelected: (_) =>
                      setState(() => _filterClass = vehicleClass),
                );
              },
            ),
          ),
          Expanded(
            child: records.isEmpty
                ? Center(
                    child: Text(
                      _store.totalScans == 0
                          ? 'No detections yet'
                          : 'No matching detections',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: records.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final record = records[index];
                      final storeIndex = _store.records.indexOf(record);
                      return Dismissible(
                        key: ValueKey(
                          '${record.timestamp.toIso8601String()}-$storeIndex',
                        ),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (_) => _store.removeAt(storeIndex),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: AppColors.backgroundLight,
                                child: Icon(
                                  Icons.directions_car_rounded,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      record.vehicleClass,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${record.timestamp.toLocal()}'
                                          .split('.')
                                          .first,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${(record.confidence * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: AppColors.primaryLight,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
