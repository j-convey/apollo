library database_service;

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

part 'tables/schema.dart';
part 'tables/tracks_extension.dart';

class DatabaseService {
  static Database? _database;
  
  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Initialize FFI for desktop platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'apollo_music.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Parse media data string back to list
  List<dynamic> _parseMediaData(String mediaData) {
    try {
      if (mediaData.isEmpty) return [];
      final decoded = jsonDecode(mediaData);
      return decoded is List ? decoded : [];
    } catch (e) {
      debugPrint('DATABASE: Error parsing media data: $e');
      return [];
    }
  }
}
