import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cimagen/components/Animations.dart';
import 'package:cimagen/main.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:gap/gap.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../Utils.dart';
import '../../constants.dart';
import '../../modules/ConfigManager.dart';
import '../../utils/ImageManager.dart';
import 'ImageView.dart';

class E621Search extends StatefulWidget {

  const E621Search({super.key});

  @override
  State<E621Search> createState() => _E621SearchState();
}

class _E621SearchState extends State<E621Search> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<E621Post> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _limit = 75;
  String _lastQuery = '';

  Future<void> _performSearch(bool reset) async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    if (reset) {
      _posts.clear();
      _currentPage = 1;
      _hasMore = true;
      _lastQuery = _searchController.text;
    }

    try {
      final result = await sqLite.searchPosts(_lastQuery, _currentPage, _limit);
      final List<E621Post> newPosts = result['posts'] as List<E621Post>;
      _hasMore = result['hasMore'] as bool;

      setState(() {
        _posts.addAll(newPosts);
      });

      _currentPage++;
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoading && _hasMore) {
        _performSearch(false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 400,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Enter search query (e.g., "cat rating:s score:>10")',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _performSearch(true),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _performSearch(true),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = (constraints.maxWidth / 180).floor();
              return AlignedGridView.count(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                itemCount: _posts.length + (_isLoading ? 1 : 0),
                mainAxisSpacing: 3,
                crossAxisSpacing: 3,
                crossAxisCount: crossAxisCount,
                itemBuilder: (context, index) {
                  if (index == _posts.length) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final post = _posts[index];
                  final String cacheDir = kBaseNavigatorKey.currentContext!.read<ConfigManager>().imagesCacheDir;
                  final String localPath = '$cacheDir/${post.md5}.jpg';
                  final File file = File(localPath);

                  Widget imageWidget;
                  if(post.isDeleted){
                    imageWidget = DottedBorder(
                      options: RoundedRectDottedBorderOptions(
                        dashPattern: const [6, 6],
                        color: Colors.grey,
                        strokeWidth: 2,
                        radius: const Radius.circular(4),
                      ),
                      child: Padding(padding: const EdgeInsets.all(8), child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                          const Text('Well...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const Gap(8),
                          Text('This post has been deleted', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                          SelectableText(post.md5, style: const TextStyle(color: Colors.grey, fontSize: 8))
                        ],
                      )),
                    );
                  } else if(post.fileExt == 'swf'){
                    imageWidget = DottedBorder(
                      options: RoundedRectDottedBorderOptions(
                        dashPattern: const [6, 6],
                        color: Colors.grey,
                        strokeWidth: 2,
                        radius: const Radius.circular(4),
                      ),
                      child: Padding(padding: const EdgeInsets.all(8), child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.image_search_sharp, color: Colors.white, size: 28),
                          const Text('Flash Player', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Container(
                            color: Color(0xffb30f12),
                            height: 2,
                            width: 28,
                          ),
                          const Gap(8),
                          Text('You need Flash Player (no)', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                          SelectableText(post.md5, style: const TextStyle(color: Colors.grey, fontSize: 8))
                        ],
                      )),
                    );
                  } else if (file.existsSync()) {
                    imageWidget = Image.file(file, gaplessPlayback: true);
                  } else {
                    downloadPreview(post, cacheDir);
                    imageWidget = CachedNetworkImage(
                      imageUrl: post.previewUrl,
                      imageBuilder: (context, imageProvider) {
                        return Image(image: imageProvider, gaplessPlayback: true);
                      },
                      progressIndicatorBuilder: (context, url, downloadProgress) => Shimmer.fromColors(
                        baseColor: Colors.transparent,
                        highlightColor: Colors.white.withAlpha(90),
                        period: const Duration(seconds: 4),
                        child: AspectRatio(aspectRatio: post.width / post.height),
                      ),
                      errorWidget: (context, url, error) => Padding(padding: const EdgeInsets.all(8), child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.orange, size: 28),
                          const Text('Error', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const Gap(8),
                          SelectableText(error.toString(), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                          SelectableText(post.md5.toString(), style: const TextStyle(color: Colors.grey, fontSize: 10))
                        ],
                      )),
                    );//Image.network(post.previewUrl, fit: BoxFit.cover, gaplessPlayback: true);
                  }

                  bool isAnimation = ['gif', 'mp4', 'webm', 'webp'].contains(post.fileExt);
                  bool some = isAnimation;

                  return GestureDetector(
                      onTap: () async {
                        if(post.isDeleted){
                          showDialog<String>(
                            context: context,
                            builder: (BuildContext context) => AlertDialog(
                              icon: const Icon(Icons.delete),
                              iconColor: Colors.white,
                              title: const Text('Ooppsss...'),
                              content: Text('This post has been deleted'),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: (){
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Okay'),
                                ),
                              ],
                            ),
                          );
                          return;
                        }
                        if(!isImage(post.fileExt)){
                          showDialog<String>(
                            context: context,
                            builder: (BuildContext context) => AlertDialog(
                              icon: const Icon(Icons.file_open),
                              iconColor: Colors.yellow,
                              title: const Text('Ooppsss...'),
                              content: Text('We cannot open this type of file at this time'),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: (){
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Okay'),
                                ),
                              ],
                            ),
                          );
                          return;
                        }
                        showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            content: LinearProgressIndicator(),
                          ),
                        );

                        ImageMeta im = ImageMeta(
                          fileTypeExtension: post.fileExt,
                          fullNetworkPath: post.fullUrl,
                        );

                        try{
                          await im.parseNetworkImage();
                          await im.makeImage(makeThumbnail: true);
                          if(!mounted) return;
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ImageView(imageMeta: im)));
                        } catch (e){
                          Navigator.pop(context);
                          showDialog<String>(
                            context: context,
                            builder: (BuildContext context) => AlertDialog(
                              icon: const Icon(Icons.error_outline),
                              iconColor: Colors.redAccent,
                              title: const Text('Ooppsss...'),
                              content: SelectableText('Error: $e'),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: (){
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Okay'),
                                ),
                              ],
                            ),
                          );
                          rethrow;
                        }
                        //Navigator.push(context, MaterialPageRoute(builder: (context) => ImageView(imageMeta: imageMeta))
                      },
                      child: AspectRatio(
                        aspectRatio: post.width / post.height,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Stack(
                              alignment: Alignment.topRight,
                              children: [
                                imageWidget,
                                if(some) Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                              colors: [
                                                Color.fromRGBO(0, 0, 0, 0.0),
                                                Color.fromRGBO(0, 0, 0, 0.4),
                                                Color.fromRGBO(0, 0, 0, 0.8)
                                              ],
                                              stops: [0, 0.2, 1.0],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if(isAnimation) ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: BackdropFilter(
                                                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // Blur for Hi-Res tag
                                                child: Container(
                                                  padding: const EdgeInsets.only(left: 2, right: 2, bottom: 1),
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(4),
                                                    color: (const Color(0xffa69955)).withOpacity(0.2),
                                                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
                                                  ),
                                                  child: Text(
                                                    post.fileExt,
                                                    style: TextStyle(
                                                      color: const Color(0xfff5e7c4),
                                                      fontSize: 12,
                                                      shadows: [Shadow(blurRadius: 1, color: Colors.black.withOpacity(0.3))],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                          ],
                                        )
                                    )
                                ),
                              ]
                            )
                          )
                        )
                      )
                  );
                },
              );
            }
          )
        ),
      ],
    );
  }
}

class E621Post {
  final int id;
  final int uploaderID;
  final String createdAt;
  final String md5;
  final String? source;
  final String rating;
  final int width;
  final int height;
  final List<String> tags;
  final List<String> lockedTags;
  final int favCount;
  final String fileExt;
  final int? parentID;
  final int changeSeq;
  final int? approverID;
  final int fileSize;
  final int commentCount;
  final String? description;
  final dynamic duration;
  final String updatedAt;
  final bool isDeleted;
  final bool isPending;
  final bool isFlagged;
  final int score;
  final int upScore;
  final int downScore;
  final bool isRatingLocked;
  final bool isStatusLocked;
  final bool isNoteLocked;

  const E621Post({
    required this.id,
    required this.uploaderID,
    required this.createdAt,
    required this.md5,
    this.source,
    required this.rating,
    required this.width,
    required this.height,
    required this.tags,
    required this.lockedTags,
    required this.favCount,
    required this.fileExt,
    this.parentID,
    required this.changeSeq,
    this.approverID,
    required this.fileSize,
    required this.commentCount,
    this.description,
    this.duration,
    required this.updatedAt,
    this.isDeleted = false,
    this.isPending = false,
    this.isFlagged = false,
    required this.score,
    required this.upScore,
    required this.downScore,
    this.isRatingLocked = true,
    this.isStatusLocked = false,
    this.isNoteLocked = true
  });

  factory E621Post.fromMap(Map<String, dynamic> map) {
    return E621Post(
      id: map['id'] as int,
      uploaderID: map['uploader_id'] as int,
      createdAt: map['created_at'] as String,
      md5: map['md5'] as String,
      source: map['source'] as String?,
      rating: map['rating'] as String,
      width: map['image_width'] as int,
      height: map['image_height'] as int,
      tags: (map['tag_string'] as String).split(' ').where((t) => t.isNotEmpty).toList(),
      lockedTags: (map['locked_tags'] as String? ?? '').split(' ').where((t) => t.isNotEmpty).toList(),
      favCount: map['fav_count'] as int,
      fileExt: map['file_ext'] as String,
      parentID: map['parent_id'] as int?,
      changeSeq: map['change_seq'] as int,
      approverID: map['approver_id'] as int?,
      fileSize: map['file_size'] as int,
      commentCount: map['comment_count'] as int,
      description: map['description'] as String?,
      duration: map['duration'],
      updatedAt: map['updated_at'] as String? ?? '',
      isDeleted: (map['is_deleted'] as int) == 1,
      isPending: (map['is_pending'] as int) == 1,
      isFlagged: (map['is_flagged'] as int) == 1,
      score: map['score'] as int,
      upScore: map['up_score'] as int,
      downScore: map['down_score'] as int,
      isRatingLocked: (map['is_rating_locked'] as int) == 1,
      isStatusLocked: (map['is_status_locked'] as int) == 1,
      isNoteLocked: (map['is_note_locked'] as int) == 1,
    );
  }

  String get previewUrl => 'https://static1.e621.net/data/preview/${md5.substring(0, 2)}/${md5.substring(2, 4)}/$md5.jpg';

  String get fullUrl => 'https://static1.e621.net/data/${md5.substring(0, 2)}/${md5.substring(2, 4)}/$md5.$fileExt';
}

Future<void> downloadPreview(E621Post post, String cacheDir) async {
  final dir = Directory(cacheDir);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  final filePath = '$cacheDir/${post.md5}.jpg';
  final file = File(filePath);
  if (await file.exists()) return;

  try {
    final response = await http.get(Uri.parse(post.previewUrl));
    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes);
    }
  } catch (e) {
    // Handle error silently or log
  }
}