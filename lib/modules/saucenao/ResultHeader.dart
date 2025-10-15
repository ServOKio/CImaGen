import 'package:json_annotation/json_annotation.dart';

part 'ResultHeader.g.dart';

@JsonSerializable()
class ResultHeader {
  ResultHeader(this.similarity, this.thumbnail, this.index_id, this.index_name, this.dupes, this.hidden);

  final String similarity;
  final String thumbnail;
  final int index_id;
  final String index_name;
  final int dupes;
  final int hidden;

  factory ResultHeader.fromJson(Map<String, dynamic> json) => _$ResultHeaderFromJson(json);

  Map<String, dynamic> toJson() => _$ResultHeaderToJson(this);

// "similarity": "61.86",
// "thumbnail": "https://img3.saucenao.com/booru/2/2/222ed0525c3c4f69fcc3c6faf8fc2a3c_6.jpg?auth=OHB3niKx7_T7JtHnd3588w&exp=1759258800",
// "index_id": 29,
// "index_name": "Index #29: e621.net - 222ed0525c3c4f69fcc3c6faf8fc2a3c_6.jpg",
// "dupes": 0,
// "hidden": 0
}