import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';

import 'package:result/drawer/appdrawer.dart';

import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:result/screens/schoolconfiguration/school_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:excel/excel.dart' as xls;

class ClassSetup extends StatefulWidget {
  const ClassSetup({super.key});

  @override
  State<ClassSetup> createState() => _ClassSetupState();
}

class _ClassSetupState extends State<ClassSetup> {
  List<dynamic> academicYears = [];
  String? selectedYearId;
  String? selectedYearName;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController classController = TextEditingController();
  Comparable<dynamic> Function(dynamic)? _currentSortField;

  String section = "NO"; // default

  Future<void> saveClass() async {
    if (_formKey.currentState!.validate()) {
      String className = classController.text;
      final prefs = await SharedPreferences.getInstance();

      // Here you are "reading" that saved variable back from the disk
      String? host = prefs.getString('saved_host');
      print("Class: $className");
      print("Section Available: $section");
      try {
        var res = await http.post(
          Uri.parse("http://$host/systemsetupapi.php?action=insertclasses"),
          body: {
            'class_name': className.toUpperCase(),
            'section': section.toUpperCase(),
          },
        );
        print("RAW RESPONSE FROM SERVER: ${res.body}");
        var response = jsonDecode(res.body);
        if (response["status"] == "success") {
          print("Record inserted");
        } else {
          print("Server Error: ${response["error"]}");
        }
      } catch (e) {
        print("Caught Error: $e");
      }
      classController.clear();
      setState(() {
        section = "NO";
      });
    }
  }

  void clearForm() {
    classController.clear();
    setState(() {
      section = "NO";
    });
  }

  /// 🔷 FETCH DATA FROM PHP
  Future<void> fetchClassDataOfAcademicYear() async {
    final prefs = await SharedPreferences.getInstance();

    // Here you are "reading" that saved variable back from the disk
    String? host = prefs.getString('saved_host');
    var url = Uri.parse(
      "http://$host/systemsetupapi.php?action=fetchclassdataofacademicyear",
    );

    var response = await http.get(url);

    if (response.statusCode == 200) {
      print(response.body);
      setState(() {
        academicYears = jsonDecode(response.body);
        // Re-apply sorting if active...
        if (_currentSortField != null && _sortColumnIndex != null) {
          academicYears.sort((a, b) {
            var aVal = _currentSortField!(a);
            var bVal = _currentSortField!(b);
            return _sortAscending
                ? Comparable.compare(aVal, bVal)
                : Comparable.compare(bVal, aVal);
          });
        }

        // Update filtered list based on current search query
        _filterData();
      });
    } else {
      print("Error fetching data");
    }
  }

  Future<void> deleteClasses(var id) async {
    final prefs = await SharedPreferences.getInstance();

    // Here you are "reading" that saved variable back from the disk
    String? host = prefs.getString('saved_host');
    var url = Uri.parse(
      "http://$host/systemsetupapi.php?action=deleteclassofacademicyear",
    );

    var response = await http.post(url, body: {"id": id});

    if (response.statusCode == 200) {
      print("Response: ${response.body}");
      fetchClassDataOfAcademicYear(); // refresh table
    } else {
      print("Delete failed");
    }
  }

  /// If your logo instead comes from a file/network path, swap this out.
  Future<Uint8List> _loadLogoBytes() async {
    final path = SchoolConfig.logoPath;
    if (path == null || path.isEmpty) {
      return Uint8List(0);
    }
    try {
      final file = File(path);
      if (!await file.exists()) {
        print("Logo file does not exist at: $path");
        return Uint8List(0);
      }
      return await file.readAsBytes();
    } catch (e) {
      print("Could not load school logo: $e");
      return Uint8List(0);
    }
  }

  /// 🔷 Shared header widget for the PDF export: logo + school name/address/phone
  /// + "Classes List - Academic Year: X" title.
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
          "List of Classes for the current academic year",
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }

  Future<void> printAcademicYears() async {
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
            headers: ["S.N.", "CLASS NAME", "YEAR", "SECTION"],
            data: filteredAcademicYears.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return [
                (index + 1).toString(),
                item['class_name'].toString(),
                item['year_name'].toString(),
                item['section'].toString(),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontSize: 10, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey800,
            ),
            cellStyle: pw.TextStyle(fontSize: 9.5),
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
              0: const pw.FlexColumnWidth(0.7),
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.3),
            },
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "Total Classes: ${filteredAcademicYears.length}",
              style: pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  /// 🔷 EXPORT TO EXCEL
  Future<void> exportClassesToExcel() async {
    final workbook = xls.Excel.createExcel();
    const sheetName = 'Classes';
    final sheet = workbook[sheetName];

    // Remove the default auto-created sheet if it's not the one we want
    if (workbook.sheets.keys.contains('Sheet1') && sheetName != 'Sheet1') {
      workbook.delete('Sheet1');
    }

    void styledHeaderCell(String text, {bool bold = true, double size = 12}) {
      sheet.appendRow([xls.TextCellValue(text)]);
      final cell = sheet.cell(
        xls.CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: sheet.maxRows - 1,
        ),
      );
      cell.cellStyle = xls.CellStyle(bold: bold, fontSize: size.toInt());
    }

    // School header block
    styledHeaderCell(SchoolConfig.schoolName, bold: true, size: 16);
    styledHeaderCell(SchoolConfig.address, bold: false, size: 11);
    styledHeaderCell(SchoolConfig.phoneNumber, bold: false, size: 11);
    sheet.appendRow([]); // blank spacer row

    styledHeaderCell(
      "List of Classes conducted for given academic year",
      bold: true,
      size: 13,
    );
    sheet.appendRow([]); // blank spacer row

    // Table header row
    sheet.appendRow([
      xls.TextCellValue("S.N."),
      xls.TextCellValue("Class Name"),
      xls.TextCellValue("Year"),
      xls.TextCellValue("Section"),
    ]);
    final headerRowIndex = sheet.maxRows - 1;
    for (var col = 0; col < 4; col++) {
      final cell = sheet.cell(
        xls.CellIndex.indexByColumnRow(
          columnIndex: col,
          rowIndex: headerRowIndex,
        ),
      );
      cell.cellStyle = xls.CellStyle(bold: true);
    }

    // Table rows
    for (var i = 0; i < filteredAcademicYears.length; i++) {
      final item = filteredAcademicYears[i];
      sheet.appendRow([
        xls.IntCellValue(i + 1),
        xls.TextCellValue(item['class_name'].toString()),
        xls.TextCellValue(item['year_name'].toString()),
        xls.TextCellValue(item['section'].toString()),
      ]);
    }

    final encoded = workbook.encode();
    if (encoded == null) {
      print("Failed to encode Excel workbook");
      return;
    }
    final bytes = Uint8List.fromList(encoded);

    final safeYearName = (selectedYearName ?? 'all').replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );

    try {
      var outputPath = await FilePicker.saveFile(
        dialogTitle: 'Save Classes Report',
        fileName: 'classes_report_$safeYearName.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: kIsWeb ? bytes : null, // only needed on web
      );

      if (outputPath == null) return; // user cancelled the dialog

      if (!kIsWeb) {
        // Desktop/mobile: saveFile only returns a chosen path, it doesn't
        // write the file itself — we write it ourselves, exactly once.
        if (!outputPath.toLowerCase().endsWith('.xlsx')) {
          outputPath = '$outputPath.xlsx';
        }
        final file = File(outputPath);
        await file.writeAsBytes(bytes);
      }
      // On web, file_picker already triggered the browser download using `bytes`.

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(kIsWeb ? 'Downloaded' : 'Saved to $outputPath')),
      );
    } catch (e) {
      print("Export failed: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    fetchClassDataOfAcademicYear();
    // Listen to search input changes for real-time filtering
    _searchController.addListener(_filterData);
  }

  void _filterData() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredAcademicYears = List.from(academicYears);
      } else {
        filteredAcademicYears = academicYears.where((item) {
          String className = item['class_name'].toString().toLowerCase();
          return className.contains(query);
        }).toList();
      }
    });
  }

  // Tracking sorting state
  int? _sortColumnIndex;
  bool _sortAscending = true;

  // Sorting function
  void _sortData<T>(
    Comparable<T> Function(dynamic item) getField,
    int columnIndex,
    bool ascending,
  ) {
    _currentSortField = getField; // Save the rule
    _sortColumnIndex = columnIndex;
    _sortAscending = ascending;
    academicYears.sort((a, b) {
      if (!ascending) {
        final c = a;
        a = b;
        b = c;
      }
      return Comparable.compare(getField(a), getField(b));
    });
    _filterData();
  }

  // Search and filtering state
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> filteredAcademicYears =
      []; // This will hold the items displayed in the table
  @override
  void dispose() {
    // CRITICAL: Stop the timer when the screen is closed
    academicYears.clear();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,

        title: Text("Result Management System"),
      ),
      drawer: const AppDrawer(),

      body: Row(
        children: [
          /// LEFT DASHBOARD
          Expanded(
            flex: 1, // 1 part
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Card(
                  elevation: 3,
                  margin: const EdgeInsets.all(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),

                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// 🔷 TITLE
                          const Text(
                            "Class Setup",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 20),

                          /// 🔷 CLASS NAME FIELD
                          TextFormField(
                            controller: classController,
                            decoration: const InputDecoration(
                              labelText: "Enter Class Name",
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Class name is required";
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          Row(
                            children: [
                              RadioGroup<String>(
                                // You define the group logic ONCE here
                                groupValue: section,
                                onChanged: (String? value) {
                                  setState(() {
                                    section = value!;
                                  });
                                },
                                child: Row(
                                  children: [
                                    const Text("Section: "),

                                    Radio<String>(value: "YES"),
                                    const Text("YES"),

                                    const SizedBox(width: 20),

                                    Radio<String>(value: "NO"),
                                    const Text("NO"),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              /// 🔷 BUTTONS
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () async {
                                  await saveClass();

                                  // Refresh data instantly upon returning
                                  await fetchClassDataOfAcademicYear();
                                },
                                child: const Text("Save"),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: clearForm,
                                child: const Text("Clear"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          /// RIGHT DASHBOARD
          Expanded(
            flex: 2, // 2 parts (wider)
            child: Container(
              color: Colors.green.shade50,
              child: Column(
                children: [
                  // Search Bar + Export Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        /// 🔷 EXPORT BUTTONS
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                printAcademicYears();
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
                                exportClassesToExcel();
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

                        /// 🔷 SEARCH BAR
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth:
                                300, // Controls how wide the search box can get
                            minWidth: 200,
                          ),
                          child: TextField(
                            controller: _searchController,
                            // Add a listener or setState to rebuild when text changes so the clear button updates
                            onChanged: (value) => setState(() {}),
                            decoration: InputDecoration(
                              isDense:
                                  true, // Makes the height more compact and professional
                              labelText: "Search Class",
                              hintText: "Enter class name...",
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

                  // DataTable using filteredAcademicYears
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        sortColumnIndex: _sortColumnIndex,
                        sortAscending: _sortAscending,
                        columns: [
                          DataColumn(
                            label: const Text("ID"),
                            onSort: (columnIndex, ascending) {
                              _sortData(
                                (item) => academicYears.indexOf(item),
                                columnIndex,
                                ascending,
                              );
                            },
                          ),
                          DataColumn(
                            label: const Text("Class Name"),
                            onSort: (columnIndex, ascending) {
                              _sortData(
                                (item) =>
                                    item['class_name'].toString().toLowerCase(),
                                columnIndex,
                                ascending,
                              );
                            },
                          ),
                          DataColumn(
                            label: const Text("Year Name"),
                            onSort: (columnIndex, ascending) {
                              _sortData(
                                (item) =>
                                    item['year_name'].toString().toLowerCase(),
                                columnIndex,
                                ascending,
                              );
                            },
                          ),
                          DataColumn(
                            label: const Text("Section"),
                            onSort: (columnIndex, ascending) {
                              _sortData(
                                (item) =>
                                    item['section'].toString().toLowerCase(),
                                columnIndex,
                                ascending,
                              );
                            },
                          ),
                          const DataColumn(label: Text("Actions")),
                        ],
                        // NOTE: Map over filteredAcademicYears instead of academicYears!
                        rows: filteredAcademicYears.asMap().entries.map((
                          entry,
                        ) {
                          int index = entry.key;
                          var item = entry.value;
                          return DataRow(
                            cells: [
                              DataCell(Text((index + 1).toString())),
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
                                Text(item['section'].toString().toUpperCase()),
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
                                        // Your delete dialog code...
                                        deleteClasses(
                                          item['class_id'].toString(),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
