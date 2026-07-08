import 'dart:io';

import 'package:external_path/external_path.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/utils/utils.dart' as sqLite show firstIntValue;

import 'api_models.dart';

class DatabaseHelper {
  static const int _dbVersion = 1;
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory? dD;
    if(Platform.isAndroid){
      dD = Directory(await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_DOCUMENTS));
    } else {
      dD = await getApplicationDocumentsDirectory();
    }
    dynamic dbPath = Directory(p.join(dD.path, 'CImaGen', 'databases'));
    if (!await dbPath.exists()) {
      await dbPath.create(recursive: true);
    }
    dbPath = File(p.join(dD.path, 'CImaGen', 'databases', 'pawchive.db'));

    return await openDatabase(
      dbPath.path,
      version: _dbVersion,
      onOpen: (db) {
        // Enable foreign keys
        db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Leaks table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS leaks (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        service INTEGER NOT NULL,
        indexed INTEGER NOT NULL,
        updated INTEGER NOT NULL,
        favorited INTEGER NOT NULL DEFAULT 0,
        ever_imported INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Posts table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS posts (
        id TEXT PRIMARY KEY,
        user TEXT NOT NULL,
        service INTEGER NOT NULL,
        title TEXT,
        content TEXT,
        embed TEXT,
        shared_file INTEGER NOT NULL DEFAULT 0,
        added TEXT,
        published TEXT,
        edited TEXT,
        file TEXT,
        attachments TEXT,
        poll TEXT,
        captions TEXT,
        tags TEXT,
        origin TEXT,
        preview_state TEXT,
        has_full INTEGER NOT NULL DEFAULT 0,
        preview_attempts INTEGER NOT NULL DEFAULT 0,
        detail_fetched INTEGER NOT NULL DEFAULT 0,
        import_size_cap_gb REAL,
        FOREIGN KEY (user) REFERENCES leaks(id) ON DELETE CASCADE
      )
    ''');

    // Indexes for performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_leaks_service ON leaks(service)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_posts_user ON posts(user)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_posts_service ON posts(service)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_posts_published ON posts(published)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion == 0) return;
    if (kDebugMode) {
      print('Database upgrade: $oldVersion -> $newVersion');
    }
    // Add migration scripts here for future versions
    // Example:
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE posts ADD COLUMN new_field TEXT');
    // }
  }

  // ============ LEAKS CRUD ============

  Future<int> insertLeak(Leak leak) async {
    final db = await database;
    return db.insert('leaks', leak.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> insertLeaks(List<Leak> leaks) async {
    final db = await database;
    final batch = db.batch();
    for (final leak in leaks) {
      batch.insert('leaks', leak.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    final results = await batch.commit(noResult: false);
    return results.length;
  }

  Future<Leak?> getLeak(String id) async {
    final db = await database;
    final maps = await db.query('leaks', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Leak.fromMap(maps.first);
  }

  Future<List<Leak>> getAllLeaks({String? orderBy}) async {
    final db = await database;
    final maps = await db.query(
      'leaks',
      orderBy: orderBy ?? 'updated DESC',
    );
    return maps.map((m) => Leak.fromMap(m)).toList();
  }

  Future<List<Leak>> getLeaksByService(Service service) async {
    final db = await database;
    final maps = await db.query(
      'leaks',
      where: 'service = ?',
      whereArgs: [service.value],
      orderBy: 'updated DESC',
    );
    return maps.map((m) => Leak.fromMap(m)).toList();
  }

  Future<int> updateLeak(Leak leak) async {
    final db = await database;
    return db.update('leaks', leak.toMap(), where: 'id = ?', whereArgs: [leak.id]);
  }

  Future<int> deleteLeak(String id) async {
    final db = await database;
    return db.delete('leaks', where: 'id = ?', whereArgs: [id]);
  }

  // ============ POSTS CRUD ============

  Future<int> insertPost(Post post) async {
    final db = await database;
    return db.insert('posts', post.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> insertPosts(List<Post> posts) async {
    final db = await database;
    final batch = db.batch();
    for (final post in posts) {
      batch.insert('posts', post.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    final results = await batch.commit(noResult: false);
    return results.length;
  }

  Future<Post?> getPost(String id) async {
    final db = await database;
    final maps = await db.query('posts', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Post.fromMap(maps.first);
  }

  Future<List<Post>> getPostsByUser(String userId, {int limit = 50, int offset = 0}) async {
    final db = await database;
    final maps = await db.query(
      'posts',
      where: 'user = ?',
      whereArgs: [userId],
      orderBy: 'published DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => Post.fromMap(m)).toList();
  }

  Future<List<Post>> getPostsByService(
      Service service, {
        int limit = 50,
        int offset = 0,
      }) async {
    final db = await database;
    final maps = await db.query(
      'posts',
      where: 'service = ?',
      whereArgs: [service.value],
      orderBy: 'published DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => Post.fromMap(m)).toList();
  }

  Future<List<Post>> getPostsWithFullContent({
    Service? service,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    final where = service != null ? 'has_full = 1 AND service = ?' : 'has_full = 1';
    final whereArgs = service != null ? [service.value] : null;

    final maps = await db.query(
      'posts',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'published DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => Post.fromMap(m)).toList();
  }

  Future<int> updatePost(Post post) async {
    final db = await database;
    return db.update('posts', post.toMap(), where: 'id = ?', whereArgs: [post.id]);
  }

  Future<int> deletePost(String id) async {
    final db = await database;
    return db.delete('posts', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deletePostsByUser(String userId) async {
    final db = await database;
    return db.delete('posts', where: 'user = ?', whereArgs: [userId]);
  }

  // ============ JOIN QUERIES ============

  Future<List<Map<String, dynamic>>> getPostsWithLeakInfo({
    int limit = 50,
    int offset = 0,
    Service? service,
  }) async {
    final db = await database;
    final where = service != null ? 'WHERE p.service = ?' : '';
    final whereArgs = service != null ? [service.value] : <dynamic>[];

    return db.rawQuery('''
      SELECT p.*, l.name as leak_name
      FROM posts p
      LEFT JOIN leaks l ON p.user = l.id
      $where
      ORDER BY p.published DESC
      LIMIT ? OFFSET ?
    ''', [...whereArgs, limit, offset]);
  }

  // ============ UTILITY ============

  Future<int> getLeaksCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM leaks');
    return sqLite.firstIntValue(result) ?? 0;
  }

  Future<int> getPostsCount({String? userId}) async {
    final db = await database;
    if (userId != null) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM posts WHERE user = ?',
        [userId],
      );
      return sqLite.firstIntValue(result) ?? 0;
    }
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM posts');
    return sqLite.firstIntValue(result) ?? 0;
  }

  /// Search leaks by name (case-insensitive)
  Future<List<Leak>> searchLeaks(String query) async {
    final db = await database;
    final maps = await db.query(
      'leaks',
      where: 'LOWER(name) LIKE ?',
      whereArgs: ['%${query.toLowerCase()}%'],
      orderBy: 'updated DESC',
    );
    return maps.map((m) => Leak.fromMap(m)).toList();
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}