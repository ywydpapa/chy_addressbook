import 'dart:io';

class ApiConf {
  static String baseUrl = 'https://chyaddr.chycollege.kr';

  static Future<void> init() async {
    try {
      final addresses = await InternetAddress.lookup('chyaddr.chycollege.kr');
      if (addresses.isNotEmpty) {
        baseUrl = 'https://${addresses.first.address}';
      }
    } catch (e) {
      baseUrl = 'https://112.160.205.167';
    }
  }
}
