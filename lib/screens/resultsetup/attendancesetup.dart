import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:result/drawer/appdrawer.dart';
// 1. IMPORT PDF AND PRINTING PACKAGES
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AttendanceSetup extends StatefulWidget {
  const AttendanceSetup({super.key});

  @override
  State<AttendanceSetup> createState() => _AttendanceSetupState();
}

class _AttendanceSetupState extends State<AttendanceSetup> {
  // --- Selection States ---
  String? selectedYear = '2026';
  String? selectedClass;
  String? selectedSection;
  String? selectedSubject;
  String? selectedExam;
  // --- ADD THESE VARIABLES HERE ---
  String? selectedActivityId;
  String? totalWorkingDaysValue;
  bool _isLoading = true;
  String? currentSetupId;
  // Loaded from fetchSections
  String? selectedClassId;
  String? selectedClassName;
  String? selectedSectionName;
  String? selectedSectionId;
  bool hasSection = false;
  List<dynamic> academicClasses = [];
  List<dynamic> extraActivitiesList = [];
  List<dynamic> examinationsList = [];
  List<dynamic> sectionList = [];
  String? selectedSubjectName;
  bool showAttendanceColumn = false; // Toggle state

  List<dynamic> _students = [];
  // --- Configuration Controllers ---
  final Map<String, TextEditingController> _configControllers = {};

  final List<String> academicYears = List.generate(
    301,
    (index) => (2000 + index).toString(),
  );

  Future<void> fetchClassDataOfAcademicYear() async {
    final prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('saved_host');
    if (host == null) return;

    try {
      var url = Uri.parse("http://$host/resultsetupapi.php").replace(
        queryParameters: {
          'action':
              'fetchClassesByYear', // Ensure this matches your PHP case action name
          'year_name': selectedYear!,
        },
      );

      var res = await http.get(url);
      var response = jsonDecode(res.body);

      // Check if it's formatted as a Map response with a status wrapper
      if (response is Map && response["status"] == "success") {
        setState(() {
          academicClasses = response["data"]; // Safely extract the list
          selectedClass = null; // Reset child dropdowns
          selectedClassId = null;
        });
      } else if (response is List) {
        // Fallback in case your PHP returns a raw list directly
        setState(() {
          academicClasses = response;
          selectedClass = null;
          selectedClassId = null;
        });
      } else {
        print("Server Error: ${response["message"] ?? 'Unknown error'}");
      }
    } catch (e) {
      print("Network Error: $e");
    }
  }

  //fetching the sections
  /// 🔷 FETCH SECTIONS (Called when class changes)
  Future<void> fetchSections(String classId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? host = prefs.getString('saved_host');
      if (host == null) return;

      final response = await http.get(
        Uri.parse(
          "http://$host/systemsetupapi.php?action=get_sections&class_id=$classId",
        ),
      );

      if (response.statusCode == 200) {
        setState(() {
          sectionList = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Error fetching sections: $e");
    }
  }

  //fetching the subjects
  Future<void> fetchSubjects(String classId) async {
    final prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('saved_host');
    if (host == null) return;

    // The 'class_id' is passed as a URL parameter
    var url = Uri.parse(
      "http://$host/resultsetupapi.php?action=fetchExtraActivitiesByClass&class_id=$classId",
    );

    var response = await http.get(url);

    if (response.statusCode == 200) {
      List<dynamic> fetchedList = jsonDecode(response.body);
      setState(() {
        extraActivitiesList = fetchedList;
      });
    } else {
      print("Error fetching subjects");
    }
  }

  //fetch the examination
  Future<void> fetchExaminations() async {
    final prefs = await SharedPreferences.getInstance();

    // Here you are "reading" that saved variable back from the disk
    String? host = prefs.getString('saved_host');
    var url = Uri.parse(
      "http://$host/resultsetupapi.php?action=fetchExaminations",
    );

    var response = await http.get(url);

    if (response.statusCode == 200) {
      print(response.body);
      setState(() {
        examinationsList = jsonDecode(response.body);
      });
    } else {
      print("Error fetching data");
    }
  }

  // --- Dynamic Form Configuration Maps ---
  final Map<String, dynamic> marksConfig = {};

  List<Map<String, dynamic>> studentsDataset = [];
  bool showStudentsTable = false;
  Future<void> _fetchStudents() async {
    final prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('saved_host');
    if (host == null) return;

    debugPrint(
      "Sending params -> Year: $selectedYear, Class: $selectedClassId, Exam: $selectedExam, Activity: $selectedActivityId",
    );

    try {
      var url = Uri.http(host, "/resultsetupapi.php", {
        "action": "fetchActivityStudents",
        "year_id": selectedYear!,
        "class_id": selectedClassId!,
        "section_id":
            (selectedSectionId != null && selectedSectionId!.isNotEmpty)
            ? selectedSectionId!
            : '0',
        "exam_id": (selectedExam != null && selectedExam!.isNotEmpty)
            ? selectedExam!
            : '0',
        "activity_id":
            (selectedActivityId != null && selectedActivityId!.isNotEmpty)
            ? selectedActivityId!
            : '0',
      });

      var res = await http.get(url);
      debugPrint("FETCH BODY: ${res.body}");
      var response = jsonDecode(res.body);

      if (response["status"] == "success") {
        List<dynamic> data = response["data"];

        final setupConfig = response["setup_config"];
        if (setupConfig != null) {
          setState(() {
            totalWorkingDaysValue = setupConfig['total_working_days']
                .toString();
            currentSetupId = setupConfig['setup_id'].toString();

            // Ensure 'totalAttendance' controller exists and update it
            if (!_configControllers.containsKey('totalAttendance')) {
              _configControllers['totalAttendance'] = TextEditingController();
            }
            _configControllers['totalAttendance']?.text =
                totalWorkingDaysValue!;
          });
        } else {
          setState(() {
            currentSetupId = null;
            totalWorkingDaysValue = '';
            if (_configControllers.containsKey('totalAttendance')) {
              _configControllers['totalAttendance']?.text = '';
            }
          });
        }

        setState(() {
          showStudentsTable = false;
        });

        // Dispose old student controllers safely
        for (var student in studentsDataset) {
          student['daysPresentController']?.dispose();
          student['theoryController']?.dispose();
        }

        setState(() {
          _students = data;
          studentsDataset = List.generate(data.length, (index) {
            final s = data[index];
            final existing = s['existing_record'];
            final overallAttendance = s['overall_attendance'];

            final daysPresentController = TextEditingController();
            final theoryController = TextEditingController();
            // 1. Set default text from global overall attendance first
            if (overallAttendance != null) {
              daysPresentController.text = overallAttendance.toString();
            }

            // 2. Check if there is an existing record to override defaults
            bool defaultAbsent = false;
            if (existing != null) {
              defaultAbsent =
                  existing['is_absent'].toString() == '1' ||
                  existing['is_absent'].toString() == 'true';

              // If the activity record specifically has days saved, use that instead,
              // otherwise keep the overall attendance value
              if (existing['days_present'] != null) {
                daysPresentController.text = existing['days_present']
                    .toString();
              }

              theoryController.text =
                  existing['performance_grade']?.toString() ?? '';
            }

            return {
              'sn': index + 1,
              'studentId': s['student_id'].toString(),
              'enrollmentId': s['enrollment_id'].toString(),
              'rollNo': s['roll_number'].toString(),
              'name': s['student_name'].toString(),
              'daysPresentController': daysPresentController,
              'theoryController': theoryController,
              'isAbsent': defaultAbsent,
              'is_absent': defaultAbsent ? 1 : 0,
            };
          });
          showStudentsTable = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Server Error: ${response["message"]}")),
        );
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to load students')));
    }
  }

  Future<void> _saveActivityRecords() async {
    // Removed the currentSetupId == null check so PHP can handle the upsert automatically

    if (studentsDataset.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No students to save.')));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('saved_host');
    if (host == null) return;

    final payload = {
      "year_name": selectedYear,
      "class_id": selectedClassId,
      "section_id": selectedSectionId ?? '0',
      "exam_id": selectedExam,
      "activity_id": selectedActivityId,
      // "total_working_days":
      //     int.tryParse(_configControllers['totalAttendance']?.text ?? '0') ?? 0,
      "students": studentsDataset.map((s) {
        return {
          "enrollment_id": s['enrollmentId'],
          "days_present":
              int.tryParse(s['daysPresentController'].text.trim()) ?? 0,
          "performance_grade": s['theoryController'].text.trim(),
          "is_absent": s['isAbsent'] == true ? 1 : 0,
        };
      }).toList(),
    };

    try {
      var url = Uri.parse(
        "http://$host/resultsetupapi.php?action=saveActivityRecords",
      );
      var res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      debugPrint("SAVE BODY: ${res.body}");
      var response = jsonDecode(res.body);

      if (response["status"] == "success") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(
              child: Text(response["message"] ?? 'Saved successfully!'),
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text("Save failed: ${response["message"]}")),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      debugPrint("Save Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save. Check connection.')),
      );
    }
  }

  // 2. CALL THIS WHEN USER CLICKS "DISPLAY" (NO SAVING/POSTING)
  Future<void> _displayStudentsOnly() async {
    if (selectedYear == null ||
        selectedClassId == null ||
        selectedSectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select year, class and section')),
      );
      return;
    }
    // --- ADD THIS CHECK ---
    if (selectedActivityId == null || selectedExam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select extra activity and examination'),
        ),
      );
      return;
    }
    // ----------------------

    setState(() => _isLoading = true);

    try {
      await _fetchStudents();
    } catch (e) {
      debugPrint("Display Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchExaminations();
    // Initialize the totalAttendance controller
    _configControllers['totalAttendance'] = TextEditingController();
  }

  @override
  void dispose() {
    for (var student in studentsDataset) {
      student['daysPresentController']?.dispose();
      student['gradeController']?.dispose();
    }
    _configControllers.forEach((key, controller) {
      controller.dispose();
    });
    super.dispose();
  }

  Future<void> _saveGlobalAttendanceOnly() async {
    final prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('saved_host');
    if (host == null) return;

    final payload = {
      "year_name": selectedYear,
      "class_id": selectedClassId,
      "section_id": selectedSectionId ?? '0',
      "exam_id": selectedExam,
      "total_working_days":
          int.tryParse(_configControllers['totalAttendance']?.text ?? '0') ?? 0,
      "students": studentsDataset.map((s) {
        return {
          "enrollment_id": s['enrollmentId'],
          "days_present":
              int.tryParse(s['daysPresentController'].text.trim()) ?? 0,
          "is_absent": s['isAbsent'] == true ? 1 : 0,
        };
      }).toList(),
    };

    try {
      var url = Uri.parse(
        "http://$host/resultsetupapi.php?action=saveOverallAttendance",
      );
      var res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      var response = jsonDecode(res.body);
      if (response["status"] == "success") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response["message"] ?? 'Attendance saved globally!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed: ${response["message"]}"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      debugPrint("Attendance Save Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save attendance. Check connection.'),
        ),
      );
    }
  }

  Future<void> _printStudentLedger({
    required List<Map<String, dynamic>> studentsDataset,
    required String className,
    required String sectionName,
    required String subjectName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pw_pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'School Report Management System',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: pw_pdf.PdfColors.indigo900,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Student Mark Entry Ledger | Class: $className - $sectionName | Subject: $subjectName',
              style: const pw.TextStyle(
                fontSize: 12,
                color: pw_pdf.PdfColors.grey700,
              ),
            ),
            pw.Divider(thickness: 1, color: pw_pdf.PdfColors.grey400),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (context) {
          return [
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: pw_pdf.PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: pw_pdf.PdfColors.indigo800,
              ),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: pw_pdf.PdfColors.grey300,
                    width: 0.5,
                  ),
                ),
              ),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              headers: <String>[
                'S.N.',
                'Roll No',
                'Student Name',
                'Theory',
                'Practical',

                'Status',
              ],
              data: studentsDataset.map((student) {
                final bool isAbsent = student['isAbsent'] ?? false;

                // Extract values dynamically from text controllers or map keys
                final String rollNo = '${student['rollNo'] ?? ''}';
                final String name = '${student['name'] ?? ''}';
                final String sn = '${student['sn'] ?? ''}';

                // Read text values safely using safe navigation (?.)
                final TextEditingController? theoryController =
                    student['theoryController'];
                final TextEditingController? practicalController =
                    student['practicalController'];

                final String theory = isAbsent
                    ? '-'
                    : (theoryController?.text.isNotEmpty == true
                          ? theoryController!.text
                          : '0.0');

                final String practical = isAbsent
                    ? '-'
                    : (practicalController?.text.isNotEmpty == true
                          ? practicalController!.text
                          : '0.0');

                return <String>[
                  sn,
                  rollNo,
                  name,
                  theory,
                  practical,
                  isAbsent ? 'Absent' : 'Present',
                ];
              }).toList(),
            ),
          ];
        },
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated via RMS System',
              style: const pw.TextStyle(
                fontSize: 8,
                color: pw_pdf.PdfColors.grey500,
              ),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(
                fontSize: 8,
                color: pw_pdf.PdfColors.grey500,
              ),
            ),
          ],
        ),
      ),
    );

    // Trigger Printing / PDF Preview Dialog
    await Printing.layoutPdf(
      onLayout: (pw_pdf.PdfPageFormat format) async => pdf.save(),
      name: 'Student_Ledger.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Result Management System"),
      ),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- TOP CONFIG PANEL LAYER ---
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Row 1: Dropdowns Configuration
                  Row(
                    children: [
                      Expanded(
                        child: _buildStyledDropdown(
                          label: 'Fiscal Year',
                          value: selectedYear,
                          hint: 'Year',
                          items: academicYears
                              .map(
                                (y) => DropdownMenuItem<String>(
                                  value: y,
                                  child: Text(y),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() => selectedYear = v);
                            fetchClassDataOfAcademicYear();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStyledDropdown(
                          label: 'Select Class',
                          value: selectedClassId,
                          hint: 'Class',
                          items: academicClasses.map((item) {
                            return DropdownMenuItem<String>(
                              value: item['class_id'].toString(),
                              child: Text(
                                item['class_name'].toString().toUpperCase(),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newClassId) {
                            if (newClassId == null) return;

                            setState(() {
                              selectedClassId = newClassId;
                              selectedSubject = null;
                              extraActivitiesList = [];
                            });
                            fetchSubjects(newClassId);

                            var selectedItem = academicClasses.firstWhere(
                              (item) =>
                                  item['class_id'].toString() == newClassId,
                            );

                            setState(() {
                              selectedClassId = newClassId;
                              selectedClassName = selectedItem['class_name']
                                  .toString();
                              selectedSectionId = null;
                              sectionList = [];
                              hasSection =
                                  selectedItem['section']
                                      .toString()
                                      .trim()
                                      .toUpperCase() ==
                                  "YES";

                              if (hasSection) {
                                selectedSectionName = "";
                                fetchSections(newClassId);
                              } else {
                                selectedSectionId = "-";
                                selectedSectionName = "-";
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: _buildStyledDropdown(
                          label: 'Select Section',
                          value: !hasSection ? "-" : selectedSectionId,
                          hint: 'Section',
                          items: !hasSection
                              ? const [
                                  DropdownMenuItem(
                                    value: "-",
                                    child: Text("-"),
                                  ),
                                ]
                              : sectionList.map((sec) {
                                  return DropdownMenuItem<String>(
                                    value: sec['section_id'].toString(),
                                    child: Text(sec['section_name'].toString()),
                                  );
                                }).toList(),
                          onChanged: !hasSection
                              ? null
                              : (val) {
                                  setState(() {
                                    selectedSectionId = val;
                                    var selectedSec = sectionList.firstWhere(
                                      (sec) =>
                                          sec['section_id'].toString() == val,
                                    );
                                    selectedSectionName =
                                        selectedSec['section_name'].toString();
                                  });
                                },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStyledDropdown(
                          label: 'Select Extra Activities',
                          value:
                              extraActivitiesList.any(
                                (s) =>
                                    s['activity_id'].toString() ==
                                    selectedActivityId,
                              )
                              ? selectedActivityId
                              : null,
                          hint: 'Activity',
                          items: extraActivitiesList.map((item) {
                            return DropdownMenuItem<String>(
                              value: item['activity_id'].toString(),
                              child: Text(
                                item['activity_name'].toString().toUpperCase(),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedActivityId = newValue;

                              // Find and save the matching activity name
                              final selectedActivity = extraActivitiesList
                                  .firstWhere(
                                    (sub) =>
                                        sub['activity_id'].toString() ==
                                        newValue,
                                    orElse: () => {},
                                  );
                              selectedSubjectName =
                                  selectedActivity['activity_name'] ?? '';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      //for the terminal exam
                      // --- EXAMINATION ---
                      Expanded(
                        child: _buildStyledDropdown(
                          label: 'Select Examination',
                          value:
                              examinationsList.any(
                                (s) => s['exam_id'].toString() == selectedExam,
                              )
                              ? selectedExam
                              : null,
                          hint: 'Exam',
                          items: examinationsList.map((item) {
                            return DropdownMenuItem<String>(
                              value: item['exam_id'].toString(),
                              child: Text(
                                item['exam_name'].toString().toUpperCase(),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() => selectedExam = newValue);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Row 2: Dynamic FM/PM inputs + Display Buttons
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 180, // Adjust this width as needed
                              child: _buildCompactParamField(
                                'Total Attendance',
                                'totalAttendance',
                              ),
                            ),

                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          _displayStudentsOnly();
                        },
                        icon: const Icon(
                          Icons.search,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Display',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade600,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            showAttendanceColumn = !showAttendanceColumn;
                          });
                        },
                        icon: const Icon(
                          Icons.people_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Attendance',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade600,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- STUDENT LEDGER SECTION ---
            if (showStudentsTable)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Dynamic Header Title
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        color: Colors.grey.shade50,
                        child: Text(
                          'Student Mark Entry Matrix Ledger [${selectedClassName ?? ""} - ${selectedSectionName ?? ""}]',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade900,
                          ),
                        ),
                      ),
                      const Divider(height: 1, thickness: 1),

                      // Render Grid Data Matrix
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowHeight: 48,
                              dataRowMinHeight: 48,
                              dataRowMaxHeight: 56,
                              horizontalMargin: 20,
                              columnSpacing: 48,
                              headingRowColor: WidgetStateProperty.all(
                                Colors.grey.shade100,
                              ),
                              columns: [
                                DataColumn(label: Text('S.N.')),
                                const DataColumn(label: Text('Roll No')),
                                const DataColumn(label: Text('Student Name')),

                                // Conditionally render Attendance Header Column
                                if (showAttendanceColumn)
                                  const DataColumn(
                                    label: Text(
                                      'Attendance',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),

                                const DataColumn(
                                  label: Text('Score / Grade'),
                                ), // Your marks/grades field
                                const DataColumn(label: Text('Absent')),
                              ],

                              rows: studentsDataset.map((student) {
                                // In your database, 1 = absent and 0 = present
                                bool isAbsent =
                                    (student['is_absent'] == 1) ||
                                    (student['is_absent'] == '1') ||
                                    (student['isAbsent'] == true);

                                return DataRow(
                                  // Added row coloring so it turns light red when absent, matching your working code
                                  color:
                                      WidgetStateProperty.resolveWith<Color?>((
                                        Set<WidgetState> states,
                                      ) {
                                        if (isAbsent) return Colors.red.shade50;
                                        return null;
                                      }),
                                  cells: [
                                    DataCell(
                                      Text(
                                        '${student['sn']}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          decoration: isAbsent
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${student['rollNo']}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          decoration: isAbsent
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${student['name']}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          decoration: isAbsent
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ),

                                    // Conditionally render Attendance Input Cell
                                    if (showAttendanceColumn)
                                      DataCell(
                                        SizedBox(
                                          width: 90,
                                          height: 36,
                                          child: TextField(
                                            controller:
                                                student['daysPresentController'],
                                            keyboardType: TextInputType.number,
                                            enabled: !isAbsent,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isAbsent
                                                  ? Colors.grey
                                                  : Colors.black,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: isAbsent
                                                  ? 'Absent'
                                                  : 'Days',
                                              filled: isAbsent,
                                              fillColor: Colors.grey.shade200,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 8,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                    // Grade / Score input cell with Red Background & Strike-through for Absent
                                    DataCell(
                                      Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 100,
                                          minHeight: 48,
                                        ),
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isAbsent
                                              ? Colors.red.shade100
                                              : Colors.transparent,
                                        ),
                                        child: isAbsent
                                            ? Container(
                                                width: double.infinity,
                                                alignment: Alignment.center,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade200,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'ABSENT',
                                                  style: TextStyle(
                                                    color: Colors.red.shade900,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    decoration: TextDecoration
                                                        .lineThrough,
                                                    decorationColor:
                                                        Colors.red.shade900,
                                                    decorationThickness: 2,
                                                  ),
                                                ),
                                              )
                                            : SizedBox(
                                                width: 100,
                                                height: 36,
                                                child: TextField(
                                                  controller:
                                                      student['theoryController'],
                                                  keyboardType:
                                                      TextInputType.text,
                                                  enabled: !isAbsent,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                  decoration: InputDecoration(
                                                    hintText: 'Grade/Marks',
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 8,
                                                        ),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),

                                    // Absent Checkbox
                                    DataCell(
                                      Checkbox(
                                        value:
                                            isAbsent, // This ensures it evaluates to a strict boolean
                                        activeColor: Colors.red.shade600,
                                        onChanged: (bool? val) {
                                          setState(() {
                                            bool checked = val ?? false;
                                            student['isAbsent'] = checked;
                                            student['is_absent'] = checked
                                                ? 1
                                                : 0;

                                            if (checked) {
                                              student['daysPresentController']
                                                  ?.clear();
                                              student['theoryController']
                                                  ?.clear();
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),

                      // Footer Actions Container Block
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade300),
                          ),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(6),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                _printStudentLedger(
                                  className: selectedClassName ?? "Class",
                                  sectionName: selectedSectionName ?? "Section",
                                  subjectName:
                                      selectedSubjectName ??
                                      "Subject", // Passed here
                                  studentsDataset: studentsDataset,
                                );
                              },

                              icon: const Icon(
                                Icons.print,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Print Data',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo.shade700,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            SizedBox(width: 5.0),
                            ElevatedButton.icon(
                              onPressed: () {
                                // Directly save records; the PHP backend will upsert the setup automatically
                                _saveActivityRecords();
                              },
                              icon: const Icon(
                                Icons.save_as,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Save Entries',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo.shade700,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _saveGlobalAttendanceOnly,
                              icon: const Icon(
                                Icons.save_as,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Save Attendance',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo.shade700,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyledDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?>? onChanged,
    String hint = 'Select',
  }) {
    final bool isDisabled = onChanged == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDisabled ? Colors.grey.shade100 : Colors.white,
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              initialValue: value,
              isExpanded: true,
              isDense: true,
              icon: Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: isDisabled ? Colors.grey.shade400 : Colors.black54,
              ),
              hint: Text(
                hint,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: InputBorder.none,
              ),
              style: TextStyle(
                fontSize: 13,
                color: isDisabled ? Colors.grey.shade500 : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactParamField(String label, String mapKey) {
    // Ensure a controller exists for this key
    final controller = _configControllers.putIfAbsent(
      mapKey,
      () => TextEditingController(text: marksConfig[mapKey]?.toString() ?? ''),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: TextFormField(
            controller: controller, // <-- Using the controller here
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              fillColor: Colors.grey.shade50,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            onChanged: (val) {
              // Keep your marksConfig map synchronized as the user types
              marksConfig[mapKey] = val;
            },
          ),
        ),
      ],
    );
  }
}
