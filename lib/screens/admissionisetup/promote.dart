import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:result/drawer/appdrawer.dart';

class Promote extends StatefulWidget {
  const Promote({super.key});
  @override
  State<Promote> createState() => _PromoteState();
}

class _PromoteState extends State<Promote> {
  //jump from
  // --- Selection States ---
  String? selectedYear = '2026';
  String? selectedClass;
  String? selectedSection;
  String? selectedSubject;
  String? selectedExam;
  String? currentSetupId;
  String? selectedClassId;
  String? selectedClassName;
  String? selectedSectionName;
  String? selectedSectionId;
  bool hasSection = false;
  List<dynamic> academicClasses = [];
  List<dynamic> examinationsList = [];
  List<dynamic> sectionList = [];
  List<dynamic> reportList = [];
  bool isLoading = false;
  List<dynamic> subjectsList = [];
  List<dynamic> extraActivitiesSetupList = [];
  String? examName = "";
  final TextEditingController issueDateController = TextEditingController();
  // student selector state
  static const String kAllStudentsValue = 'ALL';
  String? selectedStudentRoll; // 'ALL' or a specific roll_number string

  final List<String> academicYears = List.generate(
    500,
    (index) => (2020 + index).toString(),
  );
  //jump to
  // --- Selection States ---
  String? jumptoselectedYear = '2026';
  String? jumptoselectedClass;
  String? jumptoselectedSection;
  String? jumptoselectedSubject;
  String? jumptoselectedExam;

  String? jumptocurrentSetupId;
  String? jumptoselectedClassId;
  String? jumptoselectedClassName;
  String? jumptoselectedSectionName;
  String? jumptoselectedSectionId;
  bool jumptohasSection = false;
  List<dynamic> jumptoacademicClasses = [];
  List<dynamic> jumptoexaminationsList = [];
  List<dynamic> jumptosectionList = [];
  List<dynamic> jumptoreportList = [];
  bool jumptoisLoading = false;
  List<dynamic> jumptosubjectsList = [];
  List<dynamic> jumptoextraActivitiesSetupList = [];
  String? jumptoexamName = "";

  // student selector state

  String? jumptoselectedStudentRoll; // 'ALL' or a specific roll_number string

  final List<String> jumptoacademicYears = List.generate(
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
          'action': 'fetchClassesByYear',
          'year_name': selectedYear!,
        },
      );

      var res = await http.get(url);
      var response = jsonDecode(res.body);

      if (response is Map && response["status"] == "success") {
        setState(() {
          academicClasses = response["data"];
          selectedClass = null;
          selectedClassId = null;
        });
      } else if (response is List) {
        setState(() {
          academicClasses = response;
          selectedClass = null;
          selectedClassId = null;
        });
      } else {
        debugPrint("Server Error: ${response["message"] ?? 'Unknown error'}");
      }
    } catch (e) {
      debugPrint("Network Error: $e");
    }
  }

  Future<void> fetchJumpToClassDataOfAcademicYear() async {
    final prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('saved_host');
    if (host == null) return;

    try {
      var url = Uri.parse("http://$host/resultsetupapi.php").replace(
        queryParameters: {
          'action': 'fetchClassesByYear',
          'year_name': jumptoselectedYear!,
        },
      );

      var res = await http.get(url);
      var response = jsonDecode(res.body);

      if (response is Map && response["status"] == "success") {
        setState(() {
          jumptoacademicClasses = response["data"];
          jumptoselectedClass = null;
          jumptoselectedClassId = null;
        });
      } else if (response is List) {
        setState(() {
          jumptoacademicClasses = response;
          jumptoselectedClass = null;
          jumptoselectedClassId = null;
        });
      } else {
        debugPrint("Server Error: ${response["message"] ?? 'Unknown error'}");
      }
    } catch (e) {
      debugPrint("Network Error: $e");
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
        setState(() {
          sectionList = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Error fetching sections: $e");
    }
  }

  Future<void> fetchJumpToSections(String classId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? host = prefs.getString('saved_host');
      if (host == null || host.isEmpty) return;

      final response = await http.get(
        Uri.parse(
          "http://$host/systemsetupapi.php?action=get_sections&class_id=$classId",
        ),
      );

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);

        if (mounted) {
          setState(() {
            if (decodedData is List) {
              // Direct dynamic assignment (matches fetchSections)
              jumptosectionList = decodedData;
            } else if (decodedData is Map && decodedData.containsKey('data')) {
              jumptosectionList = decodedData['data'];
            } else {
              jumptosectionList = [];
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching jump to sections: $e");
    }
  }

  @override
  void dispose() {
    issueDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<DropdownMenuItem<String>> studentItems = [
      const DropdownMenuItem(
        value: kAllStudentsValue,
        child: Text('All Students'),
      ),
      ...reportList.map((r) {
        final roll = r['roll_number']?.toString() ?? '';
        final name = r['student_name']?.toString() ?? '';
        return DropdownMenuItem<String>(
          value: roll,
          child: Text('$roll - $name', overflow: TextOverflow.ellipsis),
        );
      }),
    ];

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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "JUMP FROM:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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

                            var selectedItem = academicClasses.firstWhere(
                              (item) =>
                                  item['class_id'].toString() == newClassId,
                            );

                            setState(() {
                              selectedClassId = newClassId;
                              selectedClassName = selectedItem['class_name']
                                  .toString();
                              selectedSubject = null;
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
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "JUMP TO:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStyledDropdown(
                          label: 'Fiscal Year',
                          value: jumptoselectedYear,
                          hint: 'Year',
                          items: jumptoacademicYears
                              .map(
                                (y) => DropdownMenuItem<String>(
                                  value: y,
                                  child: Text(y),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() => jumptoselectedYear = v);
                            fetchJumpToClassDataOfAcademicYear();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: _buildStyledDropdown(
                          label: 'Select Class',
                          value: jumptoselectedClassId,
                          hint: 'Class',
                          items: jumptoacademicClasses.map((item) {
                            return DropdownMenuItem<String>(
                              value: item['class_id'].toString(),
                              child: Text(
                                item['class_name'].toString().toUpperCase(),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newClassId) {
                            if (newClassId == null) return;

                            // 1. Find selected item using safe lookup
                            final jumptoselectedItem = jumptoacademicClasses
                                .firstWhere(
                                  (item) =>
                                      item['class_id'].toString() == newClassId,
                                  orElse: () => {},
                                );

                            if (jumptoselectedItem.isEmpty) return;

                            final bool jumptohasSec =
                                jumptoselectedItem['section']
                                    .toString()
                                    .trim()
                                    .toUpperCase() ==
                                "YES";

                            // 2. Synchronous UI State Update First
                            setState(() {
                              jumptoselectedClassId = newClassId;
                              jumptoselectedClassName =
                                  jumptoselectedItem['class_name'].toString();
                              jumptoselectedSubject = null;
                              jumptoselectedSectionId = null;
                              jumptosectionList = []; // Reset section list
                              jumptohasSection = jumptohasSec;

                              if (jumptohasSec) {
                                jumptoselectedSectionName = "";
                              } else {
                                jumptoselectedSectionId = "-";
                                jumptoselectedSectionName = "-";
                              }
                            });

                            // 3. Trigger Async API Call OUTSIDE setState
                            if (jumptohasSec) {
                              fetchJumpToSections(newClassId);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStyledDropdown(
                          label: 'Select Section',
                          value: !jumptohasSection
                              ? "-"
                              : jumptoselectedSectionId,
                          hint: 'Section',
                          items: !jumptohasSection
                              ? const [
                                  DropdownMenuItem(
                                    value: "-",
                                    child: Text("-"),
                                  ),
                                ]
                              : jumptosectionList.map((sec) {
                                  return DropdownMenuItem<String>(
                                    value: sec['section_id'].toString(),
                                    child: Text(sec['section_name'].toString()),
                                  );
                                }).toList(),
                          onChanged: !jumptohasSection
                              ? null
                              : (val) {
                                  if (val == null) return;

                                  // Safe lookup to prevent crash if section not found
                                  final selectedSec = jumptosectionList
                                      .firstWhere(
                                        (sec) =>
                                            sec['section_id'].toString() == val,
                                        orElse: () => {},
                                      );

                                  setState(() {
                                    jumptoselectedSectionId = val;
                                    if (selectedSec.isNotEmpty) {
                                      jumptoselectedSectionName =
                                          selectedSec['section_name']
                                              .toString();
                                    }
                                  });
                                },
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(
                  Icons.get_app_outlined,
                  size: 16,
                  color: Colors.white,
                ),
                label: const Text(
                  'OK',
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
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
}
