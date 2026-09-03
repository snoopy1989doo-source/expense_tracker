// ignore: avoid_web_libraries_in_flutter
import 'dart:js_util' as js_util;

Future<String> parseSlipOCRPlatform(String base64Str) async {
  try {
    if (js_util.hasProperty(js_util.globalThis, 'parseSlipOCR')) {
      final promise = js_util.callMethod(js_util.globalThis, 'parseSlipOCR', [base64Str]);
      final result = await js_util.promiseToFuture(promise);
      return result?.toString() ?? '';
    }
  } catch (_) {}
  return '';
}
