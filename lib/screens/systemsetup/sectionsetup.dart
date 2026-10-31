import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:result/drawer/appdrawer.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:result/screens/schoolconfiguration/school_config.dart';

// adjust to your actual path
class SectionSetup extends StatefulWidget {
  const SectionSetup({super.key});

  @override
  State<SectionSetup> createState() => _SectionSetupState();
}

class _SectionSetupState extends State<SectionSetup> {
  Timer? _timer;
  List<dynamic> academicYears = [];
  String? selectedYearId;
  String? selectedYearName;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController classController = TextEditingController();

  String section = "NO"; // default
  String? selectedClassName;

  void clearForm() {
    classController.clear();
    setState(() {
      section = "NO";
    });
  }

  List<dynamic> classList = [];
  String? selectedClass;
  Future<void> fetchClassesOfSection() async {
    final prefs = await SharedPreferences.getInstance();

    // Here you are "reading" that saved variable back from the disk
    String? host = prefs.getString('saved_host');
    final response = await http.get(
      Uri.parse("http://$host/systemsetupapi.php?action=fetchclassesofsection"),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      setState(() {
        setState(() {
          classList = data; // Keep everything: id, name, section, etc.
        });
        selectedClass = null; // reset safely
      });
    }
  }

  List<dynamic> classListHavingSections = [];
  String? selectedClassesHavingSections;
  Future<void> fetchClassesHavingSectionsData() async {
    final prefs = await SharedPreferences.getInstance();

    // Here you are "reading" that saved variable back from the disk
    String? host = prefs.getString('saved_host');
    try {
      final response = await http.get(
        Uri.parse(
          "http://$host/systemsetupapi.php?action=fetchclasseshavingsectionsdata",
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          classListHavingSections = data;
        });
      }
    } catch (e) {
      print("Fetch Error: $e");
    }
  }

  // ---------------------------------------------------------------------
  // SEARCH + SORT (new)
  // ---------------------------------------------------------------------
  final TextEditingController searchController = TextEditingController();
  String searchQuery = "";

  // Which column is currently sorted, and in which direction.
  int? sortColumnIndex;
  bool sortAscending = true;

  /// Returns [classListHavingSections] filtered by the search box (matches
  /// against class name, case-insensitive) and sorted according to
  /// [sortColumnIndex] / [sortAscending]. Does not mutate the original list.
  List<dynamic> get _visibleClassListHavingSections {
    List<dynamic> result = classListHavingSections;

    if (searchQuery.trim().isNotEmpty) {
      final query = searchQuery.trim().toLowerCase();
      result = result.where((item) {
        final className = item['class_name']?.toString().toLowerCase() ?? '';
        return className.contains(query);
      }).toList();
    } else {
      result = List<dynamic>.from(result);
    }

    if (sortColumnIndex != null) {
      String keyForColumn(int index) {
        switch (index) {
          case 0:
            return 'class_name';
          case 1:
            return 'section_name';
          case 2:
            return 'year_name';
          default:
            return 'class_name';
        }
      }

      final key = keyForColumn(sortColumnIndex!);
      result.sort((a, b) {
        final aVal = a[key]?.toString().toLowerCase() ?? '';
        final bVal = b[key]?.toString().toLowerCase() ?? '';
        return sortAscending ? aVal.compareTo(bVal) : bVal.compareTo(aVal);
      });
    }

    return result;
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      sortColumnIndex = columnIndex;
      sortAscending = ascending;
    });
  }

  @override
  void initState() {
    super.initState();
    fetchClassesOfSection();
    fetchClassesHavingSectionsData();

    _timer = Timer.periodic(
      Duration(seconds: 1),
      (timer) => fetchClassesHavingSectionsData(),
    );
  }

  Future<void> deleteClasshavingsection(String id) async {
    final prefs = await SharedPreferences.getInstance();

    // Here you are "reading" that saved variable back from the disk
    String? host = prefs.getString('saved_host');
    var url = Uri.parse(
      "http://$host/systemsetupapi.php?action=deleteclasshavingsection",
    );

    var response = await http.post(url, body: {"id": id});

    if (response.statusCode == 200) {
      fetchClassesOfSection(); // refresh table
    } else {
      print("Delete failed");
    }
  }

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
        pw.Text("Classes & Sections Report", style: pw.TextStyle(fontSize: 14)),
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
            headers: ["S.N.", "CLASS NAME", "SECTION", "YEAR"],
            data: _visibleClassListHavingSections.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return [
                (index + 1).toString(),
                item['class_name'].toString(),
                item['section_name'].toString(),
                item['year_name'].toString(),
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
              1: const pw.FlexColumnWidth(2.2),
              2: const pw.FlexColumnWidth(1.3),
              3: const pw.FlexColumnWidth(1.5),
            },
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "Total Records: ${_visibleClassListHavingSections.length}",
              style: pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> exportSectionsToExcel() async {
    final workbook = xls.Excel.createExcel();
    const sheetName = 'Sections';
    final sheet = workbook[sheetName];

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

    styledHeaderCell(SchoolConfig.schoolName, bold: true, size: 16);
    styledHeaderCell(SchoolConfig.address, bold: false, size: 11);
    styledHeaderCell(SchoolConfig.phoneNumber, bold: false, size: 11);
    sheet.appendRow([]);

    styledHeaderCell("Classes & Sections Report", bold: true, size: 13);
    sheet.appendRow([]);

    sheet.appendRow([
      xls.TextCellValue("S.N."),
      xls.TextCellValue("Class Name"),
      xls.TextCellValue("Section"),
      xls.TextCellValue("Year"),
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

    final exportList = _visibleClassListHavingSections;
    for (var i = 0; i < exportList.length; i++) {
      final item = exportList[i];
      sheet.appendRow([
        xls.IntCellValue(i + 1),
        xls.TextCellValue(item['class_name'].toString()),
        xls.TextCellValue(item['section_name'].toString()),
        xls.TextCellValue(item['year_name'].toString()),
      ]);
    }

    final encoded = workbook.encode();
    if (encoded == null) {
      print("Failed to encode Excel workbook");
      return;
    }
    final bytes = Uint8List.fromList(encoded);

    try {
      var outputPath = await FilePicker.saveFile(
        dialogTitle: 'Save Sections Report',
        fileName: 'sections_report.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: kIsWeb ? bytes : null, // only needed on web
      );

      if (outputPath == null) return; // user cancelled

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

  List classes = [];
  String? selectedClassId;
  TextEditingController sectionController = TextEditingController();

  saveSection() async {
    final prefs = await SharedPreferences.getInstance();

    // Here you are "reading" that saved variable back from the disk
    String? host = prefs.getString('saved_host');
    var res = await http.post(
      Uri.parse(
        "http://$host/systemsetupapi.php?action=insertclasseshavingsections",
      ),
      body: {
        "class_id": selectedClassId,
        "section_name": sectionController.text.toUpperCase(),
        "class_name": selectedClassName,
      },
    );

    print(res.body);
  }

  @override
  void dispose() {
    _timer?.cancel(); // CRITICAL: Stop the timer when the screen is closed
    academicYears.clear();
    classList.clear();
    classListHavingSections.clear();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleList = _visibleClassListHavingSections;

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
                            "Section Setup",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: DropdownButton<String>(
                              isExpanded: true,
                              hint: const Text("Select Class"),
                              // Logic check using String comparison
                              value:
                                  classList.any((item) {
                                    // 1. Cast the item to a Map so we can access keys
                                    final Map<String, dynamic> classMap =
                                        item as Map<String, dynamic>;

                                    // 2. Perform the comparison
                                    return classMap['class_id'].toString() ==
                                        selectedClassId;
                                  })
                                  ? selectedClassId
                                  : null,
                              items: classList.asMap().entries.map((entry) {
                                int index = entry.key;
                                Map<String, dynamic> item =
                                    entry.value as Map<String, dynamic>;

                                return DropdownMenuItem<String>(
                                  // Value is the String ID
                                  value: item['class_id'].toString(),
                                  child: Text(
                                    "${index + 1}. ${item['class_name'].toString().toUpperCase()}",
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedClassId = newValue;
                                  var selectedItem = classList.firstWhere(
                                    (item) =>
                                        (item
                                                as Map<
                                                  String,
                                                  dynamic
                                                >)['class_id']
                                            .toString() ==
                                        newValue,
                                  );

                                  selectedClassName = selectedItem['class_name']
                                      .toString();
                                });

                                // Access the index based on the selected ID
                                int selectedIndex = classList.indexWhere(
                                  (item) =>
                                      (item as Map<String, dynamic>)['class_id']
                                          .toString() ==
                                      newValue,
                                );

                                debugPrint("Selected Index: $selectedIndex");
                                debugPrint("Selected Class ID: $newValue");
                              },
                            ),
                          ),
                          SizedBox(height: 20),

                          /// Section Input
                          TextField(
                            controller: sectionController,
                            decoration: InputDecoration(
                              labelText: "Enter Section (A, B...)",
                              border: OutlineInputBorder(),
                            ),
                          ),

                          SizedBox(height: 20),

                          Center(
                            child: ElevatedButton(
                              onPressed: saveSection,
                              child: Text("Save Section"),
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          /// R
          /// RIGHT DASHBOARD
          Expanded(
            flex: 2, // 2 parts (wider)
            child: Container(
              color: Colors.green.shade50,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left side: export buttons
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
                              exportSectionsToExcel();
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

                      // Right side: search box
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 250,
                            minWidth: 200,
                          ),
                          child: TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: "Search by class",
                              hintText: "e.g. Class 10",
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: searchQuery.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        searchController.clear();
                                        setState(() {
                                          searchQuery = "";
                                        });
                                      },
                                    ),
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            onChanged: (value) {
                              setState(() {
                                searchQuery = value;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          sortColumnIndex: sortColumnIndex,
                          sortAscending: sortAscending,
                          columns: [
                            DataColumn(label: const Text("S.N.")),
                            DataColumn(
                              label: const Text("Class Name"),
                              onSort: _onSort,
                            ),
                            DataColumn(
                              label: const Text("Sections"),
                              onSort: _onSort,
                            ),
                            DataColumn(
                              label: const Text("Year Name"),
                              onSort: _onSort,
                            ),
                            const DataColumn(label: Text("Actions")),
                          ],
                          rows: visibleList.asMap().entries.map((entry) {
                            int index =
                                entry.key; // This gives you 0, 1, 2, 3...
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
                                    item['section_name']
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
                                                  "Are you sure you want to delete this academic year?",
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
                                                      deleteClasshavingsection(
                                                        item['section_id']
                                                            .toString(),
                                                      );
                                                      print(item['section_id']);
                                                      print(item['class_name']);
                                                      print(
                                                        item['section_name'],
                                                      );
                                                      print(item['year_name']);

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
