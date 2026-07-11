import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Stores incident payloads locally until the API is reachable again.
class OfflineQueue {
  Database? _database;

  Future<void> open() async {
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
    await open();
    return _database!.insert('queued_incidents', {
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> pending() async {
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
    await open();
    await _database!.delete(
      'queued_incidents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
