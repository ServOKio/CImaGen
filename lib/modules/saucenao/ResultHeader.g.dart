// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ResultHeader.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ResultHeader _$ResultHeaderFromJson(Map<String, dynamic> json) => ResultHeader(
      json['similarity'] as String,
      json['thumbnail'] as String,
      (json['index_id'] as num).toInt(),
      json['index_name'] as String,
      (json['dupes'] as num).toInt(),
      (json['hidden'] as num).toInt(),
    );

Map<String, dynamic> _$ResultHeaderToJson(ResultHeader instance) =>
    <String, dynamic>{
      'similarity': instance.similarity,
      'thumbnail': instance.thumbnail,
      'index_id': instance.index_id,
      'index_name': instance.index_name,
      'dupes': instance.dupes,
      'hidden': instance.hidden,
    };
