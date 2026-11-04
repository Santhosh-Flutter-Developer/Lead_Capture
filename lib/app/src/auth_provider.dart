import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/services/services.dart';
import '/views/views.dart';
import '/utils/utils.dart';

const _channel = MethodChannel('runtime.check');

class AuthProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  Widget? _homeWidget;

  bool get isLoggedIn => _isLoggedIn;
  Widget? get homeWidget => _homeWidget;

  Future<void> checkLoginStatus() async {
    try {
      if (!kIsWeb && kIsWindows) {
        final currentVersion =
            '${AppPackageInfo.version}+${AppPackageInfo.buildNumber}';
        final lastVersion = await Spdb.getLastRunAppVersion();
        if (lastVersion != currentVersion) {
          await Spdb.clearLoginSession();
          await Spdb.setLastRunAppVersion(currentVersion);
        }
      }

      var isLogin = await Spdb.checkLogin();

      bool isUpdateNeed = VersionService.version?.isUpdateNeed ?? false;

      if (!isUpdateNeed) {
        // Windows runtime check — only on native Windows, never on web
        if (!kIsWeb && kIsWindows) {
          var isInstalled = await runtimeInstalled();
          if (!isInstalled) {
            _homeWidget = const RuntimeInstall();
            _isLoggedIn = true;
            notifyListeners();
            return;
          }
        }

        if (isLogin) {
          var isAdmin = await Spdb.isAdminLoggedIn();
          // Refresh cached lookup data (lead/deal statuses, categories,
          // employees, etc.) on every app start for an already-active
          // session. Without this, a returning user only ever sees
          // whatever was cached at their last explicit login (or has to
          // wait for the 6-hour periodic timer / tap manual sync), which
          // is why filter dropdowns can appear empty until a manual sync.
          // Fire-and-forget so app boot isn't blocked on network sync.
          // debugPrint calls are temporary - remove once confirmed working
          // via console/log output.
          debugPrint("AuthProvider: starting startup cache sync...");
          // ignore: discarded_futures
          CacheService.syncAllCollections()
              .then((_) {
                debugPrint("AuthProvider: startup cache sync completed.");
              })
              .catchError((e, st) {
                debugPrint("AuthProvider: startup cache sync FAILED: $e");
              });
          // Initialize static lead statuses
          // Web gets the same sidebar (desktop) layout as native desktop
          if (kIsDesktop || kIsWeb) {
            _homeWidget = RouteScreen();
          } else {
            _homeWidget = MainScreen(isAdmin: isAdmin);
          }
        } else {
          _homeWidget = const Login();
        }
      } else {
        // Update screens — only relevant on native platforms
        if (!kIsWeb) {
          if (kIsWindows) {
            _homeWidget = WindowsUpdate();
          } else if (kIsMobile) {
            // Android update screen (already guarded in the original)
            _homeWidget = AndroidUpdate();
          } else {
            _homeWidget = const Login();
          }
          // For other native platforms (macOS, Linux) fall through to Login
        }
        // On web: version update is handled server-side; skip update screen
      }

      _isLoggedIn = true;
      notifyListeners();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      _homeWidget = const Login();
      _isLoggedIn = true;
      notifyListeners();
    }
  }
}

Future<bool> runtimeInstalled() async {
  try {
    return await _channel.invokeMethod<bool>('isVCRuntimeInstalled') ?? false;
  } catch (e) {
    return false;
  }
}
