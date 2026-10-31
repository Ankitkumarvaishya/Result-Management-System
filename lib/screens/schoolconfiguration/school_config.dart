import 'package:shared_preferences/shared_preferences.dart';

/// Global school configuration.
/// Because every field here is `static`, you can access it from ANY file
/// in your project like this, with no context, no provider, no passing
/// data between screens:
///
///   SchoolConfig.schoolName
///   SchoolConfig.address
///   SchoolConfig.phoneNumber
///   SchoolConfig.logoPath
///
/// Just make sure SchoolConfig.load() has run once (done in main.dart)
/// before you use these values.
class SchoolConfig {
  static String host = '';
  static String schoolName = '';
  static String address = '';
  static String phoneNumber = '';
  static String? logoPath; // local file path to the saved logo image

  /// Call once at app startup (see main.dart) to populate the static
  /// fields from disk.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    host = prefs.getString('saved_host') ?? '';
    schoolName = prefs.getString('school_name') ?? '';
    address = prefs.getString('school_address') ?? '';
    phoneNumber = prefs.getString('school_phone') ?? '';
    logoPath = prefs.getString('school_logo_path');
  }

  /// Call this whenever the configuration screen saves new values.
  /// Updates both the in-memory static fields (instantly available
  /// everywhere) and persists them to disk (survives app restarts).
  static Future<void> save({
    String? host,
    String? schoolName,
    String? address,
    String? phoneNumber,
    String? logoPath,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (host != null) {
      SchoolConfig.host = host;
      await prefs.setString('saved_host', host);
    }
    if (schoolName != null) {
      SchoolConfig.schoolName = schoolName;
      await prefs.setString('school_name', schoolName);
    }
    if (address != null) {
      SchoolConfig.address = address;
      await prefs.setString('school_address', address);
    }
    if (phoneNumber != null) {
      SchoolConfig.phoneNumber = phoneNumber;
      await prefs.setString('school_phone', phoneNumber);
    }
    if (logoPath != null) {
      SchoolConfig.logoPath = logoPath;
      await prefs.setString('school_logo_path', logoPath);
    }
  }
}
