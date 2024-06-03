import 'package:dio/dio.dart';

class GitHub{
  final dio = Dio();
  static const _org = 'ServOKio';
  static const _repo = 'CImaGen';

  static const _apiHost = 'api.github.com';
  static const _commitsEndpoint = '/repos/$_org/$_repo/commits';
  static const _latestReleaseEndpoint = '/repos/$_org/$_repo/releases/latest';

  final Map<Uri, Iterable<Commit>> _commitsCache = {};

  Future<Iterable<Commit>> getCommits({ Map<String, dynamic>? params }) async {
    final commitsUri = Uri.https(_apiHost, _commitsEndpoint, params);
    if (_commitsCache.containsKey(commitsUri)) return _commitsCache[commitsUri]!;
    try {
      final res = await dio.getUri(commitsUri);
      if (res.data is List) {
        final commits = List<Map<String, dynamic>>.from(res.data).map((e) => Commit.fromJson(e));
        _commitsCache[commitsUri] = commits;
        return commits;
      }
    } on DioException {
      // nop
    }
    return [];
  }

  Future<Commit?> getCommit(String commit) async {
    try {
      final res = await dio.getUri(Uri.https(_apiHost, '$_commitsEndpoint/$commit'));
      if (res.data is Map<String, dynamic>) return Commit.fromJson(res.data);
    } on DioException {
      // nop
    }
    return null;
  }

  Future<Release?> getLatestRelease() async {
    try {
      final res = await dio.getUri(Uri.https(_apiHost, _latestReleaseEndpoint));
      if (res.data is Map<String, dynamic>) return Release.fromJson(res.data);
    } on DioException {
      // nop
    }
    return null;
  }

  String getDownloadUrl(String ref, String file) => 'https://raw.githubusercontent.com/$_org/$_repo/$ref/$file';
}

class Commit {
  final String htmlUrl;
  final String sha;
  final CommitCommit commit;
  final String author;

  Commit({ required this.htmlUrl, required this.sha, required this.commit, required this.author });

  Commit.fromJson(Map<String, dynamic> json) : htmlUrl = json['html_url'], sha = json['sha'], commit = CommitCommit(json['commit']['message']), author = json['author'] == null ? json['commit']['author']['name'] : json['author']['login'];
}

class CommitCommit {
  final String message;

  const CommitCommit(this.message);
}

class Release {
  final String tag;
  final String name;
  final String body;
  final Iterable<Asset> assets;

  const Release(this.tag, this.name, this.body, this.assets);

  Release.fromJson(Map<String, dynamic> json) : tag = json['tag_name'], name = json['name'], body = json['body'], assets = (json['assets'] as Iterable<dynamic>).map((e) => Asset(e['name'], e['browser_download_url']));
}

class Asset {
  final String name;
  final String downloadUrl;

  const Asset(this.name, this.downloadUrl);
}