import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:result/screens/schoolconfiguration/school_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:result/drawer/appdrawer.dart';
// 1. IMPORT PDF AND PRINTING PACKAGES
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MarkEntrySetup extends StatefulWidget {
  const MarkEntrySetup({super.key});

  @override
  State<MarkEntrySetup> createState() => _MarkEntrySetupState();
}

class _MarkEntrySetupState extends State<MarkEntrySetup> {
  // --- Selection States ---
  String? selectedYear = '2026';
  String? selectedClass;
  String? selectedSection;
  String? selectedSubject;
  String? selectedExam;
  bool _isLoading = true;
  String? currentSetupId;
  // Loaded from fetchSections
  String? selectedClassId;
  String? selectedClassName;
  String? selectedSectionName;
  String? selectedSectionId;
  bool hasSection = false;
  List<dynamic> academicClasses = [];
  List<dynamic> SubjectsList = [];
  List<dynamic> examinationsList = [];
  List<dynamic> sectionList = [];
  String? selectedSubjectName;

  List<dynamic> _students = [];
  // --- Configuration Controllers ---
  final Map<String, TextEditingController> _configControllers = {};

  // NEW: Dynamically generate years from 2000 to 2300
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
        List decodedList = json.decode(response.body);

        // Use mounted check if this is inside a State object
        if (!mounted) return;

        setState(() {
          sectionList = decodedList;
          if (sectionList.isNotEmpty) {
            selectedSectionId = sectionList[0]['section_id'].toString();
            selectedSectionName = sectionList[0]['section_name'].toString();
          } else {
            selectedSectionId = null;
            selectedSectionName = "";
          }
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
      "http://$host/resultsetupapi.php?action=fetchSubjectsByClass&class_id=$classId",
    );

    var response = await http.get(url);

    if (response.statusCode == 200) {
      List<dynamic> fetchedList = jsonDecode(response.body);
      setState(() {
        SubjectsList = fetchedList;
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

    // Note: _isLoading = true is already handled by the caller (_displayStudentsOnly)
    try {
      var url = Uri.http(host, "/resultsetupapi.php", {
        "action": "fetchStudentsForDisplay",
        "year_name": selectedYear!,
        "class_id": selectedClassId!,
        "section_id": selectedSectionId!,
        "subject_id": (selectedSubject != null && selectedSubject!.isNotEmpty)
            ? selectedSubject!
            : '0',
        "exam_id": (selectedExam != null && selectedExam!.isNotEmpty)
            ? selectedExam!
            : '0',
      });

      var res = await http.get(url);
      debugPrint("FETCH BODY: ${res.body}");
      var response = jsonDecode(res.body);

      if (response["status"] == "success") {
        List<dynamic> data = response["data"];

        // Handle configuration setup state
        final setupConfig = response["setup_config"];
        if (setupConfig != null) {
          setState(() {
            marksConfig['theoryFM'] = setupConfig['theory_fm'].toString();
            marksConfig['theoryPM'] = setupConfig['theory_pm'].toString();
            marksConfig['practicalFM'] = setupConfig['practical_fm'].toString();
            marksConfig['practicalPM'] = setupConfig['practical_pm'].toString();
            marksConfig['totalFM'] = setupConfig['total_fm'].toString();
            marksConfig['totalPM'] = setupConfig['total_pm'].toString();
            currentSetupId = setupConfig['setup_id'].toString();

            _configControllers['theoryFM']?.text = marksConfig['theoryFM']!;
            _configControllers['theoryPM']?.text = marksConfig['theoryPM']!;
            _configControllers['practicalFM']?.text =
                marksConfig['practicalFM']!;
            _configControllers['practicalPM']?.text =
                marksConfig['practicalPM']!;
            _configControllers['totalFM']?.text = marksConfig['totalFM']!;
            _configControllers['totalPM']?.text = marksConfig['totalPM']!;
          });
        } else {
          setState(() {
            currentSetupId = null;
            _configControllers['theoryFM']?.text = '';
            _configControllers['theoryPM']?.text = '';
            _configControllers['practicalFM']?.text = '';
            _configControllers['practicalPM']?.text = '';
            _configControllers['totalFM']?.text = '';
            _configControllers['totalPM']?.text = '';
          });
        }

        // Safely dispose old controllers *after* resetting the UI state pointer,
        // or better yet, check if we can reuse them. To be safe, clear table view first:
        setState(() {
          showStudentsTable =
              false; // Hide table temporarily so UI detaches old controllers safely
        });

        for (var student in studentsDataset) {
          student['theoryController']?.dispose();
          student['practicalController']?.dispose();
        }

        setState(() {
          _students = data;
          studentsDataset = List.generate(data.length, (index) {
            final s = data[index];
            final existing = s['existing_marks'];

            final theoryController = TextEditingController();
            final practicalController = TextEditingController();
            bool isAbsent = false;
            String? computedResult;

            if (existing != null) {
              isAbsent = existing['is_absent'].toString() == '1';
              if (!isAbsent) {
                theoryController.text =
                    existing['theory_marks']?.toString() ?? '';
                practicalController.text =
                    existing['practical_marks']?.toString() ?? '';
              }
              if (existing['result'] != null) {
                computedResult = existing['result'].toString();
              }
            }

            return {
              'sn': index + 1,
              'studentId': s['student_id'].toString(),
              'enrollmentId': s['enrollment_id'].toString(),
              'rollNo': s['roll_number'].toString(),
              'name': s['student_name'].toString(),
              'theoryController': theoryController,
              'practicalController': practicalController,
              'isAbsent': isAbsent,
              'result': computedResult,
            };
          });
          showStudentsTable = true; // Show table back with fresh controllers
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

  Future<void> _saveMarks() async {
    if (currentSetupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No active setup found. Please save configuration or display first.',
          ),
        ),
      );
      return;
    }
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
      "setup_id": currentSetupId,
      "students": studentsDataset.map((s) {
        return {
          "student_id": s['studentId'],
          "theory_marks": s['theoryController'].text.trim(),
          "practical_marks": s['practicalController'].text.trim(),
          "is_absent": s['isAbsent'] == true ? 1 : 0,
        };
      }).toList(),
    };

    try {
      var url = Uri.parse(
        "http://$host/resultsetupapi.php?action=saveMarksEntry",
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
              child: Text('Saved successfully! (${response["saved"]} records)'),
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

  // 1. CALL THIS WHEN USER CLICKS "SAVE CONFIGURATION"
  Future<void> _saveExamSetupOnly() async {
    if (selectedYear == null ||
        selectedClassId == null ||
        selectedSectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select year, class and section')),
      );
      return;
    }
    if (selectedSubject == null || selectedExam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select subject and examination')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('saved_host');
    if (host == null) return;

    setState(() => _isLoading = true);

    final payload = {
      "year_name": selectedYear,
      "class_id": selectedClassId,
      "section_id": selectedSectionId,
      "subject_id": selectedSubject,
      "exam_id": selectedExam,
      "theory_fm":
          double.tryParse(_configControllers['theoryFM']?.text ?? '0') ?? 0,
      "theory_pm":
          double.tryParse(_configControllers['theoryPM']?.text ?? '0') ?? 0,
      "practical_fm":
          double.tryParse(_configControllers['practicalFM']?.text ?? '0') ?? 0,
      "practical_pm":
          double.tryParse(_configControllers['practicalPM']?.text ?? '0') ?? 0,
      "total_fm":
          double.tryParse(_configControllers['totalFM']?.text ?? '0') ??
          0, // <-- Sent to backend
      "total_pm":
          double.tryParse(_configControllers['totalPM']?.text ?? '0') ?? 0,
    };
    try {
      var setupUrl = Uri.parse(
        "http://$host/resultsetupapi.php?action=setupExamSubject",
      );
      var setupRes = await http.post(
        setupUrl,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      var setupResponse = jsonDecode(setupRes.body);

      if (setupResponse["status"] != "success") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Setup failed: ${setupResponse["message"]}")),
        );
      } else {
        currentSetupId = setupResponse["setup_id"].toString();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Exam configuration saved successfully!"),
          ),
        );
      }
    } catch (e) {
      debugPrint("Setup Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save configuration. Check connection.'),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
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
    if (selectedSubject == null || selectedExam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select subject and examination')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Cleanly handles fetching without triggering a setup save POST request
      await _fetchStudents();
    } catch (e) {
      debugPrint("Display Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load student list.')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchExaminations();

    // Initialize a TextEditingController for every configuration key
    marksConfig.forEach((key, value) {
      _configControllers[key] = TextEditingController(text: value.toString());
    });
  }

  @override
  void dispose() {
    for (var student in studentsDataset) {
      student['theoryController']?.dispose();
      student['practicalController']?.dispose();
    }
    // Always dispose controllers to avoid memory leaks
    _configControllers.forEach((key, controller) {
      controller.dispose();
    });
    super.dispose();
  }

  // Future<void> _printStudentLedger({
  //   required List<Map<String, dynamic>> studentsDataset,
  //   required String className,
  //   required String sectionName,
  //   required String subjectName, // Added parameter
  // }) async {
  //   final pdf = pw.Document();

  //   pdf.addPage(
  //     pw.MultiPage(
  //       pageFormat: pw_pdf.PdfPageFormat.a4,
  //       margin: const pw.EdgeInsets.all(32),
  //       header: (context) => pw.Column(
  //         crossAxisAlignment: pw.CrossAxisAlignment.start,
  //         children: [
  //           pw.Text(
  //             'School Report Management System',
  //             style: pw.TextStyle(
  //               fontSize: 18,
  //               fontWeight: pw.FontWeight.bold,
  //               color: pw_pdf.PdfColors.indigo900,
  //             ),
  //           ),
  //           pw.SizedBox(height: 4),
  //           pw.Text(
  //             'Student Mark Entry Ledger | Class: $className - $sectionName | Subject: $subjectName',
  //             style: const pw.TextStyle(
  //               fontSize: 12,
  //               color: pw_pdf.PdfColors.grey700,
  //             ),
  //           ),
  //           pw.Divider(thickness: 1, color: pw_pdf.PdfColors.grey400),
  //           pw.SizedBox(height: 10),
  //         ],
  //       ),
  //       build: (context) {
  //         return [
  //           pw.TableHelper.fromTextArray(
  //             headerStyle: pw.TextStyle(
  //               fontWeight: pw.FontWeight.bold,
  //               fontSize: 10,
  //               color: pw_pdf.PdfColors.white,
  //             ),
  //             headerDecoration: const pw.BoxDecoration(
  //               color: pw_pdf.PdfColors.indigo800,
  //             ),
  //             rowDecoration: const pw.BoxDecoration(
  //               border: pw.Border(
  //                 bottom: pw.BorderSide(
  //                   color: pw_pdf.PdfColors.grey300,
  //                   width: 0.5,
  //                 ),
  //               ),
  //             ),
  //             cellStyle: const pw.TextStyle(fontSize: 10),
  //             cellAlignment: pw.Alignment.centerLeft,
  //             headers: <String>[
  //               'S.N.',
  //               'Roll No',
  //               'Student Name',
  //               'Theory',
  //               'Practical',
  //               'Result',
  //               'Status',
  //             ],
  //             data: studentsDataset.map((student) {
  //               final bool isAbsent = student['isAbsent'] ?? false;

  //               // Extract values dynamically from text controllers or map keys
  //               final String rollNo = '${student['rollNo'] ?? ''}';
  //               final String name = '${student['name'] ?? ''}';
  //               final String sn = '${student['sn'] ?? ''}';

  //               // Read text values safely from controllers if actively typing
  //               final TextEditingController? theoryController =
  //                   student['theoryController'];
  //               final TextEditingController? practicalController =
  //                   student['practicalController'];

  //               final String theory = isAbsent
  //                   ? '-'
  //                   : (theoryController?.text.isEmpty == true
  //                         ? '0.0'
  //                         : theoryController!.text);
  //               final String practical = isAbsent
  //                   ? '-'
  //                   : (practicalController?.text.isEmpty == true
  //                         ? '0.0'
  //                         : practicalController!.text);
  //               final String result = isAbsent
  //                   ? 'ABSENT'
  //                   : (student['result'] ?? '-');

  //               return <String>[
  //                 sn,
  //                 rollNo,
  //                 name,
  //                 theory,
  //                 practical,
  //                 result,
  //                 isAbsent ? 'Absent' : 'Present',
  //               ];
  //             }).toList(),
  //           ),
  //         ];
  //       },
  //       footer: (context) => pw.Row(
  //         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //         children: [
  //           pw.Text(
  //             'Generated via RMS System',
  //             style: const pw.TextStyle(
  //               fontSize: 8,
  //               color: pw_pdf.PdfColors.grey500,
  //             ),
  //           ),
  //           pw.Text(
  //             'Page ${context.pageNumber} of ${context.pagesCount}',
  //             style: const pw.TextStyle(
  //               fontSize: 8,
  //               color: pw_pdf.PdfColors.grey500,
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );

  //   // Trigger Printing / PDF Preview Dialog
  //   await Printing.layoutPdf(
  //     onLayout: (pw_pdf.PdfPageFormat format) async => pdf.save(),
  //     name: 'Student_Ledger.pdf',
  //   );
  // }
  // =============================================================================
  // 1. HELPER: LOAD LOGO BYTES FROM SCHOOL CONFIG
  // =============================================================================
  Future<Uint8List> _loadLogoBytes() async {
    final path = SchoolConfig.logoPath;
    if (path == null || path.isEmpty) {
      return Uint8List(0);
    }
    try {
      final file = File(path);
      if (!await file.exists()) {
        debugPrint("Logo file does not exist at: $path");
        return Uint8List(0);
      }
      return await file.readAsBytes();
    } catch (e) {
      debugPrint("Could not load school logo: $e");
      return Uint8List(0);
    }
  }

  // =============================================================================
  // 2. DYNAMIC SCHOOL HEADER BUILDER
  // =============================================================================
  Future<pw.Widget> _buildPdfHeader({
    String reportTitle = "Student Mark Entry Ledger",
  }) async {
    final logoBytes = await _loadLogoBytes();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logoBytes.isNotEmpty) ...[
              pw.Container(
                width: 60,
                height: 60,
                margin: const pw.EdgeInsets.only(right: 12),
                child: pw.Image(pw.MemoryImage(logoBytes)),
              ),
            ],
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  SchoolConfig.schoolName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  SchoolConfig.address,
                  style: const pw.TextStyle(fontSize: 11),
                ),
                pw.Text(
                  SchoolConfig.phoneNumber,
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 6),
        pw.Text(
          reportTitle,
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }

  // =============================================================================
  // 3. STUDENT MARK ENTRY LEDGER PRINT FUNCTION
  // =============================================================================
  Future<void> _printStudentLedger({
    required List<Map<String, dynamic>> studentsDataset,
    required String className,
    required String sectionName,
    required String subjectName,
  }) async {
    // Guard Clause: Check if the dataset contains valid data
    if (studentsDataset.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No student data available to export.')),
        );
      }
      return;
    }

    final pdf = pw.Document(theme: pw.ThemeData.withFont());

    // Dynamic Header Title including Subject, Class, and Section
    final String dynamicTitle =
        "Student Mark Entry Ledger | Class: $className - $sectionName | Subject: $subjectName";

    final header = await _buildPdfHeader(reportTitle: dynamicTitle);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pw_pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => context.pageNumber == 1 ? header : pw.SizedBox(),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}  •  Generated ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 8, color: pw_pdf.PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: const [
              "S.N.",
              "ROLL NO.",
              "STUDENT NAME",
              "THEORY",
              "PRACTICAL",
              "RESULT",
              "STATUS",
            ],
            data: studentsDataset.asMap().entries.map((entry) {
              final int index = entry.key;
              final Map<String, dynamic> student = entry.value;
              final bool isAbsent = student['isAbsent'] ?? false;

              final String sn = (student['sn'] ?? (index + 1)).toString();
              final String rollNo = (student['rollNo'] ?? '-').toString();
              final String name = (student['name'] ?? '-')
                  .toString()
                  .toUpperCase();

              // Extract values safely from active controllers or raw values
              final TextEditingController? theoryController =
                  student['theoryController'];
              final TextEditingController? practicalController =
                  student['practicalController'];

              final String theory = isAbsent
                  ? '-'
                  : (theoryController?.text.isEmpty == true
                        ? '0.0'
                        : (theoryController?.text ??
                              (student['theory'] ?? '0.0').toString()));

              final String practical = isAbsent
                  ? '-'
                  : (practicalController?.text.isEmpty == true
                        ? '0.0'
                        : (practicalController?.text ??
                              (student['practical'] ?? '0.0').toString()));

              final String result = isAbsent
                  ? 'ABSENT'
                  : (student['result'] ?? '-').toString().toUpperCase();

              return [
                sn,
                rollNo,
                name,
                theory,
                practical,
                result,
                isAbsent ? 'ABSENT' : 'PRESENT',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              color: pw_pdf.PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: pw_pdf.PdfColors.blueGrey800,
            ),
            cellStyle: pw.TextStyle(fontSize: 8.5),
            cellAlignments: {
              0: pw.Alignment.center, // S.N.
              1: pw.Alignment.center, // ROLL NO.
              2: pw.Alignment.centerLeft, // STUDENT NAME
              3: pw.Alignment.center, // THEORY
              4: pw.Alignment.center, // PRACTICAL
              5: pw.Alignment.center, // RESULT
              6: pw.Alignment.center, // STATUS
            },
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: pw_pdf.PdfColors.grey300,
                  width: 0.5,
                ),
              ),
            ),
            oddRowDecoration: const pw.BoxDecoration(
              color: pw_pdf.PdfColors.grey100,
            ),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 6,
            ),
            border: null,
            columnWidths: const {
              0: pw.FlexColumnWidth(0.6), // S.N.
              1: pw.FlexColumnWidth(0.9), // Roll No
              2: pw.FlexColumnWidth(2.2), // Student Name
              3: pw.FlexColumnWidth(1.0), // Theory
              4: pw.FlexColumnWidth(1.0), // Practical
              5: pw.FlexColumnWidth(1.1), // Result
              6: pw.FlexColumnWidth(1.0), // Status
            },
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "Total Records: ${studentsDataset.length}",
              style: pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );

    // Trigger cross-platform Printing / Saving layout
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Student_Ledger_${className}_$sectionName.pdf',
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
                              SubjectsList = [];
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

                      // Expanded(
                      //   child: _buildStyledDropdown(
                      //     label: 'Select Section',
                      //     value: !hasSection ? "-" : selectedSectionId,
                      //     hint: 'Section',
                      //     items: !hasSection
                      //         ? const [
                      //             DropdownMenuItem(
                      //               value: "-",
                      //               child: Text("-"),
                      //             ),
                      //           ]
                      //         : sectionList.map((sec) {
                      //             return DropdownMenuItem<String>(
                      //               value: sec['section_id'].toString(),
                      //               child: Text(sec['section_name'].toString()),
                      //             );
                      //           }).toList(),
                      //     onChanged: !hasSection
                      //         ? null
                      //         : (val) {
                      //             setState(() {
                      //               selectedSectionId = val;
                      //               var selectedSec = sectionList.firstWhere(
                      //                 (sec) =>
                      //                     sec['section_id'].toString() == val,
                      //               );
                      //               selectedSectionName =
                      //                   selectedSec['section_name'].toString();
                      //             });
                      //           },
                      //   ),
                      // ),
                      Expanded(
                        child: _buildStyledDropdown(
                          label: 'Select Section',
                          value: !hasSection
                              ? "-"
                              : (sectionList.any(
                                      (sec) =>
                                          sec['section_id'].toString() ==
                                          selectedSectionId,
                                    )
                                    ? selectedSectionId
                                    : null),
                          hint: 'Section',
                          items: !hasSection
                              ? const [
                                  DropdownMenuItem(
                                    value: "-",
                                    child: Text("-"),
                                  ),
                                ]
                              : sectionList.isEmpty
                              ? const [
                                  DropdownMenuItem(
                                    value: null,
                                    child: Text("Loading sections..."),
                                  ),
                                ]
                              : sectionList.map((sec) {
                                  return DropdownMenuItem<String>(
                                    value: sec['section_id'].toString(),
                                    child: Text(sec['section_name'].toString()),
                                  );
                                }).toList(),
                          onChanged: (!hasSection || sectionList.isEmpty)
                              ? null
                              : (val) {
                                  if (val == null) return;
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
                          label: 'Select Subject',
                          value:
                              SubjectsList.any(
                                (s) =>
                                    s['subject_id'].toString() ==
                                    selectedSubject,
                              )
                              ? selectedSubject
                              : null,
                          hint: 'Subject',
                          items: SubjectsList.map((item) {
                            return DropdownMenuItem<String>(
                              value: item['subject_id'].toString(),
                              child: Text(
                                item['subject_name'].toString().toUpperCase(),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedSubject = newValue;
                              // Find and save the matching subject name!
                              final selectedSub = SubjectsList.firstWhere(
                                (sub) =>
                                    sub['subject_id'].toString() == newValue,
                                orElse: () => {},
                              );
                              selectedSubjectName =
                                  selectedSub['subject_name'] ?? '';
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
                            Expanded(
                              child: _buildCompactParamField(
                                'Total FM',
                                'totalFM',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildCompactParamField(
                                'Total PM',
                                'totalPM',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildCompactParamField(
                                'Theory FM',
                                'theoryFM',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildCompactParamField(
                                'Theory PM',
                                'theoryPM',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildCompactParamField(
                                'Pr. FM',
                                'practicalFM',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildCompactParamField(
                                'Pr. PM',
                                'practicalPM',
                              ),
                            ),
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
                              columns: const [
                                DataColumn(
                                  label: Text(
                                    'S.N.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Roll No',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Student Name',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Theory Marks',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Practical Marks',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Result',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Absent',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ), // NEW COLUMN
                              ],
                              rows: studentsDataset.map((student) {
                                // Extract current absent status
                                bool isAbsent = student['isAbsent'] ?? false;
                                // Extract current result status from dataset item (populated when fetched from backend)
                                String? computedResult = student['result'];

                                return DataRow(
                                  // Change background color slightly if student is marked absent
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

                                    // Theory Input (Disabled if Absent)
                                    DataCell(
                                      SizedBox(
                                        width: 100,
                                        height: 36,
                                        child: TextField(
                                          controller:
                                              student['theoryController'],
                                          keyboardType: TextInputType.number,
                                          enabled:
                                              !isAbsent, // Locks box if absent
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isAbsent
                                                ? Colors.grey
                                                : Colors.black,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: isAbsent
                                                ? 'Absent'
                                                : '0.0',
                                            filled: isAbsent,
                                            fillColor: Colors.grey.shade200,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 10,
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

                                    // Practical Input (Disabled if Absent)
                                    DataCell(
                                      SizedBox(
                                        width: 100,
                                        height: 36,
                                        child: TextField(
                                          controller:
                                              student['practicalController'],
                                          keyboardType: TextInputType.number,
                                          enabled:
                                              !isAbsent, // Locks box if absent
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isAbsent
                                                ? Colors.grey
                                                : Colors.black,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: isAbsent
                                                ? 'Absent'
                                                : '0.0',
                                            filled: isAbsent,
                                            fillColor: Colors.grey.shade200,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 10,
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
                                    // Practical Input (Disabled if Absent)
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: computedResult == 'Pass'
                                              ? Colors.green.shade50
                                              : (computedResult == 'Fail'
                                                    ? Colors.red.shade50
                                                    : Colors.transparent),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          isAbsent
                                              ? 'Absent'
                                              : (computedResult ?? '-'),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: computedResult == 'Pass'
                                                ? Colors.green.shade800
                                                : (computedResult == 'Fail'
                                                      ? Colors.red.shade800
                                                      : Colors.grey),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Absent Checkbox Tick
                                    DataCell(
                                      Checkbox(
                                        value: isAbsent,
                                        activeColor: Colors.red.shade600,
                                        onChanged: (bool? val) {
                                          setState(() {
                                            student['isAbsent'] = val ?? false;

                                            // Automatically clear the mark inputs if they are marked absent
                                            if (student['isAbsent'] == true) {
                                              student['theoryController']
                                                  .clear();
                                              student['practicalController']
                                                  .clear();
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
                              onPressed: () async {
                                // 1. First, save or upsert the exam configuration and wait for it to finish
                                await _saveExamSetupOnly();
                                // 2. Check if the setup successfully provided a setup_id
                                if (currentSetupId != null) {
                                  // 3. Only then proceed to save the student marks
                                  await _saveMarks();
                                } else {
                                  debugPrint(
                                    "Aborted saving marks because configuration setup failed.",
                                  );
                                }
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
