import 'helpers/ApiInfo.dart';

class GradioClient {
  static String? app_reference;
  static String? hfTokenS;
  String baseUrl = "https://huggingface.co/spaces/";

  Map<String, dynamic> options = {};

  static Future<GradioClient?> connect(String space, {String? hfToken}) async {
    app_reference = space;
    hfTokenS = hfToken;
  }

  Future predict(String s, Map<dynamic, dynamic> map) async {}

  Future<void> init() async {
    if (options['auth'] != null) {
      await resolve_cookies();
    }

    await this
        ._resolve_config()
        .then(({config}) => this._resolve_heartbeat(config));

    this.api_info = await this.view_api();
    this.api_map = map_names_to_ids(this.config?.dependencies || []);
  }
}
