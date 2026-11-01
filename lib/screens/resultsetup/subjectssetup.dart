import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:result/drawer/appdrawer.dart';
import 'package:result/screens/schoolconfiguration/school_config.dart';

// --- IMPORT PDF AND PRINTING PACKAGES ---
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class Subjectssetup extends StatefulWidget {
  const Subjectssetup({super.key});

  @override
  State<Subjectssetup> createState() => _SubjectssetupState();
}

class _SubjectssetupState extends State<Subjectssetup> {
  final TextEditingController _subjectNameController = TextEditingController();
  final TextEditingController _subjectCodeController = TextEditingController();
  final TextEditingController _creditHourController = TextEditingController();
  List<dynamic> SubjectsList = [];
  List<dynamic> _filteredSubjects =
      []; // The data displayed in the table / exported
  List<dynamic> academicYearClasses = [];
  Map<String, dynamic>? selectedClass;
  String? classIdStr;
  Timer? _timer;
  final TextEditingController _searchController = TextEditingController();

  // --- NEW SORTING STATE TRACKERS ---
  int? _sortColumnIndex;
  bool _isAscending = true;

  @override
  void dispose() {
    _subjectNameController.dispose();
    _subjectCodeController.dispose();
    _creditHourController.dispose();
    _timer?.cancel();
    _searchController.dispose();
    SubjectsList.clear();
    academicYearClasses.clear();
    _filteredSubjects.clear();
    super.dispose();
  }

  // Filtering logic for Subject Name, Subject Code and Class Name
  void _filterSubjectsData() {
    String query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      _filteredSubjects = List.from(SubjectsList);
    } else {
      _filteredSubjects = SubjectsList.where((item) {
        String subjectName =
            item['subject_name']?.toString().toLowerCase() ?? '';
        String subjectCode =
            item['subject_code']?.toString().toLowerCase() ?? '';
        String className = item['class_name']?.toString().toLowerCase() ?? '';

        return subjectName.contains(query) ||
            subjectCode.contains(query) ||
            className.contains(query);
      }).toList();
    }
  }

  // Saving the exam details
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('saved_host');

    if (classIdStr == null || classIdStr == "null" || classIdStr!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text("Please select a target class profile.")),
        ),
      );
      return;
    }

    if (_subjectNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text("Please enter a subject name.")),
        ),
      );
      return;
    }

    try {
      var res = await http.post(
        Uri.parse("http://$host/resultsetupapi.php?action=savesubjectdetails"),
        body: {
          "class_id": classIdStr.toString(),
          "subject_name": _subjectNameController.text.toUpperCase().trim(),
          "subject_code": _subjectCodeController.text.toUpperCase().trim(),
          "credit_hours": _creditHourController.text.trim(),
        },
      );

      var response = jsonDecode(res.body);

      if (response["status"] == "success") {
        _subjectNameController.clear();
        _subjectCodeController.clear();
        _creditHourController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Center(child: Text("Subject Registered Successfully!")),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Center(
              child: Text(response["message"] ?? "Subject Entry Failed!"),
            ),
          ),
        );
      }
    } catch (e) {
      print("Caught Error: $e");
    }
  }

  // Fetch classes of current academic year
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
          academicYearClasses = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Error fetching classes: $e");
    }
  }

  /// 🔷 FETCH DATA FROM PHP WITH CONTINUOUS SORT PERSISTENCE
  Future<void> fetchSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('saved_host');
    if (host == null) return;

    var url = Uri.parse("http://$host/resultsetupapi.php?action=fetchSubjects");
    var response = await http.get(url);

    if (response.statusCode == 200) {
      List<dynamic> fetchedList = jsonDecode(response.body);

      // If a sorting configuration is active, ensure freshly polled background data retains the configuration order
      if (_sortColumnIndex != null) {
        _sortData(
          _sortColumnIndex!,
          _isAscending,
          immediateSetState: false,
          dynamicList: fetchedList,
        );
      }

      setState(() {
        SubjectsList = fetchedList;
        _filterSubjectsData();
      });
    } else {
      print("Error fetching data");
    }
  }

  Future<void> deleteSubjects(var id) async {
    final prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('saved_host');
    var url = Uri.parse(
      "http://$host/resultsetupapi.php?action=deleteSubjects",
    );

    var response = await http.post(url, body: {"id": id});

    if (response.statusCode == 200) {
      fetchSubjects();
    } else {
      print("Delete failed");
    }
  }

  //update subjects
  Future<void> updateSubjects(
    String id,
    String classId,
    String subjectName,
    String subjectCode,
    String creditHours,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('saved_host');
    var url = Uri.parse(
      "http://$host/resultsetupapi.php?action=updatesubjects",
    );

    var response = await http.post(
      url,
      body: {
        "subject_id": id,
        "class_id": classId,
        "subject_name": subjectName,
        "subject_code": subjectCode,
        "credit_hours": creditHours,
      },
    );

    if (response.statusCode == 200) {
      fetchSubjects(); // Refresh the table
    } else {
      print("Update failed");
    }
  }

  //dialog box to update
  void showEditDialog(Map<String, dynamic> item) {
    // Initialize controllers with current values from the selected row
    TextEditingController nameController = TextEditingController(
      text: item['subject_name']?.toString() ?? '',
    );
    TextEditingController codeController = TextEditingController(
      text: item['subject_code']?.toString() ?? '',
    );
    TextEditingController creditController = TextEditingController(
      text: item['credit_hours']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Subject"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Subject Name"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: "Subject Code"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: creditController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Credit Hours"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () {
                updateSubjects(
                  item['subject_id'].toString(),
                  item['class_id'].toString(),
                  nameController.text,
                  codeController.text,
                  creditController.text,
                );
                Navigator.pop(context);
              },
              child: const Text(
                "Save Changes",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- NEW SORTING METHOD ROUTINE ---
  void _sortData(
    int columnIndex,
    bool ascending, {
    bool immediateSetState = true,
    List<dynamic>? dynamicList,
  }) {
    List<dynamic> targetList = dynamicList ?? SubjectsList;

    targetList.sort((a, b) {
      dynamic valueA;
      dynamic valueB;

      // Map columnIndex layout keys matching DataTable definitions
      switch (columnIndex) {
        case 1: // Subject Name Column
          valueA = a['subject_name']?.toString().toLowerCase() ?? '';
          valueB = b['subject_name']?.toString().toLowerCase() ?? '';
          break;
        case 2: // Subject Code Column
          valueA = a['subject_code']?.toString().toLowerCase() ?? '';
          valueB = b['subject_code']?.toString().toLowerCase() ?? '';
          break;
        case 3: // Credit Hours Column (Parse numeric values cleanly to sort correctly mathematically instead of alphabetically)
          valueA = double.tryParse(a['credit_hours']?.toString() ?? '0') ?? 0.0;
          valueB = double.tryParse(b['credit_hours']?.toString() ?? '0') ?? 0.0;
          break;
        case 4: // Active Year Column
          valueA = a['year_name']?.toString().toLowerCase() ?? '';
          valueB = b['year_name']?.toString().toLowerCase() ?? '';
          break;
        case 5: // Class Name Column
          valueA = a['class_name']?.toString().toLowerCase() ?? '';
          valueB = b['class_name']?.toString().toLowerCase() ?? '';
          break;
        default:
          return 0;
      }

      if (valueA is num && valueB is num) {
        return ascending ? valueA.compareTo(valueB) : valueB.compareTo(valueA);
      }
      return ascending
          ? valueA.toString().compareTo(valueB.toString())
          : valueB.toString().compareTo(valueA.toString());
    });

    if (immediateSetState) {
      setState(() {
        _sortColumnIndex = columnIndex;
        _isAscending = ascending;
      });
    }
  }

  // SHARED SCHOOL HEADER HELPERS (same pattern as Enrollment page)

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
                  style: pw.TextStyle(fontSize: 18),
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
        pw.Text("Subjects Report", style: pw.TextStyle(fontSize: 14)),
        pw.SizedBox(height: 10),
      ],
    );
  }
  // ---------------------------------------------------------------------

  // --- METHOD TO GENERATE AND EXPORT DATA TO A4 PDF (same style as Enrollment) ---
  Future<void> _exportSubjectsToPdf() async {
    if (_filteredSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No fetched data to save to PDF!")),
      );
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
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: [
              'S.N.',
              'SUBJECT NAME',
              'SUBJECT CODE',
              'CREDIT HOURS',
              'ACTIVE YEAR',
              'CLASS NAME',
            ],
            data: _filteredSubjects.asMap().entries.map((entry) {
              int index = entry.key;
              var item = entry.value;
              return [
                (index + 1).toString(),
                (item['subject_name'] ?? '-').toString().toUpperCase(),
                (item['subject_code'] ?? '-').toString().toUpperCase(),
                (item['credit_hours'] ?? '-').toString().toUpperCase(),
                (item['year_name'] ?? '-').toString().toUpperCase(),
                (item['class_name'] ?? '-').toString().toUpperCase(),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey800,
            ),
            cellStyle: pw.TextStyle(fontSize: 8.5),
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
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
              1: const pw.FlexColumnWidth(2.0),
              2: const pw.FlexColumnWidth(1.4),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.4),
              5: const pw.FlexColumnWidth(1.6),
            },
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "Total Records: ${_filteredSubjects.length}",
              style: pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'subjects_list_report.pdf',
    );
  }

  // --- METHOD TO EXPORT DATA TO EXCEL (same style as Enrollment) ---
  Future<void> _exportSubjectsToExcel() async {
    if (_filteredSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No subject data available to export.')),
      );
      return;
    }

    try {
      // 1. Create Excel Workbook and Sheet
      final excelFile = excel.Excel.createExcel();
      final excel.Sheet sheet = excelFile['Subjects'];
      excelFile.delete('Sheet1'); // Remove default tab

      // 1a. School details header
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

      writeSchoolHeaderRow("Subjects Report", bold: true, size: 13);
      currentRow++; // blank row

      // 2. Define Table Headers
      final List<String> headers = [
        'S.N.',
        'Subject Name',
        'Subject Code',
        'Credit Hours',
        'Active Year',
        'Class Name',
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

      // 3. Write Subject Data Rows
      for (int rowIdx = 0; rowIdx < _filteredSubjects.length; rowIdx++) {
        final item = _filteredSubjects[rowIdx];

        final sn = rowIdx + 1;
        final subjectName = item['subject_name']?.toString() ?? '-';
        final subjectCode = item['subject_code']?.toString() ?? '-';
        final creditHours = item['credit_hours'] != null
            ? num.tryParse(item['credit_hours'].toString()) ??
                  item['credit_hours'].toString()
            : '-';
        final yearName = item['year_name']?.toString() ?? '-';
        final className = item['class_name']?.toString() ?? '-';

        final List<dynamic> rowData = [
          sn,
          subjectName,
          subjectCode,
          creditHours,
          yearName,
          className,
        ];

        final int dataRowIndex = currentRow + rowIdx;

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
                : excel.HorizontalAlign.Left,
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
          'Subjects_List_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      String? outputPath = await FilePicker.saveFile(
        dialogTitle: 'Save Subjects List Excel',
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
              'Subjects exported successfully!\nSaved to: $outputPath',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error exporting subjects to Excel: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export subjects list: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    fetchSubjects();
    fetchClassDataOfAcademicYear();
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) => fetchSubjects(),
    );
    _searchController.addListener(() {
      setState(() {
        _filterSubjectsData();
      });
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
          // Left Half of the Screen
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Select The Class:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  DropdownButtonFormField<dynamic>(
                    initialValue: selectedClass,
                    hint: const Text("Select Class Target"),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: academicYearClasses.map((dynamic singleClass) {
                      return DropdownMenuItem<dynamic>(
                        value: singleClass,
                        child: Text("${singleClass['class_name']}"),
                      );
                    }).toList(),
                    onChanged: (dynamic newValue) {
                      setState(() {
                        selectedClass = newValue;
                      });
                      if (newValue != null) {
                        classIdStr = newValue['class_id'].toString();
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Subject Name:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _subjectNameController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter subject name (e.g., English , Nepali)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Subject Code:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _subjectCodeController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter subject code (e.g., ENG101)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Credit Hours:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _creditHourController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter subject Credit Hour',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                        ),
                        child: const Text("Save"),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () {
                          _subjectNameController.clear();
                          _subjectCodeController.clear();
                          _creditHourController.clear();
                        },
                        child: const Text("Clear"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Right Half of the Screen (Displaying the Sorted Data Table)
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.green.shade50,
              child: Column(
                children: [
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left side: buttons
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _exportSubjectsToPdf,
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
                              onPressed: _exportSubjectsToExcel,
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
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: "Search Subject, Code or Class",
                              hintText: "Type to search...",
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
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
                  Text(
                    "List of Subjects For Every Classes",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          // --- LINK SORTING TRACKERS TO DATATABLE PROPERTY CONFIGURATIONS ---
                          sortColumnIndex: _sortColumnIndex,
                          sortAscending: _isAscending,
                          columns: [
                            const DataColumn(label: Text("S.N.")),
                            DataColumn(
                              label: const Text("Subject Name"),
                              onSort: (columnIndex, ascending) =>
                                  _sortData(columnIndex, ascending),
                            ),
                            DataColumn(
                              label: const Text("Subject Code"),
                              onSort: (columnIndex, ascending) =>
                                  _sortData(columnIndex, ascending),
                            ),
                            DataColumn(
                              label: const Text("Credit Hours"),
                              onSort: (columnIndex, ascending) =>
                                  _sortData(columnIndex, ascending),
                            ),
                            DataColumn(
                              label: const Text("Active Year"),
                              onSort: (columnIndex, ascending) =>
                                  _sortData(columnIndex, ascending),
                            ),
                            DataColumn(
                              label: const Text("Class Name"),
                              onSort: (columnIndex, ascending) =>
                                  _sortData(columnIndex, ascending),
                            ),
                            const DataColumn(label: Text("Actions")),
                          ],
                          rows: _filteredSubjects.asMap().entries.map((entry) {
                            int index = entry.key;
                            var item = entry.value;
                            return DataRow(
                              cells: [
                                DataCell(Text((index + 1).toString())),
                                DataCell(
                                  Text(
                                    item['subject_name']
                                        .toString()
                                        .toUpperCase(),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    item['subject_code']
                                        .toString()
                                        .toUpperCase(),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    item['credit_hours']
                                        .toString()
                                        .toUpperCase(),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    item['year_name'].toString().toUpperCase(),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    item['class_name'].toString().toUpperCase(),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          showEditDialog(item);
                                        },
                                        icon: Icon(
                                          Icons.edit,
                                          color: Colors.green,
                                        ),
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
                                                  "Are you sure you want to delete this examination?",
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: const Text("Cancel"),
                                                  ),
                                                  ElevatedButton(
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                    onPressed: () {
                                                      deleteSubjects(
                                                        item['subject_id']
                                                            .toString(),
                                                      );
                                                      Navigator.pop(context);
                                                    },
                                                    child: const Text("Delete"),
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
