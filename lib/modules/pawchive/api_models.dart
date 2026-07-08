import 'dart:convert';

enum Service {
  patreon(0),
  fanbox(1),
  fantia(2),
  gumroad(3),
  subscribestar(4),
  other(99);

  final int value;
  const Service(this.value);

  static Service fromValue(int value) {
    return Service.values.firstWhere(
          (e) => e.value == value,
      orElse: () => Service.other,
    );
  }

  static Service fromString(String name) {
    return Service.values.firstWhere(
          (e) => e.name == name.toLowerCase(),
      orElse: () => Service.other,
    );
  }
}

class Attachment {
  final String name;
  String? path;

  Attachment({required this.name, this.path});

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
    name: json['name'] as String,
    path: json['path'] != null ? json['path'] as String : null,
  );

  Map<String, dynamic> toJson() => {'name': name, 'path': path};
}

class Leak {
  final String id;
  final String name;
  final Service service;
  final int indexed;
  final int updated;
  final int favorited;
  final bool everImported;

  const Leak({
    required this.id,
    required this.name,
    required this.service,
    required this.indexed,
    required this.updated,
    required this.favorited,
    required this.everImported,
  });

  factory Leak.fromMap(Map<String, dynamic> map) => Leak(
    id: map['id'] as String,
    name: map['name'] as String,
    service: Service.fromValue(map['service'] as int),
    indexed: map['indexed'] as int,
    updated: map['updated'] as int,
    favorited: map['favorited'] as int,
    everImported: (map['ever_imported'] as int) == 1,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'service': service.value,
    'indexed': indexed,
    'updated': updated,
    'favorited': favorited,
    'ever_imported': everImported ? 1 : 0,
  };
}

class Post {
  final String id;
  final String user;
  final Service service;
  final String title;
  final String content;
  final Map<String, dynamic>? embed;
  final bool sharedFile;
  final String added;
  final String published;
  final String edited;
  final Map<String, dynamic>? file;
  final List<Attachment>? attachments;
  final dynamic poll;
  final dynamic captions;
  final List<String>? tags;
  final String origin;
  final String previewState;
  final bool hasFull;
  final int previewAttempts;
  final bool detailFetched;
  final double? importSizeCapGb;

  const Post({
    required this.id,
    required this.user,
    required this.service,
    required this.title,
    required this.content,
    this.embed,
    required this.sharedFile,
    required this.added,
    required this.published,
    required this.edited,
    this.file,
    this.attachments,
    this.poll,
    this.captions,
    this.tags,
    required this.origin,
    required this.previewState,
    required this.hasFull,
    required this.previewAttempts,
    required this.detailFetched,
    this.importSizeCapGb,
  });

  factory Post.fromMap(Map<String, dynamic> map) => Post(
    id: map['id'] as String,
    user: map['user'] as String,
    service: Service.fromValue(map['service'] as int),
    title: (map['title'] as String?) ?? '',
    content: (map['content'] as String?) ?? '',
    embed: map['embed'] != null
        ? jsonDecode(map['embed'] as String) as Map<String, dynamic>
        : null,
    sharedFile: (map['shared_file'] as int) == 1,
    added: (map['added'] as String?) ?? '',
    published: (map['published'] as String?) ?? '',
    edited: (map['edited'] as String?) ?? '',
    file: map['file'] != null
        ? jsonDecode(map['file'] as String) as Map<String, dynamic>
        : null,
    attachments: map['attachments'] != null
        ? (jsonDecode(map['attachments'] as String) as List)
        .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
        .toList()
        : null,
    poll: map['poll'] != null ? jsonDecode(map['poll'] as String) : null,
    captions: map['captions'] != null
        ? jsonDecode(map['captions'] as String)
        : null,
    tags: map['tags'] != null
        ? (jsonDecode(map['tags'] as String) as List).cast<String>()
        : null,
    origin: (map['origin'] as String?) ?? '',
    previewState: (map['preview_state'] as String?) ?? '',
    hasFull: (map['has_full'] as int) == 1,
    previewAttempts: (map['preview_attempts'] as int?) ?? 0,
    detailFetched: (map['detail_fetched'] as int) == 1,
    importSizeCapGb: map['import_size_cap_gb'] != null
        ? (map['import_size_cap_gb'] as num).toDouble()
        : null,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'user': user,
    'service': service.value,
    'title': title,
    'content': content,
    'embed': embed != null ? jsonEncode(embed) : null,
    'shared_file': sharedFile ? 1 : 0,
    'added': added,
    'published': published,
    'edited': edited,
    'file': file != null ? jsonEncode(file) : null,
    'attachments': attachments != null
        ? jsonEncode(attachments!.map((e) => e.toJson()).toList())
        : null,
    'poll': poll != null ? jsonEncode(poll) : null,
    'captions': captions != null ? jsonEncode(captions) : null,
    'tags': tags != null ? jsonEncode(tags) : null,
    'origin': origin,
    'preview_state': previewState,
    'has_full': hasFull ? 1 : 0,
    'preview_attempts': previewAttempts,
    'detail_fetched': detailFetched ? 1 : 0,
    'import_size_cap_gb': importSizeCapGb,
  };
}

class CreatorResponse {
  final List<CreatorJson> creators;
  final int? total;
  final int? offset;
  final int? limit;

  CreatorResponse({
    required this.creators,
    this.total,
    this.offset,
    this.limit,
  });

  /// Handles both direct arrays [] and wrapped objects {"data": []}
  factory CreatorResponse.fromJson(dynamic json) {
    final List<dynamic> data;

    if (json is List) {
      data = json;
    } else if (json is Map<String, dynamic>) {
      data = json['data'] ?? json['creators'] ?? [];
    } else {
      data = [];
    }

    return CreatorResponse(
      creators: data
          .map((e) => CreatorJson.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json is Map<String, dynamic> ? json['total'] as int? : data.length,
      offset: json is Map<String, dynamic> ? json['offset'] as int? : null,
      limit: json is Map<String, dynamic> ? json['limit'] as int? : null,
    );
  }
}

class CreatorJson {
  final String id;
  final String name;
  final String service;
  final int? indexed;
  final int? updated;
  final int? favorited;
  final bool? everImported;

  CreatorJson({
    required this.id,
    required this.name,
    required this.service,
    this.indexed,
    this.updated,
    this.favorited,
    this.everImported,
  });

  factory CreatorJson.fromJson(Map<String, dynamic> json) => CreatorJson(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    service: json['service']?.toString() ?? '',
    indexed: json['indexed'] as int?,
    updated: json['updated'] as int?,
    favorited: json['favorited'] as int?,
    everImported: json['ever_imported'] as bool?,
  );

  Leak toLeak() => Leak(
    id: id,
    name: name,
    service: Service.fromString(service),
    indexed: indexed ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
    updated: updated ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
    favorited: favorited ?? 0,
    everImported: everImported ?? false,
  );
}

class PostResponse {
  final List<PostJson> posts;
  final int? total;
  final int? offset;
  final int? limit;
  final bool? hasMore;

  PostResponse({
    required this.posts,
    this.total,
    this.offset,
    this.limit,
    this.hasMore,
  });

  /// Handles both direct arrays [] and wrapped objects {"data": []}
  factory PostResponse.fromJson(dynamic json) {
    final List<dynamic> data;

    if (json is List) {
      data = json;
    } else if (json is Map<String, dynamic>) {
      data = json['data'] ?? json['posts'] ?? [];
    } else {
      data = [];
    }

    return PostResponse(
      posts: data
          .map((e) => PostJson.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json is Map<String, dynamic> ? json['total'] as int? : data.length,
      offset: json is Map<String, dynamic> ? json['offset'] as int? : null,
      limit: json is Map<String, dynamic> ? json['limit'] as int? : null,
      hasMore: json is Map<String, dynamic> ? json['has_more'] as bool? : null,
    );
  }
}

class PostJson {
  final String id;
  final String user;
  final String service;
  final String? title;
  final String? content;
  final dynamic embed;
  final bool? sharedFile;
  final String? added;
  final String? published;
  final String? edited;
  final dynamic file;
  final List<dynamic>? attachments;
  final dynamic poll;
  final dynamic captions;
  final List<dynamic>? tags;
  final String? origin;
  final String? previewState;
  final bool? hasFull;
  final int? previewAttempts;
  final bool? detailFetched;
  final double? importSizeCapGb;

  PostJson({
    required this.id,
    required this.user,
    required this.service,
    this.title,
    this.content,
    this.embed,
    this.sharedFile,
    this.added,
    this.published,
    this.edited,
    this.file,
    this.attachments,
    this.poll,
    this.captions,
    this.tags,
    this.origin,
    this.previewState,
    this.hasFull,
    this.previewAttempts,
    this.detailFetched,
    this.importSizeCapGb,
  });

  factory PostJson.fromJson(Map<String, dynamic> json) => PostJson(
    id: json['id']?.toString() ?? '',
    user: json['user']?.toString() ?? '',
    service: json['service']?.toString() ?? '',
    title: json['title']?.toString(),
    content: json['content']?.toString(),
    embed: json['embed'],
    sharedFile: json['shared_file'] as bool?,
    added: json['added']?.toString(),
    published: json['published']?.toString(),
    edited: json['edited']?.toString(),
    file: json['file'],
    attachments: json['attachments'] as List<dynamic>?,
    poll: json['poll'],
    captions: json['captions'],
    tags: json['tags'] as List<dynamic>?,
    origin: json['origin']?.toString(),
    previewState: json['preview_state']?.toString(),
    hasFull: json['has_full'] as bool?,
    previewAttempts: json['preview_attempts'] as int?,
    detailFetched: json['detail_fetched'] as bool?,
    importSizeCapGb: (json['import_size_cap_gb'] as num?)?.toDouble(),
  );

  Post toPost() => Post(
    id: id,
    user: user,
    service: Service.fromString(service),
    title: title ?? '',
    content: content ?? '',
    embed: embed != null ? Map<String, dynamic>.from(embed as Map) : null,
    sharedFile: sharedFile ?? false,
    added: added ?? '',
    published: published ?? '',
    edited: edited ?? '',
    file: file != null ? Map<String, dynamic>.from(file as Map) : null,
    attachments: attachments
        ?.map((e) => Attachment.fromJson(e as Map<String, dynamic>))
        .toList(),
    poll: poll,
    captions: captions,
    tags: tags?.cast<String>(),
    origin: origin ?? '',
    previewState: previewState ?? '',
    hasFull: hasFull ?? false,
    previewAttempts: previewAttempts ?? 0,
    detailFetched: detailFetched ?? false,
    importSizeCapGb: importSizeCapGb,
  );
}