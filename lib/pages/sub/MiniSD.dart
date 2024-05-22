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
  _MiniSDState createState() => _MiniSDState();
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
    // if (hf_token && space_id) {
    //   jwt = await get_jwt(space_id, hf_token);
    // }
    //init();
  }
  //
  // Future<void> init() async {
  //   try {
  //     config = await resolveConfig('${networkAccess.scheme}//${networkAccess.host}', hfToken);
  //     var _config = await configSuccess(config);
  //     res(_config);
  //   } catch (e) {
  //     print(e);
  //     if (spaceID != null) {
  //       checkSpaceStatus(
  //           spaceID,
  //           RE_SPACE_NAME.hasMatch(spaceID!) ? "space_name" : "subdomain",
  //           handleSpaceSucess
  //       );
  //     } else {
  //       if (statusCallback != null) {
  //         statusCallback!({
  //           "status": "error",
  //           "message": "Could not load this space.",
  //           "load_status": "error",
  //           "detail": "NOT_FOUND"
  //         });
  //       }
  //     }
  //   }
  // }
  //
  // Future<void> handleSpaceSucess(status) async {
  //   if (statusCallback != null) {
  //     statusCallback!(status);
  //   }
  //   if (status.status == "running") {
  //     try {
  //       config = await resolveConfig('${networkAccess.scheme}//${networkAccess.host}' ,hfToken);
  //       const _config = await configSuccess(config);
  //       res(_config);
  //     } catch (e) {
  //       console.error(e);
  //       if (status_callback) {
  //         status_callback({
  //           status: "error",
  //           message: "Could not load this space.",
  //           load_status: "error",
  //           detail: "NOT_FOUND"
  //         });
  //       }
  //     }
  //   }
  // }
  //
  // Future<Map<String, dynamic>> configSuccess(Map<String, dynamic>? _config) async {
  //   config = _config;
  //   // LF ,KZNM
  //   apiMap = mapNamesToIds((_config == null ? void 0 : _config.dependencies) || []);
  //   try {
  //     api = await viewApi(config);
  //   } catch (e) {
  //     print('Could not get api details: $e');
  //   }
  //   return {
  //     config,
  //     ...return_obj
  //   };
  // }
  //
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
  //
  // Map mapNamesToIds(List<String> fns) {
  //   var apis = {};
  //   for (final (i, apiName) in fns.indexed) {
  //     if (apiName != null) apis[apiName] = i;
  //   }
  //   return apis;
  // }
  //
  // Future<Map<String, dynamic>> resolveConfig(dynamic fetchImplementation, String? endpoint, String? token) async {
  //   Map<String, dynamic> headers = {};
  //   if (token != null) {
  //     headers['Authorization'] = 'Bearer $token';
  //   }
  //   if (gradioConfig != null) {
  //     String path = gradioConfig!['root'];
  //     var config = gradioConfig;
  //     config!['root'] = endpoint! + config['root'];
  //     return {
  //       ...config,
  //       path: path
  //     };
  //   } else if (endpoint != null) {
  //     Uri? url = Uri.tryParse('$endpoint/config');
  //     Map<String, String> fi = {};
  //     for(String key in headers.keys){
  //       fi[key] = headers[key].toString();
  //     }
  //     http.Response response = await http.get(url!, headers: fi);
  //     if (response.statusCode == 200) {
  //       var config = jsonDecode(response.body);
  //       config['path'] = config.path ?? "";
  //       config['root'] = endpoint;
  //       return config;
  //     }
  //     throw "Could not get config.";
  //   }
  //   throw "No config or app endpoint found";
  // }
  //
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
                          onPressed: () {  },
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

// void submit(dynamic endpoint, dynamic data, dynamic eventData){
//   dynamic fn_index;
//   dynamic api_info;
//   if (endpoint.runtimeType == int) {
//     fn_index = endpoint;
//     api_info = api.unnamed_endpoints[fn_index];
//   } else {
//     String trimmedEndpoint = endpoint.toString().replaceAll(RegExp('/^//'), "");
//     fn_index = apiMap[trimmedEndpoint];
//     api_info = api.named_endpoints[endpoint.trim()];
//   }
// }