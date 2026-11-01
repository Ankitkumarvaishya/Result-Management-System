import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:result/drawer/appdrawer.dart';
import 'package:result/screens/schoolconfiguration/school_config.dart';

class Enrollment extends StatefulWidget {
  const Enrollment({super.key});

  @override
  State<Enrollment> createState() => _EnrollmentState();
}

class _EnrollmentState extends State<Enrollment> {
  final _formKey = GlobalKey<FormState>();
  final _editFormKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rollController = TextEditingController();
  final TextEditingController _guardianController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  // State Variables
  List<dynamic> academicYears = []; // Loaded from fetchClassDataOfAcademicYear
  List<dynamic> sectionList = []; // Loaded from fetchSections
  String? selectedClassId;
  String? selectedClassName;
  String? selectedSectionName;
  String? selectedSectionId;
  bool hasSection = false;
  final TextEditingController _searchController = TextEditingController();
  // for current active year
  String activeYear = "N/A";
  Future<void> fetchActiveYear() async {
    final prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('saved_host');

    if (host == null) {
      setState(() {
        activeYear = "N/A";
      });
      return;
    }

    try {
      var url = Uri.parse(
        "http://$host/dashboardsetupapi.php",
      ).replace(queryParameters: {'action': 'getdashboardstats'});

      var res = await http.get(url);
      var response = jsonDecode(res.body);

      // Check if request was successful and extract only the year_name
      if (response is Map && response["status"] == "success") {
        setState(() {
          activeYear = response["year_name"] ?? "N/A";
        });
      } else {
        setState(() {
          activeYear = "N/A";
        });
      }
    } catch (e) {
      setState(() {
        activeYear = "N/A";
      });
      print("Error fetching active year: $e");
    }
  }

  // Your raw data from the server
  List<dynamic> _filteredStudents = []; // The data displayed in the table
  @override
  void initState() {
    super.initState();
    fetchActiveYear();
    _fetchStudents();
    fetchClassDataOfAcademicYear();

    _searchController.addListener(_filterStudentsData);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _guardianController.dispose();
    _dobController.dispose();
    academicYears.clear();
    sectionList.clear();
    // _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// 🔷 FETCH CLASSES
  Future<void> fetchClassDataOfAcademicYear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? host = prefs.getString('saved_host');
      if (host == null) return;

      var url = Uri.parse(
        "http://$host/systemsetupapi.php?action=fetchclassdataofacademicyear",
      );
      var response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          academicYears = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Error fetching classes: $e");
    }
  }

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

  //saving the students details
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    String? host = prefs.getString('saved_host');
    String sectionValue =
        (selectedSectionId == null ||
            selectedSectionId == 0 ||
            selectedSectionId == '-')
        ? ""
        : selectedSectionId.toString();

    try {
      var res = await http.post(
        Uri.parse(
          "http://$host/admissionsetupapi.php?action=savestudentsdetails",
        ),
        body: {
          "student_name": _nameController.text.toUpperCase().trim(),
          "guardian_name": _guardianController.text.toUpperCase().trim(),
          "date_of_birth": _dobController.text.trim(),
          "roll_number": _rollController.text.trim(),
          "class_id": selectedClassId.toString(),
          "section_id": sectionValue,
        },
      );

      print("RAW RESPONSE FROM SERVER: ${res.body}");
      var response = jsonDecode(res.body);

      if (response["status"] == "success") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Center(child: Text("Student Registered Successfully!")),
          ),
        );
      } else {
        print("Server Error: ${response["error"]}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Center(
              child: Text(
                "Student Cannot be Saved! Note: Roll number should not be repeated",
              ),
            ),
          ),
        );
      }
    } catch (e) {
      print("Caught Error: $e");
    }
  }

  List<dynamic> _studentsfilter = [];
  List<dynamic> _students = [];
  bool _isLoading = true;

  // Fetching students data
  Future<void> _fetchStudents() async {
    final prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('saved_host');

    try {
      var res = await http.get(
        Uri.parse(
          "http://$host/admissionsetupapi.php?action=getstudentdetails",
        ),
      );

      var response = jsonDecode(res.body);

      if (response["status"] == "success") {
        setState(() {
          _students = response["data"];
          _studentsfilter =
              response["data"]; // <-- ASSIGN IT HERE SO FILTER HAS DATA!
          _isLoading = false;
          _filterStudentsData();
        });
      } else {
        print("Server Error: ${response["message"]}");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Network Error: $e");
      setState(() => _isLoading = false);
    }
  }

  //delete the student
  Future<void> deleteStudent(var id) async {
    final prefs = await SharedPreferences.getInstance();

    // Here you are "reading" that saved variable back from the disk
    String? host = prefs.getString('saved_host');
    var url = Uri.parse(
      "http://$host/admissionsetupapi.php?action=deletestudent",
    );

    var response = await http.post(url, body: {"student_id": id});

    if (response.statusCode == 200) {
      print("Response: ${response.body}");
      // refresh table
    } else {
      print("Delete failed");
    }
  }

  //updating the student
  Future<void> _executeServerUpdate(
    String studentId,
    String classId,
    String? sectionId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('saved_host');

    var url = Uri.parse(
      "http://$host/admissionsetupapi.php?action=updatestudentdetails",
    );

    try {
      var response = await http.post(
        url,
        body: {
          "student_id": studentId,
          "student_name": _nameController.text.toUpperCase().trim(),
          "guardian_name": _guardianController.text.toUpperCase().trim(),
          "date_of_birth": _dobController.text.trim(),
          "roll_number": _rollController.text.trim(),
          "class_id": classId,
          "section_id": (sectionId == null || sectionId == "-")
              ? ""
              : sectionId,
        },
      );

      var data = jsonDecode(response.body);

      if (data["status"] == "success") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Center(child: Text("Student Modified successfully!")),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(
          data["message"] ?? "Failed to perform data modification updates.",
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error processing save task: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  showEditStudentDialog(
    BuildContext context,
    Map<String, dynamic> student,
  ) async {
    // 🛠️ FIX 1: Clear the global section list immediately when the dialog opens
    // This prevents the previous student's sections from showing up as ghosts.
    sectionList = [];

    // 1. Pre-populate text controllers
    _nameController.text = student['student_name'] ?? '';
    _guardianController.text = student['guardian_name'] ?? '';
    _dobController.text = student['date_of_birth'] ?? '';
    _rollController.text = student['roll_number']?.toString() ?? '';

    String? originalClassName = student['class_name']?.toString().trim();

    // Smart ID Extraction
    String? localSelectedClassId =
        (student['class_id'] ??
                student['id_class'] ??
                student['class']?['id'] ??
                student['id'])
            ?.toString()
            .trim();

    // Fallback Name-Matching Strategy
    if ((localSelectedClassId == null || localSelectedClassId.isEmpty) &&
        originalClassName != null) {
      final matchedClassByName = academicYears.firstWhere(
        (item) =>
            item['class_name'].toString().trim().toUpperCase() ==
            originalClassName.toUpperCase(),
        orElse: () => {},
      );
      if (matchedClassByName.isNotEmpty) {
        localSelectedClassId = matchedClassByName['class_id']
            ?.toString()
            .trim();
      }
    }

    String? localSelectedSectionId =
        (student['section_name'] != null && student['section_name'] != '-')
        ? (student['section_id'] ?? student['id_section'])?.toString().trim()
        : "-";

    // Auto-Injector System for Class List
    if (localSelectedClassId != null && localSelectedClassId.isNotEmpty) {
      bool classExistsInList = academicYears.any(
        (item) => item['class_id'].toString().trim() == localSelectedClassId,
      );

      if (!classExistsInList) {
        academicYears.add({
          'class_id': localSelectedClassId,
          'class_name': originalClassName ?? "Class $localSelectedClassId",
          'section': student['section_name'] != null ? "YES" : "NO",
        });
      }
    }

    // 🛠️ FIX 2: Pre-fetch and AWAIT the sections before the dialog UI opens.
    // This guarantees that when the dialog draws for the first time, it has the fresh sections.
    if (localSelectedClassId != null && localSelectedClassId.isNotEmpty) {
      final currentClass = academicYears.firstWhere(
        (item) => item['class_id'].toString().trim() == localSelectedClassId,
        orElse: () => {},
      );

      if (currentClass.isNotEmpty &&
          currentClass['section']?.toString().trim().toUpperCase() == "YES") {
        await fetchSections(
          localSelectedClassId,
        ); // Waits for network data to overwrite sectionList
      }
    }

    if (!context.mounted) return;

    // 3. Render Dialog Window safely
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(
                    Icons.edit_note,
                    color: Colors.blueAccent,
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  Text("Modify: ${student['student_name'] ?? 'Student'}"),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                child: SingleChildScrollView(
                  child: Form(
                    key: _editFormKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: "Full Name",
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? "Enter full name"
                              : null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _guardianController,
                          decoration: const InputDecoration(
                            labelText: "Guardian Name",
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? "Enter guardian name"
                              : null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _dobController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "DOB (YYYY-MM-DD)",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),

                        TextFormField(
                          controller: _rollController,
                          decoration: const InputDecoration(
                            labelText: "Roll Number",
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return "Enter roll number";
                            }

                            // 🛡️ CHECK FOR SAME CLASS DUPLICATIONS ONLY
                            bool isDuplicateInClass = _students.any((item) {
                              bool isSameClass =
                                  item['class_id']?.toString().trim() ==
                                  localSelectedClassId?.toString().trim();
                              bool isSameRoll =
                                  item['roll_number']?.toString().trim() ==
                                  v.trim();
                              // Exclude current student being edited
                              bool isDifferentStudent =
                                  item['student_id']?.toString().trim() !=
                                  student['student_id']?.toString().trim();

                              return isSameClass &&
                                  isSameRoll &&
                                  isDifferentStudent;
                            });

                            if (isDuplicateInClass) {
                              return "Roll number is already taken in this class!";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        /// --- CLASS DROPDOWN ---
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value:
                              (localSelectedClassId != null &&
                                  academicYears.any(
                                    (item) =>
                                        item['class_id'].toString().trim() ==
                                        localSelectedClassId,
                                  ))
                              ? localSelectedClassId
                              : null,
                          decoration: const InputDecoration(
                            labelText: "Select Class",
                            border: OutlineInputBorder(),
                          ),
                          items: academicYears.map((item) {
                            return DropdownMenuItem<String>(
                              value: item['class_id'].toString().trim(),
                              child: Text(
                                item['class_name'].toString().toUpperCase(),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue == null) return;

                            var selectedItem = academicYears.firstWhere(
                              (item) =>
                                  item['class_id'].toString().trim() ==
                                  newValue,
                            );

                            bool classHasSection =
                                selectedItem['section']
                                    ?.toString()
                                    .trim()
                                    .toUpperCase() ==
                                "YES";

                            // 🛠️ FIX 3: Clean state layout mapping during manual selection changes
                            setDialogState(() {
                              localSelectedClassId = newValue;
                              localSelectedSectionId = "-";
                              sectionList =
                                  []; // Clear current dropdown items while loading new ones
                            });

                            if (classHasSection) {
                              fetchSections(newValue).then((_) {
                                // Trigger state e inside the dialog once async data drops
                                setDialogState(() {});
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 20),

                        /// --- SECTION DROPDOWN ---
                        DropdownButtonFormField<String>(
                          // Ensure the value exists in items, otherwise fallback safely to null
                          value:
                              (sectionList.any(
                                (sec) =>
                                    sec['section_id'].toString().trim() ==
                                    localSelectedSectionId,
                              ))
                              ? localSelectedSectionId
                              : (academicYears
                                            .firstWhere(
                                              (item) =>
                                                  item['class_id']
                                                      .toString()
                                                      .trim() ==
                                                  localSelectedClassId,
                                              orElse: () => {},
                                            )['section']
                                            ?.toString()
                                            .trim()
                                            .toUpperCase() ==
                                        "YES"
                                    ? null // If it has sections and current ID isn't valid, don't force "-"
                                    : "-"), // For non-section classes, keep "-"
                          decoration: const InputDecoration(
                            labelText: "Select Section",
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            // Show "-" option ONLY if class does NOT have sections
                            if (academicYears
                                    .firstWhere(
                                      (item) =>
                                          item['class_id'].toString().trim() ==
                                          localSelectedClassId,
                                      orElse: () => {},
                                    )['section']
                                    ?.toString()
                                    .trim()
                                    .toUpperCase() !=
                                "YES")
                              const DropdownMenuItem(
                                value: "-",
                                child: Text("-"),
                              ),

                            // Populate actual sections
                            if (sectionList.isNotEmpty)
                              ...sectionList.map((sec) {
                                return DropdownMenuItem<String>(
                                  value: sec['section_id'].toString().trim(),
                                  child: Text(sec['section_name'].toString()),
                                );
                              }),
                          ],
                          validator: (val) {
                            bool classHasSection =
                                academicYears
                                    .firstWhere(
                                      (item) =>
                                          item['class_id'].toString().trim() ==
                                          localSelectedClassId,
                                      orElse: () => {},
                                    )['section']
                                    ?.toString()
                                    .trim()
                                    .toUpperCase() ==
                                "YES";

                            if (classHasSection &&
                                (val == null || val == "-")) {
                              return "Please select a section";
                            }
                            return null;
                          },
                          onChanged: (String? val) {
                            setDialogState(() {
                              localSelectedSectionId = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _nameController.clear();
                    _guardianController.clear();
                    _dobController.clear();
                    _rollController.clear();
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text("Apply Updates"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (_editFormKey.currentState?.validate() ?? false) {
                      if (localSelectedClassId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Please select a class."),
                          ),
                        );
                        return;
                      }

                      await _executeServerUpdate(
                        student['student_id'].toString(),
                        localSelectedClassId!,
                        localSelectedSectionId,
                      );

                      if (context.mounted) {
                        Navigator.of(context).pop();
                        await _fetchStudents();
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  //FOR SORTING
  // Filtering Logic for Student Name and Class Name
  void _filterStudentsData() {
    String query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredStudents = List.from(_studentsfilter);
      } else {
        _filteredStudents = _studentsfilter.where((student) {
          String studentName =
              student['student_name']?.toString().toLowerCase() ?? '';
          String className =
              student['class_name']?.toString().toLowerCase() ?? '';

          // Matches if query is found in either student name or class name
          return studentName.contains(query) || className.contains(query);
        }).toList();
      }
    });
  }

  // ---------------------------------------------------------------------
  // SHARED SCHOOL HEADER HELPERS (new)
  // ---------------------------------------------------------------------
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

  Future<pw.Widget> _buildPdfHeader() async {
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
                  style: const pw.TextStyle(fontSize: 16),
                ),
                pw.Text(
                  SchoolConfig.phoneNumber,
                  style: const pw.TextStyle(fontSize: 16),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 6),
        pw.Text(
          "Enrollment Records Report of $activeYear B.S.",
          style: pw.TextStyle(fontSize: 14),
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }

  Future<void> _exportStudentsToExcel() async {
    if (_filteredStudents.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No student data available to export.')),
        );
      }
      return;
    }

    try {
      // 1. Create Excel Workbook and Sheet
      final excelFile = excel.Excel.createExcel();
      final excel.Sheet sheet = excelFile['Students'];
      excelFile.delete('Sheet1'); // Remove default tab

      // 1a. School details header (new)
      int currentRow = 0;
      void writeSchoolHeaderRow(
        String text, {
        bool bold = true,
        double size = 12,
      }) {
        final cell = sheet.cell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: currentRow,
          ),
        );
        cell.value = excel.TextCellValue(text);
        cell.cellStyle = excel.CellStyle(bold: bold, fontSize: size.toInt());
        currentRow++;
      }

      writeSchoolHeaderRow(SchoolConfig.schoolName, bold: true, size: 16);
      writeSchoolHeaderRow(SchoolConfig.address, bold: false, size: 11);
      writeSchoolHeaderRow(SchoolConfig.phoneNumber, bold: false, size: 11);
      currentRow++; // blank row

      writeSchoolHeaderRow("Enrollment Records Report", bold: true, size: 13);
      currentRow++; // blank row

      // 2. Define Table Headers
      final List<String> headers = [
        'Roll No.',
        'Student Name',
        'Guardian Name',
        'Date of Birth',
        'Class',
        'Section',
      ];

      final int headerRowIndex = currentRow;

      // Style Header Row
      for (int col = 0; col < headers.length; col++) {
        final cell = sheet.cell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: col,
            rowIndex: headerRowIndex,
          ),
        );
        cell.value = excel.TextCellValue(headers[col]);
        cell.cellStyle = excel.CellStyle(
          bold: true,
          backgroundColorHex: excel.ExcelColor.fromHexString(
            'FF1F4E78',
          ), // Elegant Navy Header
          fontColorHex: excel.ExcelColor.fromHexString(
            'FFFFFFFF',
          ), // White text
          horizontalAlign: excel.HorizontalAlign.Center,
          verticalAlign: excel.VerticalAlign.Center,
        );
      }
      currentRow++;

      // 3. Write Student Data Rows
      for (int rowIdx = 0; rowIdx < _filteredStudents.length; rowIdx++) {
        final student = _filteredStudents[rowIdx];

        // Parse fields safely
        final rollNo = student['roll_number'] != null
            ? num.tryParse(student['roll_number'].toString()) ??
                  student['roll_number'].toString()
            : '-';
        final studentName = student['student_name']?.toString() ?? '-';
        final guardianName = student['guardian_name']?.toString() ?? '-';
        final dob = student['date_of_birth']?.toString() ?? '-';
        final className = student['class_name']?.toString() ?? '-';
        final sectionName = student['section_name']?.toString() ?? '-';

        final List<dynamic> rowData = [
          rollNo,
          studentName,
          guardianName,
          dob,
          className,
          sectionName,
        ];

        final int dataRowIndex = currentRow + rowIdx;

        // Write each cell into Excel
        for (int col = 0; col < rowData.length; col++) {
          final cell = sheet.cell(
            excel.CellIndex.indexByColumnRow(
              columnIndex: col,
              rowIndex: dataRowIndex,
            ),
          );

          final val = rowData[col];
          if (val is num) {
            cell.value = excel.DoubleCellValue(val.toDouble());
          } else {
            cell.value = excel.TextCellValue(val.toString());
          }

          cell.cellStyle = excel.CellStyle(
            horizontalAlign: col == 0 || col == 3 || col == 4 || col == 5
                ? excel.HorizontalAlign.Center
                : excel.HorizontalAlign.Left, // Left align names, center stats
          );
        }
      }

      // 4. Auto-fit columns
      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnAutoFit(i);
      }

      // 5. Save and Export File
      final List<int>? fileBytes = excelFile.save();
      if (fileBytes == null) return;

      final String defaultFileName =
          'Student_List_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      String? outputPath = await FilePicker.saveFile(
        dialogTitle: 'Save Student List Excel',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputPath == null) return; // User cancelled

      if (!outputPath.toLowerCase().endsWith('.xlsx')) {
        outputPath = '$outputPath.xlsx';
      }

      final file = File(outputPath);
      await file.writeAsBytes(fileBytes, flush: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Students exported successfully!\nSaved to: $outputPath',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error exporting students to Excel: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export student list: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------
  // PDF EXPORT (new) — same styling/header approach as the Sections screen
  // ---------------------------------------------------------------------
  Future<void> _exportStudentsToPdf() async {
    if (_filteredStudents.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No student data available to export.')),
        );
      }
      return;
    }

    final pdf = pw.Document(theme: pw.ThemeData.withFont());
    final header = await _buildPdfHeader();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => context.pageNumber == 1 ? header : pw.SizedBox(),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}  •  Generated ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: [
              "S.N.",
              "ROLL NO.",
              "STUDENT NAME",
              "GUARDIAN NAME",
              "DOB",
              "CLASS",
              "SECTION",
            ],
            data: _filteredStudents.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return [
                (index + 1).toString(),
                (item['roll_number'] ?? '-').toString(),
                (item['student_name'] ?? '-').toString(),
                (item['guardian_name'] ?? '-').toString(),
                (item['date_of_birth'] ?? '-').toString(),
                (item['class_name'] ?? '-').toString(),
                (item['section_name'] ?? '-').toString(),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontSize: 10, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey800,
            ),
            cellStyle: pw.TextStyle(fontSize: 10),
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
              6: pw.Alignment.center,
            },
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 6,
            ),
            border: null,
            columnWidths: {
              0: const pw.FlexColumnWidth(0.6),
              1: const pw.FlexColumnWidth(1.0),
              2: const pw.FlexColumnWidth(2.2),
              3: const pw.FlexColumnWidth(2.0),
              4: const pw.FlexColumnWidth(1.4),
              5: const pw.FlexColumnWidth(1.2),
              6: const pw.FlexColumnWidth(1.0),
            },
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "Total Records: ${_filteredStudents.length}",
              style: pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // sorting
  int? _sortColumnIndex;
  bool _sortAscending = true;

  void _sort<T>(
    Comparable<T> Function(Map<String, dynamic> student) getField,
    int columnIndex,
    bool ascending,
  ) {
    _filteredStudents.sort((a, b) {
      final aValue = getField(a);
      final bValue = getField(b);
      return ascending
          ? Comparable.compare(aValue, bValue)
          : Comparable.compare(bValue, aValue);
    });
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Result Management System"),
      ),
      drawer: const AppDrawer(),
      body: Row(
        children: [
          /// LEFT SIDE: FORM
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Full Name",
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? "Enter full name" : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _guardianController,
                      decoration: const InputDecoration(
                        labelText: "Guardian Name",
                        prefixIcon: Icon(Icons.person_2),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v!.isEmpty ? "Enter guardian name" : null,
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _dobController,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: "DOB (YYYY-MM-DD or '-')",
                        hintText: "YYYY-MM-DD or '-'",
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      inputFormatters: [
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          final text = newValue.text;

                          // 1. Allow a single hyphen if date is unknown
                          if (text == '-') {
                            return newValue;
                          }

                          // 2. If user is deleting characters (backspace), let them delete freely
                          if (oldValue.text.length > text.length) {
                            return newValue;
                          }

                          // 3. Clean up input (trim whitespace, convert slashes to hyphens for Excel pastes)
                          String cleaned = text.trim().replaceAll('/', '-');

                          // 4. Handle complete 10-character dates (whether pasted over existing text or typed out)
                          if (cleaned.length == 10) {
                            if (RegExp(
                              r'^\d{4}-\d{2}-\d{2}$',
                            ).hasMatch(cleaned)) {
                              return TextEditingValue(
                                text: cleaned,
                                selection: TextSelection.collapsed(offset: 10),
                              );
                            } else {
                              return oldValue; // Block invalid 10-character strings
                            }
                          }

                          // 5. Enforce max length of 10 characters
                          if (cleaned.length > 10) return oldValue;

                          // 6. Automatically add first hyphen after 4 digits (YYYY -> YYYY-)
                          if (cleaned.length == 4 && !cleaned.contains('-')) {
                            return TextEditingValue(
                              text: '$cleaned-',
                              selection: TextSelection.collapsed(offset: 5),
                            );
                          }

                          // 7. Automatically add second hyphen after 7 digits (YYYY-MM -> YYYY-MM-)
                          if (cleaned.length == 7 &&
                              cleaned.split('-').length == 2) {
                            return TextEditingValue(
                              text: '$cleaned-',
                              selection: TextSelection.collapsed(offset: 8),
                            );
                          }

                          return newValue;
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _rollController,
                      decoration: const InputDecoration(
                        labelText: "Roll Number",
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return "Enter roll number";
                        }

                        // 🛡️ CHECK: Is this roll number taken inside the currently selected class?
                        bool isDuplicateInClass = _students.any((student) {
                          return student['class_id']?.toString().trim() ==
                                  selectedClassId?.toString().trim() &&
                              student['roll_number']?.toString().trim() ==
                                  v.trim();
                        });

                        if (isDuplicateInClass) {
                          return "Roll number is already taken in this class!";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    /// --- CLASS DROPDOWN ---
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Select Class",
                        border: OutlineInputBorder(),
                      ),
                      initialValue: selectedClassId,
                      items: academicYears.map((item) {
                        return DropdownMenuItem<String>(
                          value: item['class_id'].toString(),
                          child: Text(
                            item['class_name'].toString().toUpperCase(),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue == null) return;

                        // Find the selected class object
                        var selectedItem = academicYears.firstWhere(
                          (item) => item['class_id'].toString() == newValue,
                        );

                        setState(() {
                          selectedClassId = newValue;
                          selectedClassName = selectedItem['class_name']
                              .toString();

                          // Reset Section State
                          selectedSectionId = null;
                          sectionList = [];

                          // Check if 'section' column is "yes"
                          hasSection =
                              selectedItem['section']
                                  .toString()
                                  .trim()
                                  .toUpperCase() ==
                              "YES";

                          if (hasSection) {
                            // If it has sections, we don't know the name yet (must fetch)
                            selectedSectionName = "";
                            fetchSections(newValue);
                          } else {
                            // 3. THIS IS THE FIX: If no section, assign the dash to the variables
                            selectedSectionId = "-";
                            selectedSectionName = "-";
                          }
                          print(selectedClassName);
                        });

                        // Trigger API call for sections
                        if (hasSection) {
                          fetchSections(newValue);
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    /// --- SECTION DROPDOWN ---
                    DropdownButtonFormField<String>(
                      initialValue: !hasSection ? "-" : selectedSectionId,
                      decoration: const InputDecoration(
                        labelText: "Select Section",
                        border: OutlineInputBorder(),
                      ),
                      items: !hasSection
                          ? [
                              const DropdownMenuItem(
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
                                  (sec) => sec['section_id'].toString() == val,
                                );
                                selectedSectionName =
                                    selectedSec['section_name'].toString();
                              });
                              print(
                                "Selected Section Name: $selectedSectionName",
                              );
                            },
                    ),
                    const SizedBox(height: 40),

                    ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          // This will now print "-" instead of nothing for classes without sections
                          print("Class: $selectedClassName");
                          print("Section Name: $selectedSectionName");
                          debugPrint(
                            "Saving: ${_nameController.text}, Class: $selectedClassName, date:$_dobController          ,Section: $selectedSectionId , selectedclassid: $selectedClassId, selectedsectionid: $selectedSectionId",
                          );

                          //calling save function to save students details
                          await _save();
                          await _fetchStudents();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 55),
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Save Student Details",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          /// RIGHT SIDE: TABLE (Preview)
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.green.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const SizedBox(height: 10),

                  // Right-Aligned Search Bar Component
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left side: buttons
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                _exportStudentsToPdf();
                              },
                              icon: const Icon(
                                Icons.picture_as_pdf,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Export PDF',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent.shade700,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                _exportStudentsToExcel();
                              },
                              icon: const Icon(
                                Icons.download,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Export to Excel',
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

                        // Right side: search bar
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 300,
                            minWidth: 200,
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) => setState(() {}),
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: "Search Student or Class",
                              hintText: "Type name...",
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      "Enrollment Records of $activeYear B.S.",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth,
                              ),
                              child: DataTable(
                                sortColumnIndex: _sortColumnIndex,
                                sortAscending: _sortAscending,
                                columns: [
                                  DataColumn(
                                    label: const Text("Roll No."),
                                    onSort: (columnIndex, ascending) =>
                                        _sort<num>(
                                          (s) =>
                                              num.tryParse(
                                                s['roll_number'].toString(),
                                              ) ??
                                              0,
                                          columnIndex,
                                          ascending,
                                        ),
                                  ),
                                  DataColumn(
                                    label: const Text("Student's Name"),
                                    onSort: (columnIndex, ascending) =>
                                        _sort<String>(
                                          (s) => s['student_name'].toString(),
                                          columnIndex,
                                          ascending,
                                        ),
                                  ),
                                  DataColumn(
                                    label: const Text("Guardian's Name"),
                                    onSort: (columnIndex, ascending) =>
                                        _sort<String>(
                                          (s) => (s['guardian_name'] ?? '')
                                              .toString(),
                                          columnIndex,
                                          ascending,
                                        ),
                                  ),
                                  DataColumn(
                                    label: const Text("Date of Birth"),
                                    onSort: (columnIndex, ascending) =>
                                        _sort<String>(
                                          (s) => (s['date_of_birth'] ?? '')
                                              .toString(),
                                          columnIndex,
                                          ascending,
                                        ),
                                  ),
                                  DataColumn(
                                    label: const Text("Class"),
                                    onSort: (columnIndex, ascending) =>
                                        _sort<String>(
                                          (s) => s['class_name'].toString(),
                                          columnIndex,
                                          ascending,
                                        ),
                                  ),
                                  DataColumn(
                                    label: const Text("Section"),
                                    onSort: (columnIndex, ascending) =>
                                        _sort<String>(
                                          (s) => s['section_name'].toString(),
                                          columnIndex,
                                          ascending,
                                        ),
                                  ),
                                  const DataColumn(label: Text("Actions")),
                                ],
                                rows: _filteredStudents.map((student) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(student['roll_number'].toString()),
                                      ),
                                      DataCell(
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 220,
                                          ),
                                          child: Text(
                                            student['student_name'].toString(),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 220,
                                          ),
                                          child: Text(
                                            student['guardian_name'] ?? '-',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(student['date_of_birth'] ?? '-'),
                                      ),
                                      DataCell(
                                        Text(student['class_name'].toString()),
                                      ),
                                      DataCell(
                                        Text(
                                          student['section_name'].toString(),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit,
                                                color: Colors.green,
                                              ),
                                              onPressed: () async {
                                                await showEditStudentDialog(
                                                  context,
                                                  student,
                                                );
                                                if (!context.mounted) return;
                                                await _fetchStudents();
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return AlertDialog(
                                                      title: const Text(
                                                        "Confirm Delete",
                                                      ),
                                                      content: const Text(
                                                        "Are you sure you want to delete this student?",
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                              ),
                                                          child: const Text(
                                                            "Cancel",
                                                          ),
                                                        ),
                                                        ElevatedButton(
                                                          style:
                                                              ElevatedButton.styleFrom(
                                                                backgroundColor:
                                                                    Colors.red,
                                                              ),
                                                          onPressed: () async {
                                                            await deleteStudent(
                                                              student['student_id']
                                                                  .toString(),
                                                            );
                                                            await _fetchStudents();
                                                            if (!context
                                                                .mounted)
                                                              return;
                                                            Navigator.pop(
                                                              context,
                                                            );
                                                          },
                                                          child: const Text(
                                                            "Delete",
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
