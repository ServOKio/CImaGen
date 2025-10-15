// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ResultData.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ResultData _$ResultDataFromJson(Map<String, dynamic> json) => ResultData(
      (json['ext_urls'] as List<dynamic>?)?.map((e) => e as String).toList(),
      json['md_id'] as String?,
      (json['mu_id'] as num?)?.toInt(),
      (json['mal_id'] as num?)?.toInt(),
      (json['e621_id'] as num?)?.toInt(),
      (json['seiga_id'] as num?)?.toInt(),
      json['as_project'] as String?,
      json['source'] as String?,
      (json['hidden'] as num?)?.toInt(),
      json['part'] as String?,
      json['artist'] as String?,
      json['creator'],
      json['author'] as String?,
      json['author_name'] as String?,
      json['author_url'] as String?,
      (json['pixiv_id'] as num?)?.toInt(),
      json['member_name'] as String?,
      (json['member_id'] as num?)?.toInt(),
      json['material'] as String?,
      json['characters'] as String?,
      json['title'] as String?,
      (json['fa_id'] as num?)?.toInt(),
      json['eng_name'] as String?,
      json['jp_name'] as String?,
      json['created_at'] as String?,
      json['tweet_id'] as String?,
      json['twitter_user_id'] as String?,
      json['twitter_user_handle'] as String?,
    );

Map<String, dynamic> _$ResultDataToJson(ResultData instance) =>
    <String, dynamic>{
      'ext_urls': instance.ext_urls,
      'md_id': instance.md_id,
      'mu_id': instance.mu_id,
      'mal_id': instance.mal_id,
      'e621_id': instance.e621_id,
      'seiga_id': instance.seiga_id,
      'as_project': instance.as_project,
      'source': instance.source,
      'hidden': instance.hidden,
      'part': instance.part,
      'artist': instance.artist,
      'creator': instance.creator,
      'author': instance.author,
      'author_name': instance.author_name,
      'author_url': instance.author_url,
      'pixiv_id': instance.pixiv_id,
      'member_name': instance.member_name,
      'member_id': instance.member_id,
      'material': instance.material,
      'characters': instance.characters,
      'title': instance.title,
      'fa_id': instance.fa_id,
      'eng_name': instance.eng_name,
      'jp_name': instance.jp_name,
      'created_at': instance.created_at,
      'tweet_id': instance.tweet_id,
      'twitter_user_id': instance.twitter_user_id,
      'twitter_user_handle': instance.twitter_user_handle,
    };
