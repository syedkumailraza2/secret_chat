import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Face ID / Touch ID / fingerprint gate via local_auth.
class BiometricService {
  BiometricService._();
  static final instance = BiometricService._();

  final _auth = LocalAuthentication();

  /// True while a system auth prompt is showing (from anywhere in the app),
  /// so the lock gate can ignore the lifecycle changes it causes.
  bool get inProgress => _inProgress;
  bool _inProgress = false;

  /// True if the device can authenticate (biometrics or device passcode).
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Prompts the user; returns true on success. Falls back to the device
  /// passcode when biometrics are unavailable or fail.
  Future<bool> authenticate({String reason = 'Unlock Luna'}) async {
    _inProgress = true;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    } on MissingPluginException {
      return false;
    } finally {
      // Trailing inactive→resumed events from the system sheet arrive
      // just after the result; keep the flag up briefly to cover them.
      Future<void>.delayed(const Duration(milliseconds: 400), () => _inProgress = false);
    }
  }
}
