import 'package:cimagen/modules/pawchive/pawchive_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../main.dart';
import '../AudioController.dart';
import 'api_models.dart';
import 'database_helper.dart';

class Pawchive {
  final DatabaseHelper dbHelper = DatabaseHelper();
  final PawchiveApi api = PawchiveApi(userAgent: userAgent);

  DateTime? _lastCreatorsSync;
  DateTime? _lastPostsSync;

  DateTime? get lastCreatorsSync => _lastCreatorsSync;
  DateTime? get lastPostsSync => _lastPostsSync;

  Future<void> loadLeakedAndUsersPosts() async {
    int progressNotId = 0;

    try {
      progressNotId = notificationManager!.show(
        thumbnail: const Icon(Icons.cloud_download, color: Colors.blue, size: 32),
        title: 'Syncing leaked content',
        description: 'Fetching creators list...',
      );

      // Step 1: Fetch and store creators
      final creatorsCount = await _syncCreators(progressNotId);

      // Step 2: Fetch and store posts
      notificationManager!.update(progressNotId, (o) {
        o.setDescription('Creators synced: $creatorsCount\nFetching posts...');
      });

      final postsCount = await _syncPosts(progressNotId);

      // Step 3: Mark sync complete
      _lastCreatorsSync = DateTime.now();
      _lastPostsSync = DateTime.now();

      notificationManager!.close(progressNotId);

      notificationManager!.show(
        thumbnail: const Icon(Icons.check_circle, color: Colors.green, size: 32),
        title: 'Sync complete',
        description: 'Loaded $creatorsCount creators and $postsCount posts',
        autoCloseDuration: const Duration(seconds: 6),
      );

      if (kDebugMode) {
        print('Sync complete: $creatorsCount creators, $postsCount posts');
      }

    } on ApiException catch (e) {
      notificationManager!.close(progressNotId);
      notificationManager!.show(
        thumbnail: const Icon(Icons.error, color: Colors.redAccent, size: 32),
        title: 'Sync failed',
        description: 'API error: ${e.message}',
        sound: NtSound.wrong,
      );
    } catch (e) {
      notificationManager!.close(progressNotId);
      notificationManager!.show(
        thumbnail: const Icon(Icons.error, color: Colors.redAccent, size: 32),
        title: 'Sync failed',
        description: 'Unexpected error: $e',
        sound: NtSound.wrong,
      );
    }
  }

  /// Sync creators from API to local database
  Future<int> _syncCreators(int progressNotId) async {
    final creators = <CreatorJson>[];

    final response = await api.getCreators();
    int? total = response.total;
    creators.addAll(response.creators);

    // Update progress
    notificationManager!.update(progressNotId, (o) {
      o.setDescription('Fetching creators: ${creators.length}${total != null ? ' / $total' : ''}...');
      o.setContent(Container(
        margin: const EdgeInsets.only(top: 7),
        width: 100,
        child: LinearProgressIndicator(
          value: total != null ? creators.length / total : null,
        ),
      ));
    });

    await Future.delayed(const Duration(milliseconds: 50));

    if (creators.isEmpty) return 0;

    // Convert to Leak models and insert in batches
    final leaks = creators.map((c) => c.toLeak()).toList();
    const batchSize = 500;

    for (int i = 0; i < leaks.length; i += batchSize) {
      final end = (i + batchSize > leaks.length) ? leaks.length : i + batchSize;
      final batch = leaks.sublist(i, end);
      await dbHelper.insertLeaks(batch);

      notificationManager!.update(progressNotId, (o) {
        o.setDescription('Storing creators: $end / ${leaks.length}...');
        o.setContent(Container(
          margin: const EdgeInsets.only(top: 7),
          width: 100,
          child: LinearProgressIndicator(
            value: end / leaks.length,
          ),
        ));
      });
    }

    return creators.length;
  }

  /// Sync posts from API to local database
  Future<int> _syncPosts(int progressNotId) async {
    final posts = <PostJson>[];
    int offset = 0;
    const limit = 100;
    int? total;

    final response = await api.getPosts(offset: offset, limit: limit);
    do {
      total = response.total;
      posts.addAll(response.posts);
      offset += limit;

      // Update progress
      notificationManager!.update(progressNotId, (o) {
        o.setDescription('Fetching posts: ${posts.length}${total != null ? ' / $total' : ''}...');
        o.setContent(Container(
          margin: const EdgeInsets.only(top: 7),
          width: 100,
          child: LinearProgressIndicator(
            value: total != null ? posts.length / total : null,
          ),
        ));
      });

      await Future.delayed(const Duration(milliseconds: 50));

    } while (response.posts.length == limit);

    if (posts.isEmpty) return 0;

    // Convert to Post models and insert in batches
    final postModels = posts.map((p) => p.toPost()).toList();
    const batchSize = 200;

    for (int i = 0; i < postModels.length; i += batchSize) {
      final end = (i + batchSize > postModels.length) ? postModels.length : i + batchSize;
      final batch = postModels.sublist(i, end);
      await dbHelper.insertPosts(batch);

      notificationManager!.update(progressNotId, (o) {
        o.setDescription('Storing posts: $end / ${postModels.length}...');
      });
    }

    return posts.length;
  }

  Future<int> syncPostsForCreators(
      List<String> creatorIds, {
        int? progressNotId,
      }) async {
    final allPosts = <PostJson>[];
    int processed = 0;

    for (final creatorId in creatorIds) {
      try {
        final creatorPosts = await api.getAllCreatorPosts(creatorId);
        allPosts.addAll(creatorPosts);
        processed++;

        if (progressNotId != null) {
          notificationManager!.update(progressNotId, (o) {
            o.setDescription(
              'Fetching posts for creator $processed/${creatorIds.length}\n'
                  'Total posts: ${allPosts.length}',
            );
          });
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to fetch posts for creator $creatorId: $e');
        }
        // Continue with other creators
      }

      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (allPosts.isEmpty) return 0;

    // Insert posts
    final postModels = allPosts.map((p) => p.toPost()).toList();
    const batchSize = 200;

    for (int i = 0; i < postModels.length; i += batchSize) {
      final end = (i + batchSize > postModels.length) ? postModels.length : i + batchSize;
      await dbHelper.insertPosts(postModels.sublist(i, end));
    }

    return allPosts.length;
  }

  Future<void> incrementalSync() async {
    final lastSync = _lastCreatorsSync;

    if (lastSync == null) {
      // First time sync - do full sync
      await loadLeakedAndUsersPosts();
      return;
    }

    int progressNotId = 0;

    try {
      progressNotId = notificationManager!.show(
        thumbnail: const Icon(Icons.sync, color: Colors.blue, size: 32),
        title: 'Incremental sync',
        description: 'Checking for updates...',
      );

      // Fetch creators updated since last sync
      final updatedSince = lastSync.toIso8601String();
      final creators = await api.getCreators();

      // Filter locally to find truly new/updated ones
      final newCreators = <Leak>[];
      for (final creatorJson in creators.creators) {
        final existing = await dbHelper.getLeak(creatorJson.id);

        // If doesn't exist or updated timestamp is newer
        if (existing == null ||
            (creatorJson.updated != null && creatorJson.updated! > existing.updated)) {
          newCreators.add(creatorJson.toLeak());
        }
      }

      if (newCreators.isNotEmpty) {
        await dbHelper.insertLeaks(newCreators);
        notificationManager!.update(progressNotId, (o) {
          o.setDescription('Updated ${newCreators.length} creators');
        });
      }

      // Similarly for posts
      final postsResponse = await api.getPosts(limit: 1000);
      final newPosts = <Post>[];

      for (final postJson in postsResponse.posts) {
        final existing = await dbHelper.getPost(postJson.id);

        if (existing == null) {
          newPosts.add(postJson.toPost());
        }
      }

      if (newPosts.isNotEmpty) {
        await dbHelper.insertPosts(newPosts);
        notificationManager!.update(progressNotId, (o) {
          o.setDescription('Added ${newPosts.length} new posts');
        });
      }

      _lastCreatorsSync = DateTime.now();
      _lastPostsSync = DateTime.now();

      notificationManager!.close(progressNotId);

      if (newCreators.isNotEmpty || newPosts.isNotEmpty) {
        notificationManager!.show(
          thumbnail: const Icon(Icons.check_circle, color: Colors.green, size: 32),
          title: 'Sync complete',
          description: '${newCreators.length} creators, ${newPosts.length} posts updated',
          autoCloseDuration: const Duration(seconds: 4),
        );
      } else {
        notificationManager!.show(
          thumbnail: const Icon(Icons.check_circle, color: Colors.green, size: 32),
          title: 'Already up to date',
          description: 'No new content found',
          autoCloseDuration: const Duration(seconds: 3),
        );
      }

    } catch (e) {
      notificationManager!.close(progressNotId);
      notificationManager!.show(
        thumbnail: const Icon(Icons.error, color: Colors.orange, size: 32),
        title: 'Sync failed',
        description: '$e',
        autoCloseDuration: const Duration(seconds: 5),
      );
    }
  }

  /// Force refresh - clear and re-download everything
  Future<void> forceRefresh() async {
    int confirmNotId = 0;
    confirmNotId = notificationManager!.show(
      thumbnail: const Icon(Icons.warning_amber, color: Colors.orange, size: 32),
      title: 'Force refresh',
      description: 'This will delete all local data and re-download.\nContinue?',
      content: Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all<Color>(Colors.red),
                foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
              ),
              onPressed: () async {
                notificationManager!.close(confirmNotId);
                await _performForceRefresh();
              },
              child: const Text('Yes, refresh', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => notificationManager!.close(confirmNotId),
              child: const Text('Cancel', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performForceRefresh() async {
    int progressNotId = 0;

    try {
      progressNotId = notificationManager!.show(
        thumbnail: const Icon(Icons.refresh, color: Colors.blue, size: 32),
        title: 'Clearing data',
        description: 'Removing local database...',
      );

      // Clear tables
      final db = await dbHelper.database;
      await db.delete('posts');
      await db.delete('leaks');

      _lastCreatorsSync = null;
      _lastPostsSync = null;

      // Re-sync
      notificationManager!.update(progressNotId, (o) {
        o.setDescription('Data cleared. Starting fresh sync...');
      });

      await loadLeakedAndUsersPosts();

    } catch (e) {
      notificationManager!.close(progressNotId);
      notificationManager!.show(
        thumbnail: const Icon(Icons.error, color: Colors.redAccent, size: 32),
        title: 'Refresh failed',
        description: '$e',
        sound: NtSound.wrong,
      );
    }
  }
}