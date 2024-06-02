import 'dart:convert';

import 'package:cimagen/Utils.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'dart:math';
import 'package:http/http.dart' as http;

import '../../main.dart';

class MiniSD extends StatefulWidget{
  ImageMeta? imageMeta;
  MiniSD({ Key? key, this.imageMeta}): super(key: key);

  @override
  State<MiniSD> createState() => _MiniSDState();
}

class _MiniSDState extends State<MiniSD> {
  late String sessionHash;
  Map<String, dynamic> lastStatus = {};
  dynamic config;
  Map<dynamic, dynamic> apiMap = {};
  bool jwt = false;
  dynamic api;
  
  // Other shit
  Map<String, dynamic>? gradioConfig;
  String? spaceID;
  Function? statusCallback;
  // Network
  late Uri networkAccess;
  String? hfToken; // wtf is this shit // бляяя это хайфейс токен я понял
  
  // Shit of shit
  RegExp RE_SPACE_NAME = RegExp(r'^/[^/]*/[^/]*/$');
  
  @override
  void initState(){
    sessionHash = getRandomString(11);
    networkAccess = Uri.parse(prefs!.getString('sd_remote_webui_address') ?? '');
    // if (hfToken != null && spaceID != null) {
    //   jwt = await get_jwt(space_id, hf_token);
    // }
    init();
  }

  Future<void> init() async {
    try {
      config = await resolveConfig('${networkAccess.scheme}://${networkAccess.host}${networkAccess.hasPort ? ':${networkAccess.port}': ''}', hfToken);
      var _config = await configSuccess(config);
      //res(_config);
    } catch (e, stacktrace) {
      print(e);
      print(stacktrace);
      if (spaceID != null) {
        // checkSpaceStatus(
        //     spaceID,
        //     RE_SPACE_NAME.hasMatch(spaceID!) ? "space_name" : "subdomain",
        //     handleSpaceSucess
        // );
      } else {
        if (statusCallback != null) {
          statusCallback!({
            "status": "error",
            "message": "Could not load this space.",
            "load_status": "error",
            "detail": "NOT_FOUND"
          });
        }
      }
    }
  }

  Future<void> handleSpaceSucess(status) async {
    if (statusCallback != null) {
      statusCallback!(status);
    }
    if (status.status == "running") {
      try {
        config = await resolveConfig('${networkAccess.scheme}://${networkAccess.host}${networkAccess.hasPort ? ':${networkAccess.port}': ''}' ,hfToken);
        var _config = await configSuccess(config);
        //res(_config);
      } catch (e, stacktrace) {
        print(e);
        print(stacktrace);
        if (statusCallback != null) {
          statusCallback!({
            'status': "error",
            'message': "Could not load this space.",
            'load_status': "error",
            'detail': "NOT_FOUND"
          });
        }
      }
    }
  }

  Future<Map<String, dynamic>> configSuccess(Map<String, dynamic>? _config) async {
    config = _config;
    // // LF ,KZNM
    // apiMap = mapNamesToIds((_config == null ? void 0 : _config.dependencies) || []);
    // try {
    //   api = await viewApi(config);
    // } catch (e) {
    //   print('Could not get api details: $e');
    // }
    return config;
  }

  // dynamic viewApi(config2) {
  //   if (api){
  //     return api;
  //   }
  //   const headers = { "Content-Type": "application/json" };
  //   if (hfToken != null){
  //     headers['Authorization'] = 'Bearer $hfToken';
  //   }
  //   let response;
  //   if (semiver(config2.version || "2.0.0", "3.30") < 0) {
  //     response = await fetch_implementation(
  //       "https://gradio-space-api-fetcher-v2.hf.space/api",
  //       {
  //         method: "POST",
  //         body: JSON.stringify({
  //           serialize: false,
  //           config: JSON.stringify(config2)
  //         }),
  //         headers
  //       }
  //     );
  //   } else {
  //     response = await fetch_implementation(`${config2.root}/info`, {
  //       headers
  //     });
  //   }
  //   if (!response.ok) {
  //     throw new Error(BROKEN_CONNECTION_MSG);
  //   }
  //   let api_info = await response.json();
  //   if ("api" in api_info) {
  //     api_info = api_info.api;
  //   }
  //   if (api_info.named_endpoints["/predict"] && !api_info.unnamed_endpoints["0"]) {
  //     api_info.unnamed_endpoints[0] = api_info.named_endpoints["/predict"];
  //   }
  //   const x = transform_api_info(api_info, config2, api_map);
  //   return x;
  // }

  Map mapNamesToIds(List<String> fns) {
    var apis = {};
    for (final (i, apiName) in fns.indexed) {
      apis[apiName] = i;
    }
    return apis;
  }

  Future<Map<String, dynamic>> resolveConfig(String? endpoint, String? token) async {
    Map<String, dynamic> headers = {};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (gradioConfig != null) {
      String path = gradioConfig!['root'];
      var config = gradioConfig;
      config!['root'] = endpoint! + config['root'];
      return {
        ...config,
        path: path
      };
    } else if (endpoint != null) {
      Uri? url = Uri.tryParse('$endpoint/config');
      Map<String, String> fi = {};
      for(String key in headers.keys){
        fi[key] = headers[key].toString();
      }
      http.Response response = await http.get(url!, headers: fi);
      if (response.statusCode == 200) {
        var config = jsonDecode(response.body);
        config['path'] = config['path'] ?? "";
        config['root'] = endpoint;
        return config;
      }
      throw "Could not get config.";
    }
    throw "No config or app endpoint found";
  }

  // void checkSpaceStatus(id, String type, Function statusCallback) {
  //   String endpoint = type == "subdomain" ? 'https://huggingface.co/api/spaces/by-subdomain/$id' : 'https://huggingface.co/api/spaces/id';
  //   http.Response response;
  //   let _status;
  //   try {
  //   response = await fetch(endpoint);
  //   _status = response.status;
  //   if (_status !== 200) {
  //   throw new Error();
  //   }
  //   response = await response.json();
  //   } catch (e) {
  //   status_callback({
  //   status: "error",
  //   load_status: "error",
  //   message: "Could not get space status",
  //   detail: "NOT_FOUND"
  //   });
  //   return;
  //   }
  //   if (!response || _status !== 200)
  //   return;
  //   const {
  //   runtime: { stage },
  //   id: space_name
  //   } = response;
  //   switch (stage) {
  //   case "STOPPED":
  //   case "SLEEPING":
  //   status_callback({
  //   status: "sleeping",
  //   load_status: "pending",
  //   message: "Space is asleep. Waking it up...",
  //   detail: stage
  //   });
  //   setTimeout(() => {
  //   check_space_status(id, type, status_callback);
  //   }, 1e3);
  //   break;
  //   case "PAUSED":
  //   status_callback({
  //   status: "paused",
  //   load_status: "error",
  //   message: "This space has been paused by the author. If you would like to try this demo, consider duplicating the space.",
  //   detail: stage,
  //   discussions_enabled: await discussions_enabled(space_name)
  //   });
  //   break;
  //   case "RUNNING":
  //   case "RUNNING_BUILDING":
  //   status_callback({
  //   status: "running",
  //   load_status: "complete",
  //   message: "",
  //   detail: stage
  //   });
  //   break;
  //   case "BUILDING":
  //   status_callback({
  //   status: "building",
  //   load_status: "pending",
  //   message: "Space is building...",
  //   detail: stage
  //   });
  //   setTimeout(() => {
  //   check_space_status(id, type, status_callback);
  //   }, 1e3);
  //   break;
  //   default:
  //   status_callback({
  //   status: "space_error",
  //   load_status: "error",
  //   message: "This space is experiencing an issue.",
  //   detail: stage,
  //   discussions_enabled: await discussions_enabled(space_name)
  //   });
  //   break;
  //   }
  // }

  // void trigger_api_call({int dep_index, var event_data}){
  //   var dep = dependencies[dep_index];
  // const current_status = loading_status.get_status_for_fn(dep_index);
  // messages = messages.filter(({ fn_index }) => fn_index !== dep_index);
  // if (dep.cancels) {
  // await Promise.all(
  // dep.cancels.map(async (fn_index) => {
  // const submission = submit_map.get(fn_index);
  // submission?.cancel();
  // return submission;
  // })
  // );
  // }
  //
  // if (current_status === "pending" || current_status === "generating") {
  // return;
  // }
  //
  // let payload = {
  // fn_index: dep_index,
  // data: dep.inputs.map((id) => instance_map[id].props.value),
  // event_data: dep.collects_event_data ? event_data : null
  // };
  //
  // if (dep.frontend_fn) {
  // dep
  //     .frontend_fn(
  // payload.data.concat(
  // dep.outputs.map((id) => instance_map[id].props.value)
  // )
  // )
  //     .then((v: unknown[]) => {
  // if (dep.backend_fn) {
  // payload.data = v;
  // make_prediction();
  // } else {
  // handle_update(v, dep_index);
  // }
  // });
  // } else {
  // if (dep.backend_fn) {
  // make_prediction();
  // }
  // }
  //
  // function make_prediction(): void {
  // const submission = app
  //     .submit(payload.fn_index, payload.data as unknown[], payload.event_data)
  //     .on("data", ({ data, fn_index }) => {
  // handle_update(data, fn_index);
  // })
  //     .on("status", ({ fn_index, ...status }) => {
  // //@ts-ignore
  // loading_status.update({
  // ...status,
  // status: status.stage,
  // progress: status.progress_data,
  // fn_index
  // });
  // if (
  // !showed_duplicate_message &&
  // space_id !== null &&
  // status.position !== undefined &&
  // status.position >= 2 &&
  // status.eta !== undefined &&
  // status.eta > SHOW_DUPLICATE_MESSAGE_ON_ETA
  // ) {
  // showed_duplicate_message = true;
  // messages = [
  // new_message(DUPLICATE_MESSAGE, fn_index, "warning"),
  // ...messages
  // ];
  // }
  // if (
  // !showed_mobile_warning &&
  // is_mobile_device &&
  // status.eta !== undefined &&
  // status.eta > SHOW_MOBILE_QUEUE_WARNING_ON_ETA
  // ) {
  // showed_mobile_warning = true;
  // messages = [
  // new_message(MOBILE_QUEUE_WARNING, fn_index, "warning"),
  // ...messages
  // ];
  // }
  //
  // if (status.stage === "complete") {
  // dependencies.map(async (dep, i) => {
  // if (dep.trigger_after === fn_index) {
  // trigger_api_call(i);
  // }
  // });
  //
  // submission.destroy();
  // }
  // if (status.broken && is_mobile_device && user_left_page) {
  // window.setTimeout(() => {
  // messages = [
  // new_message(MOBILE_RECONNECT_MESSAGE, fn_index, "error"),
  // ...messages
  // ];
  // }, 0);
  // trigger_api_call(dep_index, event_data);
  // user_left_page = false;
  // } else if (status.stage === "error") {
  // if (status.message) {
  // const _message = status.message.replace(
  // MESSAGE_QUOTE_RE,
  // (_, b) => b
  // );
  // messages = [
  // new_message(_message, fn_index, "error"),
  // ...messages
  // ];
  // }
  // dependencies.map(async (dep, i) => {
  // if (
  // dep.trigger_after === fn_index &&
  // !dep.trigger_only_on_success
  // ) {
  // trigger_api_call(i);
  // }
  // });
  //
  // submission.destroy();
  // }
  // })
  //     .on("log", ({ log, fn_index, level }) => {
  // messages = [new_message(log, fn_index, level), ...messages];
  // });
  //
  // submit_map.set(dep_index, submission);
  // }
  // }

  Future<dynamic> handle_blob2(var endpoint, var data, var api_info, var token) async {
    // const blob_refs = await walk_and_store_blobs(
    //     data,
    //     void 0,
    //     [],
    //     true,
    //     api_info
    // );
    // return Promise.all(
    //     blob_refs.map(async ({ path, blob, data: data2, type }) => {
    //     if (blob) {
    //     const file_url = (await upload_files2(endpoint, [blob], token)).files[0];
    //     return { path, file_url, type };
    //     }
    //     return { path, base64: data2, type };
    //     })
    // ).then((r) => {
    // r.forEach(({ path, file_url, base64, type }) => {
    // if (base64) {
    // update_object(data, base64, path);
    //     } else if (type === "Gallery") {
    //   update_object(data, file_url, path);
    // } else if (file_url) {
    // const o = {
    // is_file: true,
    // name: `${file_url}`,
    // data: null
    // // orig_name: "file.csv"
    // };
    // update_object(data, o, path);
    // }
    // });
    // return data;
    // });
  }

  void submit(var endpoint, var data, var event_data){
    dynamic fn_index;
    dynamic api_info;
    if (endpoint.runtimeType == int) {
      fn_index = endpoint;
      api_info = api.unnamed_endpoints[fn_index];
    } else {
      String trimmedEndpoint = endpoint.toString().replaceAll(RegExp('/^//'), "");
      fn_index = apiMap[trimmedEndpoint];
      api_info = api.named_endpoints[endpoint.trim()];
    }
    if (fn_index.runtimeType != int) {
      throw Exception('There is no endpoint matching that name of fn_index matching that number.');
    }
    var websocket;
    var _endpoint = endpoint.runtimeType == int ? "/predict" : endpoint;
    var payload;
    bool complete = false;
    const listener_map = {}; // TODO
    handle_blob2(
      '${networkAccess.scheme}://${networkAccess.host}${networkAccess.hasPort ? ':${networkAccess.port}': ''}${config['path']}',
      data,
      api_info,
      hfToken
    ).then((_payload){
      payload = { 'data': _payload ?? [], 'event_data': event_data, 'fn_index': fn_index };
    });
  }

  //Text(widget.imageMeta!.fullPath)
  List<String> list = <String>['One', 'Two', 'Three', 'Four'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
            title: const Text('SD'),
            backgroundColor: const Color(0xaa000000),
            elevation: 0,
            actions: []
        ),
        body: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  DropdownButton(
                      items: list.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                      },
                  )
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                            color: Colors.black
                        ),
                        height: MediaQuery.of(context).size.height * 0.30,
                        child: TextField(
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            expands: true,
                            style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 13)
                        ),
                      ),
                      const Gap(8),
                      Container(
                        decoration: BoxDecoration(
                            color: Colors.black
                        ),
                        height: MediaQuery.of(context).size.height * 0.30,
                        child: TextField(
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            expands: true,
                            style: const TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.w400, fontSize: 13)
                        ),
                      )
                    ],
                  )),
                  const Gap(8),
                  Column(
                    children: [
                      ElevatedButton(
                          style: ButtonStyle(
                              foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                              backgroundColor: MaterialStateProperty.all<Color>(Theme.of(context).primaryColor),
                              shape: MaterialStateProperty.all<RoundedRectangleBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))))
                          ),
                          onPressed: () {
                            // var payload = {
                            //   'fn_index': dep_index,
                            //   'data': dep.inputs.map((id) => instance_map[id].props.value),
                            //   'event_data': dep.collects_event_data ? event_data : null
                            // };
                            // submit(payload['fn_index'], payload['data'], payload['event_data']);
                          },
                          child: const Text(
                              "Generate",
                              style: TextStyle(fontSize: 14)
                          )
                      )
                    ],
                  )
                ],
              )
            ],
          )
        )
    );
  }
}