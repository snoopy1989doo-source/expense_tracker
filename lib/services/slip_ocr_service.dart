import 'slip_ocr_service_stub.dart'
    if (dart.library.js_util) 'slip_ocr_service_web.dart';

class SlipOCRService {
  static Future<String> runLocalSlipOCR(String base64Str) =>
      parseSlipOCRPlatform(base64Str);
}
