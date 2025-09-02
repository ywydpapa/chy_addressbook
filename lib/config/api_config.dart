import 'dart:io';

class ApiConf {
  static String baseUrl = 'https://lionsaddr.biz-core.co.kr';

  static Future<void> init() async {
    try {
      final addresses = await InternetAddress.lookup('lionsaddr.biz-core.co.kr');
      if (addresses.isNotEmpty) {
        baseUrl = 'https://${addresses.first.address}';
      }
    } catch (e) {
      // lookup 실패 시 기존 도메인 사용
      baseUrl = 'https://112.144.8.104';
    }
  }
}
