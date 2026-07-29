import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// Stores incident payloads locally until the API is reachable again.
class OfflineQueue {
  Database? _database;
  final List<Map<String, dynamic>> _webQueue = [];
  int _webId = 0;

  Future<void> open() async {
    if (kIsWeb) return;
    _database ??= await openDatabase(
      '${await getDatabasesPath()}/dey_alert.db',
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE queued_incidents (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          payload TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      '''),
    );
  }

  Future<int> enqueue(Map<String, dynamic> payload) async {
    if (kIsWeb) {
      final id = ++_webId;
      _webQueue.add({'id': id, 'payload': Map<String, dynamic>.from(payload)});
      return id;
    }
    await open();
    return _database!.insert('queued_incidents', {
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> pending() async {
    if (kIsWeb) return List.unmodifiable(_webQueue);
    await open();
    final rows = await _database!.query('queued_incidents', orderBy: 'id ASC');
    return rows
        .map(
          (row) => {
            'id': row['id'],
            'payload': jsonDecode(row['payload'] as String),
          },
        )
        .toList();
  }

  Future<void> remove(int id) async {
    if (kIsWeb) {
      _webQueue.removeWhere((item) => item['id'] == id);
      return;
    }
    await open();
    await _database!.delete(
      'queued_incidents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
