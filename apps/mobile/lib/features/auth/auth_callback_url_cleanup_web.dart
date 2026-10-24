import 'package:web/web.dart' as web;

void clearSignupCallbackUrl(String safeUrl) {
  web.window.history.replaceState(null, '', safeUrl);
}
