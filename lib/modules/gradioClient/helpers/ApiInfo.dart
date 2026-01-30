import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants.dart';
import 'InitHelpers.dart';

RegExp RE_SPACE_NAME = RegExp(r'/^[a-zA-Z0-9_\-.]+/[a-zA-Z0-9_\-.]+$/');
RegExp RE_SPACE_DOMAIN = RegExp(r'/.*hf\.space/{0,1}.*$/');

Future<Map<String, dynamic>> process_endpoint(String app_reference, String? hf_token) async {
  const headers = { 'Authorization': '' };
  if (hf_token != null) {
    headers['Authorization'] = 'Bearer $hf_token';
  }

  String _app_reference = app_reference.trim().replaceAll(RegExp(r'//$/'), "");

  if (RE_SPACE_NAME.hasMatch(_app_reference)) {
    // app_reference is a HF space name
    try {
      var res = await http.Client().post(Uri.parse('https://huggingface.co/api/spaces/$_app_reference/$HOST_URL'), headers: headers);

      final host = (await json.decode(res.body)).host;

      return {
        'space_id': app_reference,
        ...determine_protocol(host)
      };
    } catch (e) {
      throw Exception(SPACE_METADATA_ERROR_MSG);
    }
  }

  if (RE_SPACE_DOMAIN.hasMatch(_app_reference)) {
    // app_reference is a direct HF space domain
    Map<String, String> protocols = determine_protocol(_app_reference);

    return {
      'space_id': protocols['host']!.split("/")[0].replaceAll(".hf.space", ""),
      'ws_protocol': protocols['ws_protocol']!,
      'http_protocol': protocols['http_protocol']!,
      'host': protocols['host']!
    };
  }

  return {
    'space_id': false,
    ...determine_protocol(_app_reference)
  };

}