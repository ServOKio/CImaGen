import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../components/AppBar.dart';
import '../../../components/CustomMasonryView.dart';
import '../../../modules/pawchive/api_models.dart';
import '../../../utils/ImageManager.dart';
import '../../pages/sub/ImageView.dart';
import '../DataManager.dart';

const String _thumbCdn = 'https://img.pawchive.pw/thumbnail/data';
const String _fileCdn = 'https://file.pawchive.pw/data';
const String _apiBase = 'https://pawchive.pw/api/v1';

class PostJson {
  final String id;
  final String user;
  final String service;
  final String? title;
  final String? published;
  final List<dynamic>? attachments;
  final bool? hasFull;

  const PostJson({
    required this.id,
    required this.user,
    required this.service,
    this.title,
    this.published,
    this.attachments,
    this.hasFull,
  });

  factory PostJson.fromJson(Map<String, dynamic> json) => PostJson(
    id: json['id']?.toString() ?? '',
    user: json['user']?.toString() ?? '',
    service: json['service']?.toString() ?? '',
    title: json['title']?.toString(),
    published: json['published']?.toString(),
    attachments: json['attachments'] as List<dynamic>?,
    hasFull: json['has_full'] as bool?,
  );

  String? get firstAttachmentPath {
    if (attachments == null || attachments!.isEmpty) return null;
    return (attachments!.first as Map<String, dynamic>)['path'] as String?;
  }
}

class PostDetailJson {
  final String id;
  final String user;
  final String service;
  final String title;
  final String content;
  final String published;
  final List<dynamic> attachments;
  final String? next;
  final String? prev;

  const PostDetailJson({
    required this.id,
    required this.user,
    required this.service,
    required this.title,
    required this.content,
    required this.published,
    required this.attachments,
    this.next,
    this.prev,
  });

  factory PostDetailJson.fromJson(Map<String, dynamic> json) => PostDetailJson(
    id: json['id']?.toString() ?? '',
    user: json['user']?.toString() ?? '',
    service: json['service']?.toString() ?? '',
    title: json['title']?.toString() ?? 'Untitled',
    content: json['content']?.toString() ?? '',
    published: json['published']?.toString() ?? '',
    attachments: json['attachments'] as List<dynamic>? ?? [],
    next: json['next']?.toString(),
    prev: json['prev']?.toString(),
  );
}

class ServiceInfo {
  final String label;
  final Color color;
  final IconData icon;
  const ServiceInfo({required this.label, required this.color, required this.icon});
}

const Map<String, ServiceInfo> _serviceMap = {
  'patreon': ServiceInfo(label: 'Patreon', color: Color(0xFFFF424D), icon: Icons.favorite),
  'fanbox': ServiceInfo(label: 'Fanbox', color: Color(0xFF0099FF), icon: Icons.star),
  'fantia': ServiceInfo(label: 'Fantia', color: Color(0xFFE040FB), icon: Icons.diamond),
  'gumroad': ServiceInfo(label: 'Gumroad', color: Color(0xFFFFA726), icon: Icons.store),
  'subscribestar': ServiceInfo(label: 'SubscribeStar', color: Color(0xFF66BB6A), icon: Icons.subscriptions),
};

ServiceInfo _getSvc(String s) => _serviceMap[s.toLowerCase()] ?? const ServiceInfo(label: 'Unknown', color: Color(0xFF616161), icon: Icons.help_outline);
ServiceInfo _getSvcEnum(Service s) => _serviceMap[s.name.toLowerCase()] ?? const ServiceInfo(label: 'Unknown', color: Color(0xFF616161), icon: Icons.help_outline);

String _relTime(int? u) {
  if (u == null) return '';
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(u * 1000));
  if (d.inDays > 365) return '${d.inDays ~/ 365}y';
  if (d.inDays > 30) return '${d.inDays ~/ 30}mo';
  if (d.inDays > 0) return '${d.inDays}d';
  return '${d.inHours}h';
}

String _stripHtml(String html) => html.replaceAll(RegExp(r'<[^>]*>'), '').trim();

class InnerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onBack;
  final String? title;
  final List<Widget>? actions;

  const InnerAppBar({super.key, this.onBack, this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    return DraggableAppBar(
        child: Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: onBack ?? () => Navigator.pop(context),
            ),
            if(title != null) Text(title!, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            if(actions != null) ...[const Spacer(), ...actions!]
          ],
        )
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

enum _SearchView { idle, results, userPosts, postDetail }

class DotSearch extends StatefulWidget {
  const DotSearch({super.key});

  @override
  State<DotSearch> createState() => _DotSearchState();
}

class _DotSearchState extends State<DotSearch> with TickerProviderStateMixin {
  _SearchView _view = _SearchView.idle;
  bool _isHovering = false;
  bool _hasFocus = false;
  bool _isLoading = false;

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  int _currentFileIndex = 0;
  int _totalFiles = 0;

  String? _error;

  List<Leak> _creators = [];
  List<Post> _posts = []; // Unified list: Always contains local DB Post objects

  // Pagination & Infinite Scroll state
  final _postsScrollController = ScrollController();
  int _currentOffset = 0;
  bool _hasMorePosts = true;
  bool _isLoadingMore = false;

  Leak? _selectedLeak;
  PostDetailJson? _postDetail;

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _listScroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocus.requestFocus());
    _postsScrollController.addListener(_onPostsScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _listScroll.dispose();
    _postsScrollController.removeListener(_onPostsScroll);
    _postsScrollController.dispose();
    super.dispose();
  }

  // ── Infinite Scroll Listener ──

  void _onPostsScroll() {
    if (_view != _SearchView.userPosts || _isLoadingMore || !_hasMorePosts) return;

    // Trigger when user is 80% near the bottom
    if (_postsScrollController.position.pixels >= _postsScrollController.position.maxScrollExtent * 0.8) {
      _fetchMorePosts();
    }
  }

  // ── Search ──

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) return setState(() { _view = _SearchView.idle; _creators.clear(); });
    if (q.trim().length < 4) return;

    _debounce = Timer(const Duration(milliseconds: 150), () async {
      final res = await context.read<DataManager>().pawchive.dbHelper.searchLeaks(q.trim());
      if (!mounted) return;
      setState(() { _creators = res; _view = res.isEmpty ? _SearchView.idle : _SearchView.results; });
    });
  }

  // ── Load Posts (Initial) ──

  Future<void> _loadUserPosts(Leak leak) async {
    setState(() {
      _selectedLeak = leak;
      _posts.clear();
      _currentOffset = 0;
      _hasMorePosts = true;
      _isLoading = true;
      _view = _SearchView.userPosts;
    });

    try {
      final db = context.read<DataManager>().pawchive.dbHelper;

      // 1. Load what we have locally first
      final localPosts = await db.getPostsByUser(leak.id, limit: 999999);
      if (localPosts.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _posts = localPosts;
          _isLoading = false;
          // Set the API offset to the nearest 50 step
          _currentOffset = (localPosts.length / 50).ceil() * 50;
        });
        return;
      }

      // 2. If nothing local, fetch first batch from API
      await _fetchMorePosts();

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  // ── Fetch More Posts (Pagination & Caching) ──

  Future<void> _fetchMorePosts() async {
    if (_isLoadingMore || !_hasMorePosts || _selectedLeak == null) return;
    setState(() => _isLoadingMore = true);

    final leak = _selectedLeak!;
    final svc = _getSvcEnum(leak.service);
    final db = context.read<DataManager>().pawchive.dbHelper;

    try {
      // Use the specific API endpoint format: /{service}/user/{id}?o={offset}
      final uri = Uri.parse('$_apiBase/${svc.label.toLowerCase()}/user/${leak.id}').replace(queryParameters: {
        'o': _currentOffset.toString(),
      });

      final res = await http.get(uri, headers: {'Accept': 'application/json'});
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final dynamic data = jsonDecode(res.body);
      final List<dynamic> rawItems = List.from(data is List ? data : (data['data'] ?? []));

      if (rawItems.isEmpty) {
        if (!mounted) return;
        setState(() { _hasMorePosts = false; _isLoadingMore = false; });
        return;
      }

      // Parse and convert to local DB Post objects
      final newPosts = rawItems
          .whereType<Map<String, dynamic>>()
          .map((e) => PostJson.fromJson(e))
          .map((p) => _convertApiPostToDbPost(p))
          .where((p) => !_posts.any((existing) => existing.id == p.id)) // Prevent UI duplicates
          .toList();

      if (newPosts.isEmpty) {
        if (!mounted) return;
        setState(() { _hasMorePosts = false; _isLoadingMore = false; });
        return;
      }

      // Cache to database in background
      db.insertPosts(newPosts);

      if (!mounted) return;
      setState(() {
        _posts.addAll(newPosts);
        _currentOffset += 50; // API enforces 50 steps
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoadingMore = false; });
    }
  }

  // Convert API format to local SQLite Post format
  Post _convertApiPostToDbPost(PostJson p) {
    List<Attachment>? attachments;
    if (p.attachments != null && p.attachments!.isNotEmpty) {
      attachments = p.attachments!
          .whereType<Map<String, dynamic>>()
          .map((e) => Attachment.fromJson(e))
          .toList();
    }

    return Post(
      id: p.id,
      user: p.user,
      service: Service.fromString(p.service),
      title: p.title ?? '',
      content: '',
      added: p.published ?? '',
      published: p.published ?? '',
      edited: p.published ?? '',
      attachments: attachments,
      origin: 'api_cached',
      previewState: '',
      hasFull: p.hasFull == true,
      previewAttempts: 0,
      detailFetched: false,
      sharedFile: false,
    );
  }

  // ── Post Detail ──

  Future<void> _loadPostDetail(String service, String userId, String postId) async {
    setState(() { _isLoading = true; _view = _SearchView.postDetail; _error = null; });
    try {
      final uri = Uri.parse('$_apiBase/$service/user/$userId/post/$postId');
      final res = await http.get(uri, headers: {'Accept': 'application/json'});
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      if (!mounted) return;
      setState(() { _postDetail = PostDetailJson.fromJson(jsonDecode(res.body)); _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _downloadAll() async {
    if (_postDetail == null || _isDownloading) return;
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;

    setState(() {
      _isDownloading = true;
      _totalFiles = _postDetail!.attachments.length;
      _currentFileIndex = 0;
      _downloadProgress = 0.0;
    });

    final client = http.Client();

    try {
      for (int i = 0; i < _postDetail!.attachments.length; i++) {
        final att = _postDetail!.attachments[i];
        final name = att['name'] ?? 'unknown';
        final attPath = att['path'] ?? '';
        if (attPath.isEmpty) continue;

        setState(() {
          _currentFileIndex = i + 1;
          _downloadProgress = 0.0;
        });

        final url = '$_fileCdn$attPath';
        final req = await client.send(http.Request('GET', Uri.parse(url)));
        final file = File(p.join(path, name));
        final sink = file.openWrite();

        final contentLength = req.contentLength ?? -1;
        int downloadedBytes = 0;

        await req.stream.listen(
              (chunk) {
            sink.add(chunk);
            downloadedBytes += chunk.length;

            // Only update UI when progress changes by at least 1% to prevent UI freezing
            if (contentLength > 0) {
              final newProgress = downloadedBytes / contentLength;
              if ((newProgress - _downloadProgress).abs() > 0.01) {
                _downloadProgress = newProgress;
                if (mounted) setState(() {});
              }
            }
          },
          onDone: () async => await sink.close(),
          onError: (e) {
            sink.close();
            throw e;
          },
        ).asFuture();
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download complete!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    } finally {
      client.close();
      if (mounted) setState(() { _isDownloading = false; _downloadProgress = 0.0; });
    }
  }

  void _goBack() {
    if (_view == _SearchView.postDetail) {
      setState(() { _view = _SearchView.userPosts; _postDetail = null; });
    } else if (_view == _SearchView.userPosts) {
      setState(() {
        _view = _SearchView.results;
        _selectedLeak = null;
        _posts.clear();
      });
      _searchFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_view == _SearchView.postDetail) return _buildPostDetailScreen();

    final size = MediaQuery.of(context).size;
    final isIdle = _view == _SearchView.idle;
    final isPosts = _view == _SearchView.userPosts;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF08080d),
      appBar: !isIdle
          ? InnerAppBar(
        onBack: _goBack,
        title: isPosts ? _selectedLeak?.name : null,
      )
          : null,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter(opacity: isIdle ? 0.03 : 0.015))),

          // SEARCH BOX: 300px width, centered horizontally
          AnimatedPositioned(
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeOutCubic,
            top: isIdle ? size.height * 0.42 : (isPosts ? kToolbarHeight + 8.0 : kToolbarHeight + 16.0),
            left: (size.width - 300) / 2, // Center X
            child: SizedBox(
              width: 300, // Force 300px width
              child: _buildSearchBox(),
            ),
          ),

          // Content Area
          AnimatedPositioned(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            top: isIdle ? size.height * 0.42 + 90 : (isPosts ? 0.0 : kToolbarHeight + 80.0),
            left: 0,
            right: 0,
            bottom: 0,
            child: _view == _SearchView.results
                ? _buildCreatorsList()
                : _view == _SearchView.userPosts
                ? _buildPostsView()
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── Post Detail Screen ──

  Widget _buildPostDetailScreen() {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF08080d),
        appBar: InnerAppBar(onBack: _goBack, title: 'Loading...'),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF9C27B0))),
      );
    }

    if (_postDetail == null || _error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF08080d),
        appBar: InnerAppBar(onBack: _goBack),
        body: Center(child: Text(_error ?? 'Post not found', style: const TextStyle(color: Colors.white70))),
      );
    }

    final p = _postDetail!;
    final svc = _getSvc(p.service);

    return Scaffold(
      backgroundColor: const Color(0xFF08080d),
      appBar: InnerAppBar(onBack: _goBack, title: p.title),
      body: CustomScrollView(
        slivers: [
          // 1. Header Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta Badges
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: svc.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(svc.icon, size: 14, color: svc.color),
                            const Gap(5),
                            Text(svc.label, style: TextStyle(color: svc.color, fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const Gap(12),
                      Icon(Icons.calendar_today_rounded, size: 13, color: Colors.white.withOpacity(0.3)),
                      const Gap(4),
                      Text(p.published.split('T').first, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                    ],
                  ),

                  // Text Content
                  if (p.content.isNotEmpty) ...[
                    const Gap(20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: SelectableText(
                        _stripHtml(p.content),
                        style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
                      ),
                    ),
                  ],

                  // Prev / Next Pills
                  if (p.prev != null || p.next != null) ...[
                    const Gap(24),
                    Row(
                      children: [
                        if (p.prev != null)
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _loadPostDetail(p.service, p.user, p.prev!),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.arrow_upward_rounded, color: Colors.white54, size: 18),
                                      Gap(8),
                                      Text('Previous Post', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (p.prev != null && p.next != null) const Gap(12),
                        if (p.next != null)
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _loadPostDetail(p.service, p.user, p.next!),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Next Post', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w500)),
                                      Gap(8),
                                      Icon(Icons.arrow_downward_rounded, color: Colors.white54, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const Gap(20),
                  Text('Attachments (${p.attachments.length})', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const Gap(12),
                ],
              ),
            ),
          ),

          // 2. Attachments Grid
          if (p.attachments.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 250,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final att = p.attachments[index];
                    final path = att['path'] as String? ?? '';
                    final name = att['name'] as String? ?? 'file';
                    final imgUrl = '$_thumbCdn$path';
                    final fullUrl = '$_fileCdn$path';

                    return GestureDetector(
                      onTap: () => _openImage(fullUrl, name),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: imgUrl,
                              fit: BoxFit.cover,
                              errorWidget: (c, u, e) => Container(
                                color: Colors.white10,
                                child: const Icon(Icons.broken_image, color: Colors.white24),
                              ),
                            ),
                            // Gradient overlay for text
                            Positioned(
                              left: 0, right: 0, bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                                  ),
                                ),
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: p.attachments.length,
                ),
              ),
            ),

          // Space for the bottom download bar
          if (p.attachments.isNotEmpty) const SliverPadding(padding: EdgeInsets.only(bottom: 90)),
          const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
        ],
      ),

      // 3. Modern Frosted Bottom Download Bar
      bottomNavigationBar: p.attachments.isNotEmpty
          ? Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e).withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, spreadRadius: 2),
          ],
        ),
        child: _isDownloading
            ? Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saving file $_currentFileIndex of $_totalFiles',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Text(
                  '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Gap(10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _downloadProgress,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(svc.color),
              ),
            ),
          ],
        )
            : GestureDetector(
          onTap: _downloadAll,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [svc.color.withOpacity(0.8), svc.color]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.download_rounded, color: Colors.white, size: 20),
                Gap(10),
                Text('Download All Files', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      )
          : null,
    );
  }

  Future<void> _openImage(String url, String name) async {
    ImageMeta im = ImageMeta(
      fileTypeExtension: p.extension(url),
      fullNetworkPath: url,
    );
    await im.parseNetworkImage();
    await im.makeImage(makeThumbnail: true);
    if(!mounted) return;
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => ImageView(imageMeta: im)));
  }

  // ── Search Box ──

  Widget _buildSearchBox() {
    final glow = _isHovering || _hasFocus;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: glow ? const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFF2196F3), Color(0xFF00BCD4)]) : LinearGradient(colors: [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.04)]),
          boxShadow: glow
              ? [BoxShadow(color: const Color(0xFF9C27B0).withOpacity(0.25), blurRadius: 40), BoxShadow(color: const Color(0xFF2196F3).withOpacity(0.2), blurRadius: 60, spreadRadius: 5)]
              : [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20)],
        ),
        padding: const EdgeInsets.all(2),
        child: Container(
          decoration: BoxDecoration(color: const Color(0xFF0e0e18), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              const Gap(16),
              const Icon(Icons.search_rounded, color: Colors.white38, size: 22),
              const Gap(12),
              Expanded(
                child: Focus(
                  onFocusChange: (v) => setState(() => _hasFocus = v),
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    cursorColor: const Color(0xFF9C27B0),
                    decoration: InputDecoration(
                      hintText: 'Search local creators...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      isDense: true,
                      suffixIcon: _searchCtrl.text.isNotEmpty ? GestureDetector(onTap: () { _searchCtrl.clear(); _onSearchChanged(''); }, child: const Icon(Icons.close_rounded, color: Colors.white30, size: 18)) : null,
                    ),
                  ),
                ),
              ),
              if (_searchCtrl.text.isEmpty) const Gap(16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatorsList() {
    return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
          child: CustomMasonryView(
            itemRadius: 14,
            itemPadding: 4,
            listOfItem: _creators,
            numberOfColumn: (MediaQuery.of(context).size.width / 500).round(),
            itemBuilder: (ii) {
              return AspectRatio(aspectRatio: 16/9, child: _buildCreatorCard(ii.item));
            },
          ),
        )
    );
  }

  Widget _buildCreatorCard(Leak c) {
    final svc = _getSvcEnum(c.service);
    final avatarUrl = 'https://pawchive.pw/icons/${svc.label.toLowerCase()}/${c.id}';
    final bannerUrl = 'https://pawchive.pw/banners/${svc.label.toLowerCase()}/${c.id}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _loadUserPosts(c),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: AspectRatio(aspectRatio: 4/1, child: CachedNetworkImage(
                    imageUrl: bannerUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (c, u, e) => Container(height: 60, color: svc.color.withOpacity(0.15)),
                  )),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -20),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Color(0xFF08080d), shape: BoxShape.circle),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: avatarUrl,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorWidget: (c, u, e) => Container(width: 44, height: 44, color: svc.color.withOpacity(0.2), child: Icon(svc.icon, size: 20, color: svc.color)),
                            ),
                          ),
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Transform.translate(
                          offset: const Offset(0, -10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const Gap(4),
                              Row(
                                children: [
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: svc.color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)), child: Text(svc.label, style: TextStyle(color: svc.color, fontSize: 9, fontWeight: FontWeight.w700))),
                                  const Gap(8),
                                  Text(_relTime(c.updated), style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -10),
                        child: Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.15)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Posts Grid View (Unified) ──

  Widget _buildPostsView() {
    final leak = _selectedLeak;
    if (leak == null) return const SizedBox.shrink();
    final svc = _getSvcEnum(leak.service);

    return CustomScrollView(
      controller: _postsScrollController, // Attach scroll listener for infinite scroll
      slivers: [
        SliverToBoxAdapter(
          child: _buildHeader(
            leak,
            svc,
            _posts.length,
          ),
        ),

        if (_isLoading && _posts.isEmpty) // Initial load spinner
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator(color: Color(0xFF9C27B0))),
          )
        else if (_posts.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildMessageState(
              icon: Icons.article_outlined,
              title: 'No posts found',
              subtitle: 'Nothing found in database or API',
              iconColor: Colors.white24,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                childAspectRatio: 0.72,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final p = _posts[index];
                  final path = p.attachments?.isNotEmpty == true ? p.attachments!.first.path : null;

                  return _GridCard(
                    thumbUrl: path != null ? '$_thumbCdn$path' : null,
                    title: p.title.isNotEmpty ? p.title : 'Untitled',
                    svc: svc,
                    hasFull: p.hasFull,
                    onTap: () => _loadPostDetail(p.service.name.toLowerCase(), p.user, p.id),
                  );
                },
                childCount: _posts.length,
              ),
            ),
          ),

        // Infinite Scroll loading indicator
        if (_isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9C27B0))),
              ),
            ),
          ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  Widget _buildHeader(Leak leak, ServiceInfo svc, int postCount) {
    final bannerUrl = 'https://pawchive.pw/banners/${svc.label.toLowerCase()}/${leak.id}';
    final avatarUrl = 'https://pawchive.pw/icons/${svc.label.toLowerCase()}/${leak.id}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AspectRatio(aspectRatio: 4/1, child: Container(
              width: double.infinity, color: svc.color.withOpacity(0.1),
              child: CachedNetworkImage(imageUrl: bannerUrl, fit: BoxFit.cover,
                errorWidget: (c,u,e) => Center(child: Icon(svc.icon, size: 48, color: svc.color.withOpacity(0.4))),
              ),
            )),
            Positioned(bottom: -32, left: 28,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Color(0xFF08080d), shape: BoxShape.circle),
                child: ClipOval(
                  child: CachedNetworkImage(imageUrl: avatarUrl, width: 68, height: 68, fit: BoxFit.cover,
                    errorWidget: (c,u,e) => Container(width: 68, height: 68, color: svc.color.withOpacity(0.2), child: Icon(svc.icon, size: 28, color: svc.color)),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 42),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(leak.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              const Gap(8),
              Row(
                children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: svc.color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)), child: Text(svc.label, style: TextStyle(color: svc.color, fontSize: 11, fontWeight: FontWeight.w700))),
                  const Gap(12),
                  Text('$postCount Posts', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                ],
              ),
              const Gap(16),
              const Divider(color: Colors.white10, height: 1),
              const Gap(12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageState({required IconData icon, required String title, required String subtitle, required Color iconColor}) {
    return Center(child: Padding(padding: const EdgeInsets.all(40), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: iconColor, size: 48), const Gap(16),
      Text(title, style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500)),
      const Gap(6),
      Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
    ])));
  }
}

// ── Grid Card Widget ────────────────────────────────────────────────────────

class _GridCard extends StatelessWidget {
  final String? thumbUrl;
  final String title;
  final ServiceInfo svc;
  final bool hasFull;
  final VoidCallback onTap;

  const _GridCard({required this.thumbUrl, required this.title, required this.svc, required this.hasFull, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: thumbUrl != null
                  ? CachedNetworkImage(imageUrl: thumbUrl!, fit: BoxFit.cover,
                errorWidget: (c, u, e) => Container(color: Colors.white10, child: const Icon(Icons.broken_image, color: Colors.white24)),
              )
                  : Container(color: Colors.white.withOpacity(0.05), child: Icon(Icons.text_snippet_rounded, color: Colors.white.withOpacity(0.1))),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: title == 'Untitled' ? Colors.white38 : Colors.white70, fontSize: 12, fontWeight: title == 'Untitled' ? FontWeight.w400 : FontWeight.w600, fontStyle: title == 'Untitled' ? FontStyle.italic : FontStyle.normal)),
                  const Gap(4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: svc.color.withOpacity(0.1), borderRadius: BorderRadius.circular(3)),
                        child: Text(svc.label, style: TextStyle(color: svc.color.withOpacity(0.8), fontSize: 8, fontWeight: FontWeight.w700)),
                      ),
                      if (hasFull)
                        const Icon(Icons.check_circle, color: Colors.green, size: 14),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final double opacity;
  const _GridPainter({this.opacity = 0.03});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(opacity)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 40) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += 40) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => oldDelegate.opacity != opacity;
}