import 'package:local_auth/local_auth.dart';

class FaceAuthService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// 返回 true 表示验证成功
  static Future<bool> authenticate() async {
    try {
      // 检查设备是否支持生物识别
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;

      // 弹出面容/指纹验证
      final didAuthenticate = await _auth.authenticate(
        localizedReason: '请使用面容或指纹验证打卡',
      );
      return didAuthenticate;
    } catch (e) {
      return false;
    }
  }
}
