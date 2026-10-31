import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:result/drawer/appdrawer.dart';

class PrepareResult extends StatefulWidget {
  const PrepareResult({super.key});
  @override
  State<PrepareResult> createState() => _PrepareResultState();
}

class _PrepareResultState extends State<PrepareResult> {
  // --- Selection States ---
  String? selectedYear = '2026';
  String? selectedClass;
  String? selectedSection;
  String? selectedSubject;
  String? selectedExam;
  // --- ADD THESE VARIABLES HERE ---
  String? selectedActivityId;
  String? totalWorkingDaysValue;

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

  // NEW: Dynamically generate years from 2020 to 5000
  final List<String> academicYears = List.generate(
    500,
    (index) => (2020 + index).toString(),
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
  bool isPreparing = false; // Loading indicator state

  Future<void> _prepareData() async {
    if (selectedYear == null ||
        selectedClassId == null ||
        selectedExam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Year, Class, and Examination first.'),
        ),
      );
      return;
    }

    setState(() {
      isPreparing = true; // Show loading state
    });

    // Show a sleek, non-dismissible processing dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(width: 24),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Processing Results",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Calculating marks, ranks, and grades...",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      String? host = prefs.getString('saved_host');
      if (host == null) {
        if (mounted)
          Navigator.of(context).pop(); // Dismiss dialog if returning early
        return;
      }

      var url = Uri.parse(
        "http://$host/prepareresultapi.php?action=prepareResult",
      );
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "year_name": selectedYear,
          "class_id": int.tryParse(selectedClassId!) ?? 0,
          "section_id": (!hasSection || selectedSectionId == "-")
              ? null
              : selectedSectionId,
          "exam_id": int.tryParse(selectedExam!) ?? 0,
        }),
      );

      // Safely dismiss the loading dialog right after response comes back
      if (mounted) {
        Navigator.of(context).pop();
      }

      var resData = jsonDecode(response.body);
      debugPrint("Server Response: $resData");

      if (resData["status"] == "success") {
        setState(() {
          studentsDataset = List<Map<String, dynamic>>.from(
            resData["students"].map((s) {
              return {
                'enrollmentId': s['enrollment_id'],
                'studentName': s['student_name'],
                'rollNumber': s['roll_number'],
                'theoryController': TextEditingController(
                  text: s['performance_grade'] ?? '',
                ),
                'isAbsent': s['is_absent'] == 1,
                'totalMarks': s['total_marks'],
                'percentage': s['percentage'],
                'gpa': s['gpa'],
              };
            }),
          );
          showStudentsTable = true;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed: ${resData['message'] ?? 'Unknown error'}"),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error preparing data: $e");
      // Safely dismiss dialog if an exception occurs mid-way
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error while preparing data.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isPreparing = false; // Hide loading state
        });
      }
    }
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
                            fetchExaminations();
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

                  ElevatedButton.icon(
                    onPressed: isPreparing ? null : _prepareData,
                    icon: const Icon(
                      Icons.search,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Prepare',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade600,
                      disabledBackgroundColor:
                          Colors.teal.shade300, // Looks nice when disabled
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
}
