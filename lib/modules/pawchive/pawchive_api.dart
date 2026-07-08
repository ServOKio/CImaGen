import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_models.dart';

class PawchiveApi {
  static const String baseUrl = 'https://pawchive.pw/api/v1';
  static const Duration timeout = Duration(seconds: 30);

  final String? _userAgent;

  PawchiveApi({String? userAgent}) : _userAgent = userAgent;

  Map<String, String> get _defaultHeaders => {
    'Accept': 'application/json',
    if (_userAgent != null) 'User-Agent': _userAgent!,
  };

  /// Fetch list of creators with optional pagination and filters
  Future<CreatorResponse> getCreators() async {

    final uri = Uri.parse('$baseUrl/creators');

    final response = await http.get(uri, headers: _defaultHeaders).timeout(timeout);

    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to fetch creators: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    // Changed from Map to dynamic to support direct Array responses
    final dynamic data = jsonDecode(response.body);
    return CreatorResponse.fromJson(data);
  }

  /// Fetch posts for a specific creator
  Future<PostResponse> getCreatorPosts(
      String creatorId, {
        int offset = 0,
        int limit = 50,
        String? service,
      }) async {
    final queryParams = <String, String>{
      'offset': offset.toString(),
      'limit': limit.toString(),
      if (service != null) 'service': service,
    };

    final uri = Uri.parse('$baseUrl/creators/$creatorId/posts')
        .replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: _defaultHeaders).timeout(timeout);

    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to fetch posts for creator $creatorId: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    // Changed from Map to dynamic to support direct Array responses
    final dynamic data = jsonDecode(response.body);
    return PostResponse.fromJson(data);
  }

  /// Fetch all posts for a creator (handles pagination)
  Future<List<PostJson>> getAllCreatorPosts(
      String creatorId, {
        String? service,
        void Function(int fetched)? onProgress,
      }) async {
    final allPosts = <PostJson>[];
    int offset = 0;
    const limit = 50;

    while (true) {
      final response = await getCreatorPosts(
        creatorId,
        offset: offset,
        limit: limit,
        service: service,
      );

      allPosts.addAll(response.posts);
      onProgress?.call(allPosts.length);

      if (response.posts.length < limit || response.hasMore == false) {
        break;
      }

      offset += limit;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return allPosts;
  }

  /// Fetch posts globally (batch endpoint if available)
  Future<PostResponse> getPosts({
    int offset = 0,
    int limit = 100,
    String? service,
    String? userId,
    bool? hasFull,
  }) async {
    final queryParams = <String, String>{
      'offset': offset.toString(),
      'limit': limit.toString(),
      if (service != null) 'service': service,
      if (userId != null) 'user': userId,
      if (hasFull != null) 'has_full': hasFull.toString(),
    };

    final uri = Uri.parse('$baseUrl/posts').replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: _defaultHeaders).timeout(timeout);

    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to fetch posts: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    // Changed from Map to dynamic to support direct Array responses
    final dynamic data = jsonDecode(response.body);
    return PostResponse.fromJson(data);
  }

  /// Fetch all posts globally (handles pagination)
  Future<List<PostJson>> getAllPosts({
    String? service,
    bool? hasFull,
    void Function(int fetched, int? total)? onProgress,
  }) async {
    final allPosts = <PostJson>[];
    int offset = 0;
    const limit = 100;

    while (true) {
      final response = await getPosts(
        offset: offset,
        limit: limit,
        service: service,
        hasFull: hasFull,
      );

      allPosts.addAll(response.posts);
      onProgress?.call(allPosts.length, response.total);

      // If we got less than requested, we reached the end
      if (response.posts.length < limit) {
        break;
      }

      offset += limit;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return allPosts;
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}