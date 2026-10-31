import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:result/drawer/appdrawer.dart';
import 'package:result/screens/loginscreens/loginscreen.dart';
import 'package:result/screens/schoolconfiguration/firebase_config.dart';
import 'package:result/screens/schoolconfiguration/firebasesetupscreen.dart';
import 'package:result/screens/schoolconfiguration/school_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SchoolConfig.load();
  await FirebaseConfigStore.load();
  if (FirebaseConfigStore.isConfigured) {
    // This device already has a Firebase project connected from a
    // previous setup -> initialize with those saved values immediately.
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: FirebaseConfigStore.apiKey,
        appId: FirebaseConfigStore.appId,
        messagingSenderId: FirebaseConfigStore.messagingSenderId,
        projectId: FirebaseConfigStore.projectId,
        authDomain: FirebaseConfigStore.authDomain,
        storageBucket: FirebaseConfigStore.storageBucket,
        measurementId: FirebaseConfigStore.measurementId.isEmpty
            ? null
            : FirebaseConfigStore.measurementId,
      ),
    );
    runApp(const MyApp());
  } else {
    // Fresh install, no Firebase project connected yet -> show setup
    // screen first. Once the admin connects it, move into the real app.
    runApp(
      MaterialApp(
        home: FirebaseSetupScreen(
          onConnected: () {
            runApp(const MyApp());
          },
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Result Management System',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

// ==================== RESPONSIVE DASHBOARD SCREEN ====================
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool isLoading = true;
  String activeYear = "Loading...";
  int activeClasses = 0;
  int activeSubjects = 0;
  int activeSections = 0;
  int registeredStudents = 0;
  List<dynamic> classesBreakdown = []; // Holds individual class data
  String errorMessage = "";

  @override
  void initState() {
    super.initState();
    fetchDashboardStats();
  }

  Future<void> fetchDashboardStats() async {
    final prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('saved_host');

    if (host == null) {
      setState(() {
        errorMessage = "Saved host IP not found. Please configure settings.";
        isLoading = false;
      });
      return;
    }

    try {
      var url = Uri.parse(
        "http://$host/dashboardsetupapi.php", // Ensure this matches your exact filename in htdocs
      ).replace(queryParameters: {'action': 'getdashboardstats'});

      var res = await http.get(url);

      // 🔍 DEBUG PRINT: Check your console log to see if it's HTML (404/Error) or JSON
      print("RAW BODY RESPONSE: ${res.body}");

      var response = jsonDecode(res.body);

      if (response is Map && response["status"] == "success") {
        setState(() {
          activeYear = response["year_name"] ?? "N/A";
          activeClasses = response["active_classes"] ?? 0;
          activeSubjects = response["active_subjects"] ?? 0;
          activeSections = response["active_sections"] ?? 0;
          registeredStudents = response["registered_students"] ?? 0;
          classesBreakdown = response["classes_breakdown"] ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              response["message"] ?? "Failed to load dashboard statistics.";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Network/Parsing Error: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                isLoading = true;
                errorMessage = "";
              });
              fetchDashboardStats();
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage.isNotEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                            errorMessage = "";
                          });
                          fetchDashboardStats();
                        },
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = 2;
                  if (constraints.maxWidth > 900) {
                    crossAxisCount = 4;
                  } else if (constraints.maxWidth > 600) {
                    crossAxisCount = 3;
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Active Academic Year Banner
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 20,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.secondary,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.deepPurple.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Center(
                                        child: Text(
                                          SchoolConfig.schoolName,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 30,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                      Center(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons
                                                  .location_city, // or Icons.call
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            const SizedBox(
                                              width: 8,
                                            ), // Adds space between the icon and phone number
                                            Text(
                                              SchoolConfig.address,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Center(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.phone, // or Icons.call
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            const SizedBox(
                                              width: 8,
                                            ), // Adds space between the icon and phone number
                                            Text(
                                              SchoolConfig.phoneNumber,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Center(
                                        child: Text(
                                          "Active Academic Year: $activeYear B.S.",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 25,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Overview Section Header
                          const Text(
                            "Overview Statistics",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Overview Grid View
                          GridView.count(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 1.1,
                            children: [
                              _buildStatCard(
                                context,
                                title: "Active Classes",
                                value: activeClasses.toString(),
                                icon: Icons.class_,
                                color: Colors.blue,
                              ),
                              _buildStatCard(
                                context,
                                title: "Total Subjects",
                                value: activeSubjects.toString(),
                                icon: Icons.book,
                                color: Colors.orange,
                              ),
                              _buildStatCard(
                                context,
                                title: "Active Sections",
                                value: activeSections.toString(),
                                icon: Icons.group_work,
                                color: Colors.green,
                              ),
                              _buildStatCard(
                                context,
                                title: "Registered Students",
                                value: registeredStudents.toString(),
                                icon: Icons.school,
                                color: Colors.purple,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Classes Breakdown Section Header
                          const Text(
                            "Classes Enrollment Breakdown",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Dynamic Classes Grid View
                          classesBreakdown.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Center(
                                    child: Text(
                                      "No classes found for this academic year.",
                                      style: TextStyle(color: Colors.black54),
                                    ),
                                  ),
                                )
                              : GridView.builder(
                                  itemCount: classesBreakdown.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        childAspectRatio: 1.1,
                                      ),
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    var classItem = classesBreakdown[index];
                                    return _buildStatCard(
                                      context,
                                      title:
                                          classItem['class_name'] ??
                                          "Unknown Class",
                                      value:
                                          classItem['student_count']
                                              ?.toString() ??
                                          "0",
                                      icon: Icons.class_,
                                      color: Colors.blue,
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
