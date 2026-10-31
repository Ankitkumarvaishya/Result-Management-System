import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:result/main.dart';
import 'package:result/screens/admissionisetup/promote.dart';

import 'package:result/screens/reportcenters/gradewiseledger.dart';
import 'package:result/screens/reportcenters/individualresult.dart';
import 'package:result/screens/reportcenters/numberwiseledger.dart';
import 'package:result/screens/resultsetup/attendancesetup.dart';
import 'package:result/screens/resultsetup/examsetup.dart';
import 'package:result/screens/resultsetup/extraactivitiessetup.dart';
import 'package:result/screens/resultsetup/markentrysetup.dart';
import 'package:result/screens/resultsetup/prepareresult.dart';
import 'package:result/screens/resultsetup/subjectssetup.dart';
import 'package:result/screens/schoolconfiguration/firebase_config.dart';

import 'package:result/screens/schoolconfiguration/school_config.dart';
import 'package:result/screens/schoolconfiguration/schoolconfiguration.dart';
import 'package:result/screens/systemsetup/academicyearsetup.dart';
import 'package:http/http.dart' as http;
import 'package:result/screens/systemsetup/classsetup.dart';
import 'package:result/screens/admissionisetup/enrollment.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:result/screens/systemsetup/sectionsetup.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/loginscreens/loginscreen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});
  Future<void> downloadFile(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('saved_host');
    final url = "http://$host/systemsetupapi.php?action=backup";
    try {
      var response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        Directory? directory;

        // CHECK PLATFORM FOR PATH
        if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          directory = await getDownloadsDirectory();
        } else if (Platform.isAndroid) {
          directory = await getExternalStorageDirectory();
        }

        // Fallback if the above are null
        directory ??= await getApplicationDocumentsDirectory();
        String formattedDate = DateFormat(
          'yyyy-MM-dd_HH-mm-ss',
        ).format(DateTime.now());
        String fileName = "db_backup_$formattedDate.sql";
        String filePath = "${directory.path}/$fileName";

        File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text("Success! Saved to: $filePath")),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Download Failed"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  //To get logout
  Future<void> _logout(BuildContext context) async {
    try {
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;

      // Navigate back to the Login Screen and clear the navigation stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) =>
            false, // Removes all previous routes so the user can't press back to return
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.blue),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  backgroundImage: SchoolConfig.logoPath != null
                      ? FileImage(File(SchoolConfig.logoPath!))
                      : null,
                  child: SchoolConfig.logoPath == null
                      ? const Icon(Icons.school, color: Colors.blue)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        SchoolConfig.schoolName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        SchoolConfig.address,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        SchoolConfig.phoneNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Simple Item
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MyHomePage(title: "")),
              );
            },
          ),
          // Item with Subitems
          ExpansionTile(
            leading: const Icon(Icons.tune),
            title: const Text('System Setup'),
            children: [
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40.0),
                leading: const Icon(Icons.calendar_month),
                title: const Text('Academic Year Setup'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AcademicYearSetup(),
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40.0),
                leading: const Icon(Icons.school),
                title: const Text('Class Setup'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ClassSetup()),
                  );
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40.0),
                leading: const Icon(Icons.segment),
                title: const Text('Section Setup'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SectionSetup()),
                  );
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40.0),
                leading: const Icon(Icons.backup),
                title: const Text('Backup'),
                onTap: () {
                  downloadFile(context);
                },
              ),
            ],
          ),
          ExpansionTile(
            leading: const Icon(Icons.person_add),
            title: const Text('Admission Setup'),
            children: [
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40.0),
                leading: const Icon(Icons.groups),
                title: const Text('Enrollment'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Enrollment()),
                  );
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40.0),
                leading: const Icon(Icons.upgrade),
                title: const Text('Promote'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Promote()),
                  );
                },
              ),
            ],
          ),
          ExpansionTile(
            leading: const Icon(Icons.grade),
            title: const Text('Result Setup'),
            children: [
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40.0),
                leading: const Icon(Icons.edit_calendar),
                title: const Text('Exam Setup'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Examsetup()),
                  );
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40.0),
                leading: const Icon(Icons.menu_book),
                title: const Text('Subject Setup'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Subjectssetup()),
                  );
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40.0),
                leading: const Icon(Icons.local_activity_rounded),
                title: const Text('Extra Activities Setup'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ExtraActivitiesSetup(),
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40.0),
                leading: const Icon(Icons.fact_check),
                title: const Text('Mark Entry '),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MarkEntrySetup()),
                  );
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40.0),
                leading: const Icon(Icons.how_to_reg),
                title: const Text('Att./Extra Activities Entry'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AttendanceSetup()),
                  );
                },
              ),
            ],
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Prepare Result'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PrepareResult()),
              );
            },
          ),
          ExpansionTile(
            leading: const Icon(Icons.description),
            title: const Text('Report Center'),
            children: [
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40.0),
                leading: const Icon(Icons.print),
                title: const Text('Class Result(Number System)'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => NumberWiseLedger()),
                  );
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40.0),
                leading: const Icon(Icons.print),
                title: const Text('Class Result (Grading System)'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => GradeWiseLedger()),
                  );
                },
              ),

              ListTile(
                contentPadding: const EdgeInsets.only(left: 40.0),
                leading: const Icon(Icons.print),
                title: const Text(
                  'Terminal Individual Result (Grading System)',
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => IndividualResult()),
                  );
                },
              ),
            ],
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_ethernet),
            title: const Text('School Configuration'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SchoolConfigurationScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.local_fire_department_outlined,
              color: Colors.redAccent,
            ),
            title: const Text('Reset Firebase Connection'),
            subtitle: const Text(
              'Disconnect this device from the current Firebase project',
            ),
            onTap: () => _confirmResetFirebase(context),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmResetFirebase(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Firebase Connection?'),
        content: const Text(
          'This will disconnect the app from the current Firebase project. '
          'The app will close, and you\'ll be asked to reconnect to a '
          'Firebase project the next time it opens.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Reset',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await FirebaseConfigStore.clear();

    if (!context.mounted) return;

    // Firebase can't be re-initialized mid-session, so the app needs a
    // full restart for the change to take effect. On desktop/Android this
    // can close the app directly; the user just reopens it.
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Firebase Disconnected'),
        content: const Text(
          'Please reopen the app to connect a new Firebase project.',
        ),
        actions: [
          TextButton(onPressed: () => exit(0), child: const Text('Close App')),
        ],
      ),
    );
  }
}
