import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:result/screens/schoolconfiguration/school_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:result/drawer/appdrawer.dart';

// 1. IMPORT PDF AND PRINTING PACKAGES
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ExtraActivitiesSetup extends StatefulWidget {
  const ExtraActivitiesSetup({super.key});

  @override
  State<ExtraActivitiesSetup> createState() => _ExtraActivitiesSetupState();
}

class _ExtraActivitiesSetupState extends State<ExtraActivitiesSetup> {
  final TextEditingController _activityNameController = TextEditingController();
  List<dynamic> SubjectsList = [];
  List<dynamic> academicYearClasses = [];
  Map<String, dynamic>? selectedClass;
  String? classIdStr;
  Timer? _timer;

  @override
  void dispose() {
    _activityNameController.dispose();
    _timer?.cancel();
    SubjectsList.clear();
    academicYearClasses.clear();
    super.dispose();
  }

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

    if (_activityNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text("Please enter a subject name.")),
        ),
      );
      return;
    }

    try {
      var res = await http.post(
        Uri.parse("http://$host/resultsetupapi.php?action=addExtraActivity"),
        body: {
          "class_id": classIdStr.toString(),
          "activity_name": _activityNameController.text.trim(),
        },
      );

      var response = jsonDecode(res.body);

      if (response is Map<String, dynamic>) {
        if (response["status"] == "Success") {
          _activityNameController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              content: Center(child: Text("Activity Registered Successfully!")),
            ),
          );
          fetchExtraActivities(); // Refresh table immediately after save
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Center(
                child: Text(
                  response["message"] ?? "Activity Registration Failed!",
                ),
              ),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Center(child: Text("An error occurred: $e")),
        ),
      );
    }
  }

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

  Future<void> fetchExtraActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? host = prefs.getString('saved_host');
      if (host == null) return;

      var url = Uri.parse(
        "http://$host/resultsetupapi.php?action=fetchExtraActivities",
      );
      var response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          SubjectsList = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
    }
  }

  Future<void> deleteExtraActivities(var id) async {
    final prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('saved_host');
    var url = Uri.parse(
      "http://$host/resultsetupapi.php?action=deleteExtraActivities",
    );

    var response = await http.post(url, body: {"id": id});

    if (response.statusCode == 200) {
      fetchExtraActivities();
    }
  }

  // 2. FUNCTION TO GENERATE AND PRINT PDF
  // Future<void> _printPdf() async {
  //   final pdf = pw.Document();

  //   pdf.addPage(
  //     pw.MultiPage(
  //       pageFormat: PdfPageFormat.a4,
  //       margin: const pw.EdgeInsets.all(32),
  //       build: (pw.Context context) {
  //         return [
  //           pw.Header(
  //             level: 0,
  //             child: pw.Center(
  //               child: pw.Text(
  //                 "Extra Activities Report",
  //                 style: pw.TextStyle(
  //                   fontSize: 24,
  //                   fontWeight: pw.FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //           ),
  //           pw.SizedBox(height: 20),
  //           pw.TableHelper.fromTextArray(
  //             headers: ['S.N.', 'Activity Name', 'Class Name', 'Active Year'],
  //             data: SubjectsList.asMap().entries.map((entry) {
  //               int index = entry.key;
  //               var item = entry.value;
  //               return [
  //                 (index + 1).toString(),
  //                 item['activity_name'].toString().toUpperCase(),
  //                 item['class_name'].toString().toUpperCase(),
  //                 item['year_name'].toString().toUpperCase(),
  //               ];
  //             }).toList(),
  //             headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //             headerDecoration: const pw.BoxDecoration(
  //               color: PdfColors.grey300,
  //             ),
  //             cellAlignment: pw.Alignment.centerLeft,
  //             cellHeight: 30,
  //           ),
  //         ];
  //       },
  //     ),
  //   );

  //   // Displays the system print preview sheet allowing saving as PDF
  //   await Printing.layoutPdf(
  //     onLayout: (PdfPageFormat format) async => pdf.save(),
  //     name: 'Extra_Activities_Report.pdf',
  //   );
  // }
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

  Future<pw.Widget> _buildPdfHeader({
    String reportTitle = "Extra Activities Report",
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
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }

  Future<void> _printPdf() async {
    if (SubjectsList.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No activity data available to export.'),
          ),
        );
      }
      return;
    }

    final pdf = pw.Document(theme: pw.ThemeData.withFont());

    // Builds header including School Logo, Name, Address, Phone, and custom Report Title
    final header = await _buildPdfHeader(
      reportTitle: "Extra Activities Report",
    );

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
            headers: ["S.N.", "ACTIVITY NAME", "CLASS NAME", "ACTIVE YEAR"],
            data: SubjectsList.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return [
                (index + 1).toString(),
                (item['activity_name'] ?? '-').toString().toUpperCase(),
                (item['class_name'] ?? '-').toString().toUpperCase(),
                (item['year_name'] ?? '-').toString().toUpperCase(),
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
              2: pw.Alignment.center,
              3: pw.Alignment.center,
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
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(1.6),
              3: const pw.FlexColumnWidth(1.4),
            },
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "Total Records: ${SubjectsList.length}",
              style: pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Extra_Activities_Report.pdf',
    );
  }

  @override
  void initState() {
    super.initState();
    fetchExtraActivities();
    fetchClassDataOfAcademicYear();

    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) => fetchExtraActivities(),
    );
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
                    value: selectedClass,
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
                    "Activities Name:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _activityNameController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText:
                          'Enter Extra Activities (e.g., Dancing , Singing)',
                    ),
                  ),
                  const SizedBox(height: 8),
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
                        onPressed: () => _activityNameController.clear(),
                        child: const Text("Clear"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Right Half of the Screen
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.green.shade50,
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // 3. ACTION BAR WITH GENERATE PDF BUTTON
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Extra Cirricular Activities of Every Classes",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        ElevatedButton.icon(
                          onPressed: _printPdf,
                          icon: const Icon(
                            Icons.download,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Export to PDF',
                            style: TextStyle(fontSize: 14, color: Colors.white),
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
                  const SizedBox(height: 10),

                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text("S.N.")),
                            DataColumn(label: Text("Activity Name")),
                            DataColumn(label: Text("Class Name")),
                            DataColumn(label: Text("Active Year")),
                            DataColumn(label: Text("Actions")),
                          ],
                          rows: SubjectsList.asMap().entries.map((entry) {
                            int index = entry.key;
                            var item = entry.value;
                            return DataRow(
                              cells: [
                                DataCell(Text((index + 1).toString())),
                                DataCell(
                                  Text(
                                    item['activity_name']
                                        .toString()
                                        .toUpperCase(),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    item['class_name'].toString().toUpperCase(),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    item['year_name'].toString().toUpperCase(),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    children: [
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
                                                  "Are you sure you want to delete this activity?",
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
                                                      deleteExtraActivities(
                                                        item['activity_id']
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
