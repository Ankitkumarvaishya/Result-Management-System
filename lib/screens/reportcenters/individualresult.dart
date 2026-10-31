import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:result/drawer/appdrawer.dart';

class IndividualResult extends StatefulWidget {
  const IndividualResult({super.key});

  @override
  State<IndividualResult> createState() => _IndividualResultState();
}

class _IndividualResultState extends State<IndividualResult> {
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

  Future<void> fetchExaminations() async {
    final prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('saved_host');
    var url = Uri.parse(
      "http://$host/resultsetupapi.php?action=fetchExaminations",
    );

    var response = await http.get(url);

    if (response.statusCode == 200) {
      setState(() {
        examinationsList = jsonDecode(response.body);
      });
    } else {
      print("Error fetching data");
    }
  }

  // Fetch report from API
  Future<void> _fetchReport() async {
    if (selectedYear == null ||
        selectedClassId == null ||
        selectedExam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Year, Class, and Exam.')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      String? host = prefs.getString('saved_host');
      if (host == null) return;

      var url = Uri.parse(
        "http://$host/prepareresultapi.php?action=getGradeByLedger",
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

      var resData = jsonDecode(response.body);
      if (resData["status"] == "success") {
        setState(() {
          subjectsList = resData["subjects"];
          extraActivitiesSetupList = resData["extra_activities_setup"] ?? [];
          reportList = resData["report"];
          selectedStudentRoll = kAllStudentsValue;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resData['message'] ?? 'Failed to load report'),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error fetching report: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Gradesheet PDF generation (single student or all students)
  // Future<Uint8List?> _fetchLogoBytes(String? logoUrl) async {
  //   if (logoUrl == null || logoUrl.trim().isEmpty) return null;
  //   try {
  //     final res = await http.get(Uri.parse(logoUrl));
  //     if (res.statusCode == 200) return res.bodyBytes;
  //   } catch (e) {
  //     debugPrint("Logo fetch failed: $e");
  //   }
  //   return null;
  // }
  Future<Uint8List?> _fetchLogoBytes(String? logoUrl) async {
    if (logoUrl == null || logoUrl.trim().isEmpty) return null;
    try {
      final uri = Uri.parse(logoUrl.trim());

      // Pass standard headers to avoid server blocking
      final res = await http
          .get(
            uri,
            headers: {
              'Accept': 'image/*',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        return res.bodyBytes;
      } else {
        debugPrint("Logo fetch failed with status code: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("Logo fetch failed error: $e");
    }
    return null;
  }

  Future<void> _generateResultPdf() async {
    if (reportList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please load the report first.')),
      );
      return;
    }
    final List<dynamic> studentsToPrint =
        (selectedStudentRoll == null ||
            selectedStudentRoll == kAllStudentsValue)
        ? reportList
        : reportList
              .where((r) => r['roll_number'].toString() == selectedStudentRoll)
              .toList();

    if (studentsToPrint.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected student not found in the report.'),
        ),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      // Replace these with real per-school branding lookups (API/local storage).
      final prefs = await SharedPreferences.getInstance();
      final schoolName = prefs.getString('school_name') ?? 'YOUR SCHOOL NAME';
      final schoolAddress =
          prefs.getString('school_address') ?? 'School Address';
      final schoolPhone = prefs.getString('school_phone') ?? '';
      final schoolLogoUrl = prefs.getString(
        'school_logo_url',
      ); // e.g. https://.../logo.png

      final logoBytes = await _fetchLogoBytes(schoolLogoUrl);

      final doc = _GradesheetPdfBuilder.buildDocument(
        students: studentsToPrint,
        subjectsList: subjectsList,
        extraActivitiesSetupList: extraActivitiesSetupList,
        schoolName: schoolName,
        schoolAddress: schoolAddress,
        schoolPhone: schoolPhone,
        schoolLogoBytes: logoBytes,
        examName: examName ?? '',
        className: selectedClassName ?? '',
        sectionName: hasSection ? (selectedSectionName ?? '') : '-',
        yearName: selectedYear ?? '',
        issueDate: issueDateController.text.trim(),
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _GradesheetPreviewScreen(buildPdf: doc.save),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
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
        title: const Text("Examination Management System"),
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
                            final selectedExamItem = examinationsList
                                .firstWhere(
                                  (item) =>
                                      item['exam_id'].toString() == newValue,
                                  orElse: () => null,
                                );

                            setState(() {
                              selectedExam = newValue;
                              examName = selectedExamItem?['exam_name'];
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Show Grade Sheet + Select Student + Generate Result — all one row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: isLoading ? null : _fetchReport,
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Show Grade Sheet'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStyledDropdown(
                          label: 'Select Student',
                          value: selectedStudentRoll,
                          hint: 'Student',
                          items: studentItems,
                          onChanged: reportList.isEmpty
                              ? null
                              : (v) {
                                  setState(() => selectedStudentRoll = v);
                                },
                        ),
                      ),
                      const SizedBox(width: 12),

                      SizedBox(
                        width: 160,
                        child: TextField(
                          controller: issueDateController,
                          decoration: InputDecoration(
                            labelText: 'Date of Issue',
                            hintText: 'e.g. 2026-08-08',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: (isLoading || reportList.isEmpty)
                            ? null
                            : _generateResultPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: Text(
                          selectedStudentRoll == kAllStudentsValue
                              ? 'Generate All Results'
                              : 'Generate Result',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: reportList.isEmpty
                      ? const Text(
                          'No results loaded. Select options and click "Show Grade Sheet".',
                          style: TextStyle(color: Colors.black54),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${reportList.length} student(s) loaded.',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Select a student (or All) and click Generate Result.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ],
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
// PDF preview screen — print / share / export built in

class _GradesheetPreviewScreen extends StatelessWidget {
  final Future<Uint8List> Function() buildPdf;
  const _GradesheetPreviewScreen({required this.buildPdf});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Result Preview')),
      body: PdfPreview(
        build: (format) => buildPdf(),
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false, // locked to A4
      ),
    );
  }
}

// Gradesheet PDF builder — one A4 page per student
class _GradesheetPdfBuilder {
  static const List<Map<String, String>> _defaultGradeScale = [
    {'range': '90 to 100', 'grade': 'A+', 'point': '4.0'},
    {'range': '80 to below 90', 'grade': 'A', 'point': '3.6'},
    {'range': '70 to below 80', 'grade': 'B+', 'point': '3.2'},
    {'range': '60 to below 70', 'grade': 'B', 'point': '2.8'},
    {'range': '50 to below 60', 'grade': 'C+', 'point': '2.4'},
    {'range': '40 to below 50', 'grade': 'C', 'point': '2.0'},
    {'range': '35 to below 40', 'grade': 'D', 'point': '1.6'},
    {'range': '0 to below 35', 'grade': 'NG', 'point': '-'},
    {'range': 'Absent', 'grade': 'Abs', 'point': '-'},
  ];
  static pw.Widget _issueDateRow(String issueDate) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.start,
      children: [
        pw.Text(
          'Date of Issue: ',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        ),
        pw.Text(
          issueDate.isNotEmpty ? issueDate : '-',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  static pw.Document buildDocument({
    required List<dynamic> students,
    required List<dynamic> subjectsList,
    required List<dynamic> extraActivitiesSetupList,
    required String schoolName,
    required String schoolAddress,
    required String schoolPhone,
    required Uint8List? schoolLogoBytes,
    required String examName,
    required String className,
    required String sectionName,
    required String yearName,
    required String issueDate,
  }) {
    final doc = pw.Document();
    //   final logoImage = schoolLogoBytes != null
    //       ? pw.MemoryImage(schoolLogoBytes)
    //       : null;

    //   for (final student in students) {
    //     doc.addPage(
    //       pw.Page(
    //         pageFormat: PdfPageFormat.a4,
    //         margin: const pw.EdgeInsets.all(16),
    //         build: (context) => pw.Container(
    //           decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.4)),
    //           padding: const pw.EdgeInsets.all(12),
    //           child: pw.Column(
    //             crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    //             children: [
    //               _header(schoolName, schoolAddress, schoolPhone, logoImage),
    //               pw.SizedBox(height: 6),
    //               _narrative(student, className, sectionName, examName, yearName),

    //               pw.Spacer(flex: 1),
    //               _subjectsTable(student, subjectsList),

    //               _summaryRow(student),

    //               pw.Spacer(flex: 1),
    //               if (extraActivitiesSetupList.isNotEmpty) ...[
    //                 _evaluationTable(student, extraActivitiesSetupList),
    //                 pw.Spacer(flex: 1),
    //               ],
    //               _gradeScaleTable(),

    //               pw.Spacer(flex: 1),
    //               _notesSection(),

    //               pw.Spacer(flex: 2),
    //               _signatures(),
    //               pw.SizedBox(height: 10),
    //               _issueDateRow(issueDate),
    //             ],
    //           ),
    //         ),
    //       ),
    //     );
    //   }

    //   return doc;
    // }
    // Safely attempt to decode image bytes into pdf MemoryImage
    pw.MemoryImage? logoImage;
    if (schoolLogoBytes != null && schoolLogoBytes.isNotEmpty) {
      try {
        logoImage = pw.MemoryImage(schoolLogoBytes);
      } catch (e) {
        debugPrint("Failed to decode PDF MemoryImage: $e");
        logoImage = null;
      }
    }

    for (final student in students) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (context) => pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.4)),
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _header(schoolName, schoolAddress, schoolPhone, logoImage),
                pw.SizedBox(height: 6),
                _narrative(student, className, sectionName, examName, yearName),
                pw.Spacer(flex: 1),
                _subjectsTable(student, subjectsList),
                _summaryRow(student),
                pw.Spacer(flex: 1),
                if (extraActivitiesSetupList.isNotEmpty) ...[
                  _evaluationTable(student, extraActivitiesSetupList),
                  pw.Spacer(flex: 1),
                ],
                _gradeScaleTable(),
                pw.Spacer(flex: 1),
                _notesSection(),
                pw.Spacer(flex: 2),
                _signatures(),
                pw.SizedBox(height: 10),
                _issueDateRow(issueDate),
              ],
            ),
          ),
        ),
      );
    }

    return doc;
  }

  // ---------- HEADER (logo + name + address + phone) ----------
  // static pw.Widget _header(
  //   String schoolName,
  //   String address,
  //   String phone,
  //   pw.MemoryImage? logo,
  // ) {
  //   return pw.Row(
  //     crossAxisAlignment: pw.CrossAxisAlignment.center,
  //     children: [
  //       pw.SizedBox(
  //         width: 55,
  //         height: 55,
  //         child: logo != null
  //             ? pw.Image(logo, fit: pw.BoxFit.contain)
  //             : pw.SizedBox(),
  //       ),
  //       pw.Expanded(
  //         child: pw.Column(
  //           children: [
  //             pw.Text(
  //               schoolName,
  //               textAlign: pw.TextAlign.center,
  //               style: pw.TextStyle(
  //                 fontSize: 20,
  //                 fontWeight: pw.FontWeight.bold,
  //               ),
  //             ),
  //             if (address.isNotEmpty)
  //               pw.Text(address, style: const pw.TextStyle(fontSize: 9)),
  //             if (phone.isNotEmpty)
  //               pw.Text(
  //                 'Phone: $phone',
  //                 style: const pw.TextStyle(fontSize: 9),
  //               ),
  //             pw.SizedBox(height: 4),
  //             pw.Text(
  //               'GRADE-SHEET',
  //               style: pw.TextStyle(
  //                 fontSize: 14,
  //                 fontWeight: pw.FontWeight.bold,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //       pw.SizedBox(
  //         width: 55,
  //       ), // mirrors logo width so title block stays centered
  //     ],
  //   );
  // }
  static pw.Widget _header(
    String schoolName,
    String address,
    String phone,
    pw.MemoryImage? logo,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SizedBox(
          width: 55,
          height: 55,
          child: logo != null
              ? pw.Center(child: pw.Image(logo, fit: pw.BoxFit.contain))
              : pw.SizedBox(),
        ),
        pw.Expanded(
          child: pw.Column(
            children: [
              pw.Text(
                schoolName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (address.isNotEmpty)
                pw.Text(address, style: const pw.TextStyle(fontSize: 9)),
              if (phone.isNotEmpty)
                pw.Text(
                  'Phone: $phone',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              pw.SizedBox(height: 4),
              pw.Text(
                'GRADE-SHEET',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(
          width: 55,
        ), // Mirrors logo width for symmetric header centering
      ],
    );
  }

  static pw.Widget _narrative(
    dynamic student,
    String className,
    String sectionName,
    String examName,
    String yearName,
  ) {
    pw.TextSpan bold(String t) => pw.TextSpan(
      text: t,
      style: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        decoration: pw.TextDecoration.underline,
      ),
    );
    pw.TextSpan plain(String t) => pw.TextSpan(text: t);

    final name = student['student_name']?.toString() ?? '';
    final roll = student['roll_number']?.toString() ?? '';
    final dob =
        student['dob']?.toString() ??
        student['date_of_birth']?.toString() ??
        '';

    return pw.RichText(
      textAlign: pw.TextAlign.justify,
      text: pw.TextSpan(
        style: const pw.TextStyle(fontSize: 11.5, lineSpacing: 4),
        children: [
          plain('THE GRADE SECURED BY '),
          bold(name),
          if (dob.isNotEmpty) ...[plain(' DATE OF BIRTH '), bold(dob)],
          plain(' ROLL NO. '),
          bold(roll),
          plain(' OF CLASS '),
          bold(className),
          plain(' SECTION '),
          bold(sectionName),
          plain(' IN THE '),
          bold(examName),
          plain(' HELD IN '),
          bold(yearName),
          plain(' ARE GIVEN BELOW.'),
        ],
      ),
    );
  }

  static const int _maxSubjectRows = 10;

  static pw.Widget _subjectsTable(dynamic student, List<dynamic> subjectsList) {
    final gradesMap = student['subject_grades'] ?? {};

    const double fontSize = 7.2;
    const double headerHeight = 24; // fixed total header height
    const double headerSubRowHeight = 12; // each sub-row inside OBTAINED GRADES

    final headerStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      fontSize: fontSize,
    );
    final cellStyle = pw.TextStyle(fontSize: fontSize);

    // ---- Header cell with fixed height (bounded, so Align works) ----
    pw.Widget headerCell(String text) => pw.Container(
      height: headerHeight,
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 3),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
      child: pw.Text(text, textAlign: pw.TextAlign.center, style: headerStyle),
    );

    // ---- "OBTAINED GRADES" group: label row + TH./PR. sub-row, both fixed height ----
    pw.Widget obtainedGradesHeader() => pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          height: headerSubRowHeight,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
          child: pw.Text(
            'OBTAINED GRADES',
            textAlign: pw.TextAlign.center,
            style: headerStyle,
          ),
        ),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Container(
                height: headerSubRowHeight,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
                child: pw.Text('TH.', style: headerStyle),
              ),
            ),
            pw.Expanded(
              child: pw.Container(
                height: headerSubRowHeight,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
                child: pw.Text('PR.', style: headerStyle),
              ),
            ),
          ],
        ),
      ],
    );

    final headerRow = pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(flex: 5, child: headerCell('S.N')),
        pw.Expanded(flex: 26, child: headerCell('SUBJECTS')),
        pw.Expanded(flex: 10, child: headerCell('CREDIT\nHOUR')),
        pw.Expanded(flex: 14, child: obtainedGradesHeader()),
        pw.Expanded(flex: 10, child: headerCell('TOTAL\nGRADE')),
        pw.Expanded(flex: 8, child: headerCell('GRADE\nPOINT')),
        pw.Expanded(flex: 16, child: headerCell('REMARKS')),
      ],
    );

    const double rowHeight = 20;

    pw.Widget cellText(String text, {pw.TextStyle? style}) => pw.Container(
      height: rowHeight,
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 2.0),
      child: pw.Text(
        text,
        style: style ?? cellStyle,
        textAlign: pw.TextAlign.center,
      ),
    );

    final int realCount = subjectsList.length > _maxSubjectRows
        ? _maxSubjectRows
        : subjectsList.length;

    // Precompute each row's 8 cell values (real subjects, then blanks).
    final List<List<String>> rowsData = [];
    for (int i = 0; i < _maxSubjectRows; i++) {
      if (i < realCount) {
        final sub = subjectsList[i];
        final key = sub['setup_id'].toString();
        final g = gradesMap[key];

        String th = '-',
            pr = '-',
            totalGrade = '-',
            gradePoint = '-',
            remarks = '-';
        if (g != null) {
          if (g['is_absent'] == 1) {
            th = 'Abs';
            pr = 'Abs';
            totalGrade = 'Abs';
            gradePoint = '-';
            remarks = g['subject_remarks']?.toString() ?? '-';
          } else {
            th = g['theory_grade']?.toString() ?? '-';
            pr = g['practical_grade']?.toString() ?? '-';
            totalGrade = g['subject_grade']?.toString() ?? '-';
            gradePoint = g['subject_gpa']?.toString() ?? '-';
            remarks = g['subject_remarks']?.toString() ?? '-';
          }
        }
        rowsData.add([
          '${i + 1}',
          sub['subject_name']?.toString() ?? '',
          sub['credit_hours']?.toString() ?? '-',
          th,
          pr,
          totalGrade,
          gradePoint,
          remarks,
        ]);
      } else {
        rowsData.add(['', '', '', '', '', '', '', '']);
      }
    }

    final flexList = [5, 26, 10, 7, 7, 10, 8, 16];
    // Build one column of stacked cells for a given data index, no horizontal lines.
    pw.Widget buildColumn(int colIndex, {bool bold = false}) {
      return pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: rowsData
            .map(
              (row) => cellText(
                row[colIndex],
                style: bold
                    ? cellStyle.copyWith(fontWeight: pw.FontWeight.bold)
                    : null,
              ),
            )
            .toList(),
      );
    }

    final bodyBlock = pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(width: 0.6),
          right: pw.BorderSide(width: 0.6),
          bottom: pw.BorderSide(width: 0.6),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: List.generate(flexList.length, (i) {
          final isLast = i == flexList.length - 1;
          return pw.Expanded(
            flex: flexList[i],
            child: pw.Container(
              decoration: isLast
                  ? null
                  : const pw.BoxDecoration(
                      border: pw.Border(right: pw.BorderSide(width: 0.6)),
                    ),
              child: buildColumn(i, bold: i == 1),
            ),
          );
        }),
      ),
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [headerRow, bodyBlock],
    );
  }

  static pw.Widget _summaryRow(dynamic student) {
    final attendance = student['attendance'];
    final totalDays =
        int.tryParse(attendance?['total_working_days']?.toString() ?? '0') ?? 0;
    final presentDays =
        int.tryParse(attendance?['days_present']?.toString() ?? '0') ?? 0;
    final attendanceText = totalDays > 0 ? '$presentDays/$totalDays' : '-';

    pw.Widget box(String label, String value, {int flex = 1}) => pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: const pw.EdgeInsets.all(4),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
        child: pw.Row(
          children: [
            pw.Text(
              '$label: ',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 8.5,
              ),
            ),
            pw.Expanded(
              child: pw.Text(value, style: const pw.TextStyle(fontSize: 8.5)),
            ),
          ],
        ),
      ),
    );

    return pw.Column(
      children: [
        pw.Row(
          children: [
            box('Remarks', student['remarks']?.toString() ?? '-', flex: 2),
            box('G.P.A', student['gpa']?.toString() ?? '-'),
          ],
        ),
        pw.Row(
          children: [
            box('Attendance', attendanceText),
            box('Result', student['overall_result']?.toString() ?? '-'),
            box('Rank', student['rank_in_class']?.toString() ?? '-'),
          ],
        ),
      ],
    );
  }

  static pw.Widget _evaluationTable(
    dynamic student,
    List<dynamic> extraActivitiesSetupList,
  ) {
    final extraMap = student['extra_activities'] ?? {};

    final titles = <String>[];
    final grades = <String>[];

    for (final ea in extraActivitiesSetupList) {
      titles.add(ea['activity_name']?.toString() ?? '');
      final key = ea['setup_id'].toString();
      final em = extraMap[key];
      String val = '-';
      if (em != null) {
        val = em['is_absent'] == 1
            ? 'Abs'
            : (em['grade_or_score']?.toString() ?? '-');
      }
      grades.add(val);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Center(
          child: pw.Text(
            'EXTRA CURRICULAR ACTIVITIES',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Table(
          border: pw.TableBorder.all(width: 0.6),
          children: [
            pw.TableRow(
              children: titles
                  .map(
                    (t) => pw.Padding(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Text(
                        t,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8.5,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            pw.TableRow(
              children: grades
                  .map(
                    (g) => pw.Padding(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Text(
                        g,
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ],
    );
  }

  // ---------- Grade scale: single 6-column table so both halves line up exactly ----------
  static pw.Widget _gradeScaleTable() {
    final headerStyle = pw.TextStyle(
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
    );
    final cellStyle = const pw.TextStyle(fontSize: 8);

    pw.Widget cell(String t, {pw.TextStyle? style}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 3),
      child: pw.Text(
        t,
        style: style ?? cellStyle,
        textAlign: pw.TextAlign.center,
      ),
    );

    final rows = <pw.TableRow>[
      pw.TableRow(
        children: [
          cell('Percentage', style: headerStyle),
          cell('Grade', style: headerStyle),
          cell('Grade Point', style: headerStyle),
        ],
      ),
    ];

    for (final entry in _defaultGradeScale) {
      rows.add(
        pw.TableRow(
          children: [
            cell(entry['range']!),
            cell(entry['grade']!),
            cell(entry['point']!),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.0),
        1: const pw.FlexColumnWidth(1.0),
        2: const pw.FlexColumnWidth(1.3),
      },
      children: rows,
    );
  }

  // ---------- Notes box, sits right above the signature line ----------
  static pw.Widget _notesSection() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Notes:',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
        ),

        pw.SizedBox(height: 3),
        pw.Container(
          height: 30,
          width: double.infinity,
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'TH: THEORY , PR: PRACTICAL, GPA: GRADE POINT AVERAGE,NG: NOT GRADED AND ONE CREDIT HOUR IS EQUALS TO 32 WORKING HOURS ',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _signatures() {
    pw.Widget sig(String label) => pw.Expanded(
      child: pw.Column(
        children: [
          pw.Text(
            '----------------------',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );

    return pw.Row(
      children: [
        sig('Class Teacher'),
        sig('Exam Co-ordinator'),
        sig('Principal'),
      ],
    );
  }
}
