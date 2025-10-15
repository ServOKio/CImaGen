import 'package:json_annotation/json_annotation.dart';

import 'ResultData.dart';
import 'ResultHeader.dart';

part 'Result.g.dart';

@JsonSerializable()
class Result {
  Result(this.header, this.data);

  final ResultHeader header;
  final ResultData data;

  factory Result.fromJson(Map<String, dynamic> json) => _$ResultFromJson(json);

  Map<String, dynamic> toJson() => _$ResultToJson(this);
}