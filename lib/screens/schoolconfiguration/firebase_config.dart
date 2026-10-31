import 'package:shared_preferences/shared_preferences.dart';

/// Holds the Firebase project credentials for THIS school's installation.
/// Every school that installs the app will paste in their own Firebase
/// project's config once, and it gets saved here permanently.
class FirebaseConfigStore {
  static String apiKey = '';
  static String appId = '';
  static String messagingSenderId = '';
  static String projectId = '';
  static String authDomain = '';
  static String storageBucket = '';
  static String measurementId = '';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    apiKey = prefs.getString('fb_apiKey') ?? '';
    appId = prefs.getString('fb_appId') ?? '';
    messagingSenderId = prefs.getString('fb_messagingSenderId') ?? '';
    projectId = prefs.getString('fb_projectId') ?? '';
    authDomain = prefs.getString('fb_authDomain') ?? '';
    storageBucket = prefs.getString('fb_storageBucket') ?? '';
    measurementId = prefs.getString('fb_measurementId') ?? '';
  }

  /// True once this device/install has a Firebase project configured.
  static bool get isConfigured => apiKey.isNotEmpty && projectId.isNotEmpty;

  static Future<void> save({
    required String apiKey,
    required String appId,
    required String messagingSenderId,
    required String projectId,
    required String authDomain,
    required String storageBucket,
    String measurementId = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();

    FirebaseConfigStore.apiKey = apiKey;
    FirebaseConfigStore.appId = appId;
    FirebaseConfigStore.messagingSenderId = messagingSenderId;
    FirebaseConfigStore.projectId = projectId;
    FirebaseConfigStore.authDomain = authDomain;
    FirebaseConfigStore.storageBucket = storageBucket;
    FirebaseConfigStore.measurementId = measurementId;

    await prefs.setString('fb_apiKey', apiKey);
    await prefs.setString('fb_appId', appId);
    await prefs.setString('fb_messagingSenderId', messagingSenderId);
    await prefs.setString('fb_projectId', projectId);
    await prefs.setString('fb_authDomain', authDomain);
    await prefs.setString('fb_storageBucket', storageBucket);
    await prefs.setString('fb_measurementId', measurementId);
  }

  /// Wipes the saved Firebase project config for this device. After this,
  /// `isConfigured` becomes false, so the NEXT app launch will show
  /// FirebaseSetupScreen again. Firebase itself can't be "un-initialized"
  /// mid-session, so the app must be fully closed and reopened for this
  /// to take effect.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('fb_apiKey');
    await prefs.remove('fb_appId');
    await prefs.remove('fb_messagingSenderId');
    await prefs.remove('fb_projectId');
    await prefs.remove('fb_authDomain');
    await prefs.remove('fb_storageBucket');
    await prefs.remove('fb_measurementId');

    apiKey = '';
    appId = '';
    messagingSenderId = '';
    projectId = '';
    authDomain = '';
    storageBucket = '';
    measurementId = '';
  }
}
