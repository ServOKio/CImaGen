import 'package:json_annotation/json_annotation.dart';

part 'ResultData.g.dart';

@JsonSerializable()
class ResultData {
  ResultData(
      this.ext_urls,
      this.md_id,
      this.mu_id,
      this.mal_id,
      this.e621_id,
      this.seiga_id,
      this.as_project,
      this.source,
      this.hidden,
      this.part,
      this.artist,
      this.creator,
      this.author,
      this.author_name,
      this.author_url,
      this.pixiv_id,
      this.member_name,
      this.member_id,
      this.material,
      this.characters,
      this.title,
      this.fa_id,
      this.eng_name,
      this.jp_name,
      this.created_at,
      this.tweet_id,
      this.twitter_user_id,
      this.twitter_user_handle,
  );

  final List<String>? ext_urls;
  final String? md_id;
  final int? mu_id;
  final int? mal_id;
  final int? e621_id;
  final int? seiga_id;
  final String? as_project;
  final String? source;
  final int? hidden;
  final String? part;
  final String? artist;
  final dynamic creator;
  final String? author;
  final String? author_name;
  final String? author_url;
  final int? pixiv_id;
  final String? member_name;
  final int? member_id;
  final String? material;
  final String? characters;
  final String? title;
  final int? fa_id;
  final String? eng_name;
  final String? jp_name;
  final String? created_at;
  final String? tweet_id;
  final String? twitter_user_id;
  final String? twitter_user_handle;

  factory ResultData.fromJson(Map<String, dynamic> json) => _$ResultDataFromJson(json);

  Map<String, dynamic> toJson() => _$ResultDataToJson(this);
}