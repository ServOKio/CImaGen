import 'ApiInfo.dart';

Map<String, String> determine_protocol(String endpoint) {
  if (endpoint.startsWith("http")) {
    Uri test = Uri.parse(endpoint);

    return {
      'ws_protocol': test.scheme == "https:" ? "wss" : "ws",
      'http_protocol': test.scheme,
      'host': test.host + (test.path != "/" ? test.path : "")
    };
  }

  // default to secure if no protocol is provided

  return {
    'ws_protocol': "wss",
    'http_protocol': "https:",
    'host': Uri.parse(endpoint).host
  };
}


Future<void> resolve_cookies() async {
  // var processed = await process_endpoint(app_reference!, options['hf_token']);
  //
  // try {
  //   if (options['auth'] != null) {
  //     final cookie_header = await get_cookie_header(processed['http_protocol']!, processed['host']!, options.auth, this.fetch, options['hf_token']);
  //     if (cookie_header != null) this.set_cookies(cookie_header);
  //   }
  // } catch (e) {
  //   rethrow;
  // }
}

// get_cookie_header(
// http_protocol: string,
// host: string,
// auth: [string, string],
// _fetch: typeof fetch,
// hf_token?: `hf_${string}`
// ): Promise<string | null> {
// const formData = new FormData();
// formData.append("username", auth?.[0]);
// formData.append("password", auth?.[1]);
//
// let headers: { Authorization?: string } = {};
//
// if (hf_token) {
// headers.Authorization = `Bearer ${hf_token}`;
// }
//
// const res = await _fetch(`${http_protocol}//${host}/${LOGIN_URL}`, {
// headers,
// method: "POST",
// body: formData,
// credentials: "include"
// });
//
// if (res.status === 200) {
// return res.headers.get("set-cookie");
// } else if (res.status === 401) {
// throw new Error(INVALID_CREDENTIALS_MSG);
// } else {
// throw new Error(SPACE_METADATA_ERROR_MSG);
// }
// }