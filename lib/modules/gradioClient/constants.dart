String HOST_URL = 'host';
String API_URL = 'predict/';
String SSE_URL_V0 = 'queue/join';
String SSE_DATA_URL_V0 = 'queue/data';
String SSE_URL = 'queue/data';
String SSE_DATA_URL = 'queue/join';
String UPLOAD_URL = 'upload';
String LOGIN_URL = 'login';
String CONFIG_URL = 'config';
String API_INFO_URL = 'info';
String RUNTIME_URL = 'runtime';
String SLEEPTIME_URL = 'sleeptime';
String HEARTBEAT_URL = 'heartbeat';
String COMPONENT_SERVER_URL = 'component_server';
String RESET_URL = 'reset';
String CANCEL_URL = 'cancel';
String APP_ID_URL = 'app_id';

String RAW_API_INFO_URL = 'info?serialize=False';
String SPACE_FETCHER_URL =
    "https://gradio-space-api-fetcher-v2.hf.space/api";
String SPACE_URL = "https://hf.space/{}";

// messages
String QUEUE_FULL_MSG =
    "This application is currently busy. Please try again. ";
String BROKEN_CONNECTION_MSG = "Connection errored out. ";
String CONFIG_ERROR_MSG = "Could not resolve app config. ";
String SPACE_STATUS_ERROR_MSG = "Could not get space status. ";
String API_INFO_ERROR_MSG = "Could not get API info. ";
String SPACE_METADATA_ERROR_MSG = "Space metadata could not be loaded. ";
String INVALID_URL_MSG = "Invalid URL. A full URL path is required.";
String UNAUTHORIZED_MSG = "Not authorized to access this space. ";
String INVALID_CREDENTIALS_MSG = "Invalid credentials. Could not login. ";
String MISSING_CREDENTIALS_MSG =
    "Login credentials are required to access this space.";
String NODEJS_FS_ERROR_MSG =
    "File system access is only available in Node.js environments";
String ROOT_URL_ERROR_MSG = "Root URL not found in client config";
String FILE_PROCESSING_ERROR_MSG = "Error uploading file";