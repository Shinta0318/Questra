import 'auth_callback_url_cleanup_stub.dart'
    if (dart.library.js_interop) 'auth_callback_url_cleanup_web.dart'
    as platform;

void clearSignupCallbackUrl(String safeUrl) =>
    platform.clearSignupCallbackUrl(safeUrl);
