import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SourceFileService {
  static const channel = MethodChannel('arc_reader/source_file');

  static Future<bool> retain(String uri) async {
    if (defaultTargetPlatform != TargetPlatform.android ||
        !uri.startsWith('content://')) {
      return false;
    }
    return await channel.invokeMethod<bool>('retain', {'uri': uri}) ?? false;
  }

  static Future<void> openLocation(String uri) async {
    if (uri.isEmpty) {
      throw PlatformException(
        code: 'SOURCE_UNKNOWN',
        message: '旧作品未记录来源，请先关联原文件。',
      );
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw PlatformException(
        code: 'UNSUPPORTED',
        message: '目前仅支持 Android 的原文件位置定位。',
      );
    }
    await channel.invokeMethod<void>('openLocation', {'uri': uri});
  }
}
