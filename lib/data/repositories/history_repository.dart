import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../models/history_item.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository();
});

class HistoryRepository {
  static const String _historyKey = 'image_tools_history';

  Future<List<HistoryItem>> getRecentHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJsonList = prefs.getStringList(_historyKey) ?? [];

      final items = <HistoryItem>[];
      for (final jsonStr in historyJsonList) {
        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          final item = HistoryItem.fromJson(map);
          // Only include if file still exists
          if (File(item.filePath).existsSync()) {
            items.add(item);
          }
        } catch (_) {}
      }

      return items;
    } catch (_) {
      return [];
    }
  }

  Future<void> addHistoryItem(HistoryItem item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentList = await getRecentHistory();

      // Remove existing if duplicate
      currentList.removeWhere((i) => i.filePath == item.filePath);

      // Insert at front
      currentList.insert(0, item);

      // Trim if exceeds max
      if (currentList.length > AppConstants.maxHistoryItems) {
        currentList.removeRange(AppConstants.maxHistoryItems, currentList.length);
      }

      final stringList = currentList.map((i) => jsonEncode(i.toJson())).toList();
      await prefs.setStringList(_historyKey, stringList);
    } catch (_) {}
  }

  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (_) {}
  }
}
