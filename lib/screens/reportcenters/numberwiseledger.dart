import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:result/screens/schoolconfiguration/school_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:result/drawer/appdrawer.dart';
import 'package:pluto_grid/pluto_grid.dart';

class NumberWiseLedger extends StatefulWidget {
  const NumberWiseLedger({super.key});

  @override
  State<NumberWiseLedger> createState() => _NumberWiseLedgerState();
}

class _NumberWiseLedgerState extends State<NumberWiseLedger> {
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
  List<dynamic> reportList = [];
  bool isLoading = false;
  List<dynamic> subjectsList = [];
  List<dynamic> extraActivitiesSetupList = [];
  List<PlutoColumn> columns = [];
  List<PlutoRow> rows = [];
  List<PlutoColumnGroup> columnGroups = [];
  Key gridKey = UniqueKey();
  String? examName = '';
  PlutoGridStateManager? stateManager;
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
        "http://$host/prepareresultapi.php?action=getNumberByLedger",
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
        // --- ADD THIS LINE TO INSPECT IN DEBUG CONSOLE ---
        print('RAW REPORT DATA FROM PHP: ${resData['report']}');
        setState(() {
          subjectsList = resData["subjects"];
          extraActivitiesSetupList = resData["extra_activities_setup"] ?? [];
          reportList = resData["report"];
          columns = _buildColumns();

          rows = _buildRows();

          gridKey = UniqueKey();
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

  List<PlutoColumn> _buildColumns() {
    List<PlutoColumn> cols = [];
    List<PlutoColumnGroup> groups = []; // NEW

    cols.add(
      PlutoColumn(
        title: "Roll",
        field: "roll",
        type: PlutoColumnType.text(),
        enableSorting: true,
        width: 70,
        frozen: PlutoColumnFrozen.start,
      ),
    );

    cols.add(
      PlutoColumn(
        title: "Student Name",
        field: "student",
        type: PlutoColumnType.text(),
        enableSorting: true,
        width: 200,
        frozen: PlutoColumnFrozen.start,
      ),
    );

    // UPDATED: Theory/Practical columns, grouped under subject name,
    // with F.M / P.M baked into each sub-column title.
    for (var sub in subjectsList) {
      String thField = "sub_${sub['setup_id']}_th";
      String prField = "sub_${sub['setup_id']}_pr";

      num theoryFm = num.tryParse(sub['theory_fm']?.toString() ?? '0') ?? 0;
      num theoryPm = num.tryParse(sub['theory_pm']?.toString() ?? '0') ?? 0;
      num practicalFm =
          num.tryParse(sub['practical_fm']?.toString() ?? '0') ?? 0;
      num practicalPm =
          num.tryParse(sub['practical_pm']?.toString() ?? '0') ?? 0;

      cols.add(
        PlutoColumn(
          title: "Theory\nFM:$theoryFm  PM:$theoryPm",
          field: thField,
          width: 90,
          type: PlutoColumnType.text(),
          enableSorting: true,
          titleTextAlign: PlutoColumnTextAlign.center,
          textAlign: PlutoColumnTextAlign.center,
        ),
      );

      // Only add a Practical column if this subject actually has one.
      if (practicalFm > 0) {
        cols.add(
          PlutoColumn(
            title: "Practical\nFM:$practicalFm  PM:$practicalPm",
            field: prField,
            width: 90,
            type: PlutoColumnType.text(),
            enableSorting: true,
            titleTextAlign: PlutoColumnTextAlign.center,
            textAlign: PlutoColumnTextAlign.center,
          ),
        );

        groups.add(
          PlutoColumnGroup(
            title: sub['subject_name'].toString(),
            fields: [thField, prField],
            expandedColumn: false,
          ),
        );
      } else {
        // Subject with no practical component: single-column group.
        groups.add(
          PlutoColumnGroup(
            title: sub['subject_name'].toString(),
            fields: [thField],
            expandedColumn: false,
          ),
        );
      }
    }

    for (var ea in extraActivitiesSetupList) {
      cols.add(
        PlutoColumn(
          title: ea['activity_name'],
          field: "ea_${ea['setup_id']}",
          width: 100,
          type: PlutoColumnType.text(),
          enableSorting: true,
        ),
      );
    }

    cols.addAll([
      PlutoColumn(
        title: "Attendance",
        field: "attendance",
        width: 90,
        type: PlutoColumnType.text(),
        enableSorting: true,
      ),

      PlutoColumn(
        title: "Total",
        field: "total",
        width: 90,
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        title: "Percentage",
        field: "percentage",
        width: 80,
        type: PlutoColumnType.text(),
        enableSorting: true,
      ),
      PlutoColumn(
        title: "GPA",
        field: "gpa",
        width: 80,
        type: PlutoColumnType.text(),
        enableSorting: true,
      ),
      PlutoColumn(
        title: "Result",
        field: "result",
        width: 100,
        type: PlutoColumnType.text(),
        enableSorting: true,
      ),
      PlutoColumn(
        title: "Rank",
        field: "rank",
        width: 80,
        type: PlutoColumnType.text(),
        enableSorting: true,
      ),
      PlutoColumn(
        title: "Remarks",
        field: "remarks",
        width: 150,
        type: PlutoColumnType.text(),
        enableSorting: true,
      ),
    ]);

    columnGroups = groups; // NEW: store for use in build()
    return cols;
  }

  // List<PlutoRow> _buildRows() {
  //   List<PlutoRow> r = [];

  //   for (var row in reportList) {
  //     Map marksMap = row['subject_marks'] ?? {};
  //     Map extraMap = row['extra_activities'] ?? {};
  //     Map? attendance = row['attendance'];

  //     int totalDays =
  //         int.tryParse(attendance?['total_working_days']?.toString() ?? "0") ??
  //         0;

  //     int presentDays =
  //         int.tryParse(attendance?['days_present']?.toString() ?? "0") ?? 0;

  //     Map<String, PlutoCell> cells = {};

  //     cells['roll'] = PlutoCell(value: row['roll_number']?.toString() ?? "");

  //     cells['student'] = PlutoCell(
  //       value: row['student_name']?.toString() ?? "",
  //     );

  //     // UPDATED: build separate Theory and Practical cells for each subject
  //     // instead of a single combined total.
  //     for (var sub in subjectsList) {
  //       String thKey = "sub_${sub['setup_id']}_th";
  //       String prKey = "sub_${sub['setup_id']}_pr";

  //       String thVal = "-";
  //       String prVal = "-";

  //       if (marksMap.containsKey(sub['setup_id'].toString())) {
  //         var m = marksMap[sub['setup_id'].toString()];

  //         if (m['is_absent'] == 1) {
  //           thVal = "Abs";
  //           prVal = "Abs";
  //         } else {
  //           thVal = m['theory']?.toString() ?? '-';
  //           prVal = m['practical']?.toString() ?? '-';
  //         }
  //       }

  //       cells[thKey] = PlutoCell(value: thVal);
  //       cells[prKey] = PlutoCell(value: prVal);
  //     }

  //     for (var ea in extraActivitiesSetupList) {
  //       String key = "ea_${ea['setup_id']}";

  //       String val = "-";

  //       if (extraMap.containsKey(ea['setup_id'].toString())) {
  //         var em = extraMap[ea['setup_id'].toString()];

  //         if (em['is_absent'] == 1) {
  //           val = "Abs";
  //         } else {
  //           val = em['grade_or_score'].toString();
  //         }
  //       }

  //       cells[key] = PlutoCell(value: val);
  //     }
  //     cells['attendance'] = PlutoCell(
  //       value: totalDays > 0 ? '$presentDays/$totalDays' : '-',
  //     );

  //     cells['total'] = PlutoCell(
  //       value: row['total_obtained_marks']?.toString() ?? '',
  //     );

  //     cells['percentage'] = PlutoCell(value: "${row['percentage'] ?? ''}");

  //     cells['gpa'] = PlutoCell(value: row['gpa']?.toString() ?? '');

  //     cells['result'] = PlutoCell(
  //       value: row['overall_result']?.toString() ?? '',
  //     );

  //     cells['rank'] = PlutoCell(value: row['rank_in_class']?.toString() ?? '');

  //     cells['remarks'] = PlutoCell(value: row['remarks']?.toString() ?? '');

  //     r.add(PlutoRow(cells: cells));
  //   }

  //   return r;
  // }
  List<PlutoRow> _buildRows() {
    List<PlutoRow> r = [];

    for (var row in reportList) {
      // FIX 1: Safely handle maps that PHP might encode as [] when empty
      final Map marksMap = (row['subject_marks'] is Map)
          ? row['subject_marks']
          : (row['subject_grades'] is Map ? row['subject_grades'] : {});

      final Map extraMap = (row['extra_activities'] is Map)
          ? row['extra_activities']
          : {};

      Map? attendance = (row['attendance'] is Map) ? row['attendance'] : null;

      int totalDays =
          int.tryParse(attendance?['total_working_days']?.toString() ?? "0") ??
          0;

      int presentDays =
          int.tryParse(attendance?['days_present']?.toString() ?? "0") ?? 0;

      Map<String, PlutoCell> cells = {};

      cells['roll'] = PlutoCell(value: row['roll_number']?.toString() ?? "");

      cells['student'] = PlutoCell(
        value: row['student_name']?.toString() ?? "",
      );

      // Theory & Practical cells
      for (var sub in subjectsList) {
        String subId = sub['setup_id'].toString();
        String thKey = "sub_${subId}_th";
        String prKey = "sub_${subId}_pr";

        String thVal = "-";
        String prVal = "-";

        if (marksMap.containsKey(subId)) {
          var m = marksMap[subId];

          if (m is Map) {
            if (m['is_absent'] == 1) {
              thVal = "Abs";
              prVal = "Abs";
            } else {
              // Checks for 'theory' (from marks API) or 'theory_grade' (from pdf/grades API)
              thVal =
                  m['theory']?.toString() ??
                  m['theory_grade']?.toString() ??
                  '-';
              prVal =
                  m['practical']?.toString() ??
                  m['practical_grade']?.toString() ??
                  '-';
            }
          }
        }

        cells[thKey] = PlutoCell(value: thVal);

        // Only insert PR cell into row if the column actually exists in grid
        num practicalFm =
            num.tryParse(sub['practical_fm']?.toString() ?? '0') ?? 0;
        if (practicalFm > 0) {
          cells[prKey] = PlutoCell(value: prVal);
        }
      }

      // Extra Activities cells
      for (var ea in extraActivitiesSetupList) {
        String eaId = ea['setup_id'].toString();
        String key = "ea_${eaId}";
        String val = "-";

        if (extraMap.containsKey(eaId)) {
          var em = extraMap[eaId];
          if (em is Map) {
            if (em['is_absent'] == 1) {
              val = "Abs";
            } else {
              val = em['grade_or_score']?.toString() ?? "-";
            }
          }
        }

        cells[key] = PlutoCell(value: val);
      }

      cells['attendance'] = PlutoCell(
        value: totalDays > 0 ? '$presentDays/$totalDays' : '-',
      );

      cells['total'] = PlutoCell(
        value: row['total_obtained_marks']?.toString() ?? '',
      );

      cells['percentage'] = PlutoCell(value: "${row['percentage'] ?? ''}");

      cells['gpa'] = PlutoCell(value: row['gpa']?.toString() ?? '');

      cells['result'] = PlutoCell(
        value: row['overall_result']?.toString() ?? '',
      );

      cells['rank'] = PlutoCell(value: row['rank_in_class']?.toString() ?? '');

      cells['remarks'] = PlutoCell(value: row['remarks']?.toString() ?? '');

      r.add(PlutoRow(cells: cells));
    }

    return r;
  }

  // Future<void> _exportToExcel() async {
  //   if (reportList.isEmpty) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('No data to export. Please load the report first.'),
  //         ),
  //       );
  //     }
  //     return;
  //   }

  //   try {
  //     final excelFile = excel.Excel.createExcel();
  //     final excel.Sheet sheet = excelFile['Ledger'];
  //     excelFile.delete('Sheet1');

  //     final List<bool> subjectHasPractical = subjectsList.map((s) {
  //       final double pFm =
  //           double.tryParse(s['practical_fm']?.toString() ?? '0') ?? 0;
  //       return pFm > 0;
  //     }).toList();

  //     // ---------- Reusable styles ----------
  //     excel.CellStyle groupHeaderStyle() => excel.CellStyle(
  //       bold: true,
  //       backgroundColorHex: excel.ExcelColor.fromHexString('FFD9E1F2'),
  //       horizontalAlign: excel.HorizontalAlign.Center,
  //       verticalAlign: excel.VerticalAlign.Center,
  //       topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  //       bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  //       leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  //       rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  //     );

  //     excel.CellStyle subHeaderStyle() => excel.CellStyle(
  //       bold: true,
  //       backgroundColorHex: excel.ExcelColor.fromHexString('FFEDEDED'),
  //       horizontalAlign: excel.HorizontalAlign.Center,
  //       verticalAlign: excel.VerticalAlign.Center,
  //       topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  //       bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  //       leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  //       rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  //     );

  //     excel.CellStyle dataStyle() => excel.CellStyle(
  //       horizontalAlign: excel.HorizontalAlign.Center,
  //       topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  //       bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  //       leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  //       rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  //     );

  //     // School / exam header block styles
  //     excel.CellStyle schoolNameStyle() => excel.CellStyle(
  //       bold: true,
  //       fontSize: 16,
  //       horizontalAlign: excel.HorizontalAlign.Center,
  //       verticalAlign: excel.VerticalAlign.Center,
  //     );

  //     excel.CellStyle schoolAddressStyle() => excel.CellStyle(
  //       bold: false,
  //       fontSize: 11,
  //       horizontalAlign: excel.HorizontalAlign.Center,
  //       verticalAlign: excel.VerticalAlign.Center,
  //     );

  //     excel.CellStyle examTitleStyle() => excel.CellStyle(
  //       bold: true,
  //       fontSize: 12,
  //       italic: true,
  //       horizontalAlign: excel.HorizontalAlign.Center,
  //       verticalAlign: excel.VerticalAlign.Center,
  //       backgroundColorHex: excel.ExcelColor.fromHexString('FFF2F2F2'),
  //       topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  //       bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  //       leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  //       rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
  //     );

  //     void setCell(int col, int row, dynamic value, excel.CellStyle style) {
  //       final cell = sheet.cell(
  //         excel.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
  //       );
  //       cell.value = value is excel.CellValue
  //           ? value
  //           : excel.TextCellValue(value.toString());
  //       cell.cellStyle = style;
  //     }

  //     void mergeAndSet(
  //       int startCol,
  //       int startRow,
  //       int endCol,
  //       int endRow,
  //       dynamic value,
  //       excel.CellStyle style,
  //     ) {
  //       final excel.CellValue cellValue = value is excel.CellValue
  //           ? value
  //           : excel.TextCellValue(value.toString());

  //       if (startCol == endCol && startRow == endRow) {
  //         setCell(startCol, startRow, cellValue, style);
  //         return;
  //       }

  //       sheet.merge(
  //         excel.CellIndex.indexByColumnRow(
  //           columnIndex: startCol,
  //           rowIndex: startRow,
  //         ),
  //         excel.CellIndex.indexByColumnRow(
  //           columnIndex: endCol,
  //           rowIndex: endRow,
  //         ),
  //         customValue: cellValue,
  //       );

  //       for (int c = startCol; c <= endCol; c++) {
  //         for (int r = startRow; r <= endRow; r++) {
  //           final cell = sheet.cell(
  //             excel.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
  //           );
  //           cell.cellStyle = style;
  //         }
  //       }
  //     }

  //     // ---------- Pre-calculate total column count ----------
  //     // Number Ledger subject columns: TH, [PR] only (no GRADE/GPA/REMARKS
  //     // per-subject, since this dataset stores raw marks, not grades).
  //     int totalColsCalculated = 3; // S.N., ROLL, Student Name
  //     for (int i = 0; i < subjectsList.length; i++) {
  //       totalColsCalculated += subjectHasPractical[i] ? 2 : 1; // TH, [PR]
  //     }
  //     totalColsCalculated += extraActivitiesSetupList.length;
  //     totalColsCalculated += 7; // ATT., TOTAL, %, GPA, RESULT, RANK, REMARKS

  //     // TODO: wire these up to your school-settings model / selected exam
  //     String? schoolNameText = SchoolConfig.schoolName;
  //     String? schoolAddressText = SchoolConfig.address;
  //     String? examNameText = examName;

  //     const int schoolNameRow = 0;
  //     const int schoolAddressRow = 1;
  //     const int examNameRow = 2;
  //     const int spacerRow = 3;

  //     mergeAndSet(
  //       0,
  //       schoolNameRow,
  //       totalColsCalculated - 1,
  //       schoolNameRow,
  //       schoolNameText,
  //       schoolNameStyle(),
  //     );
  //     mergeAndSet(
  //       0,
  //       schoolAddressRow,
  //       totalColsCalculated - 1,
  //       schoolAddressRow,
  //       schoolAddressText,
  //       schoolAddressStyle(),
  //     );
  //     mergeAndSet(
  //       0,
  //       examNameRow,
  //       totalColsCalculated - 1,
  //       examNameRow,
  //       examNameText,
  //       examTitleStyle(),
  //     );

  //     // ---------- Build two-row table header ----------
  //     const int topOffset = spacerRow + 1;
  //     const int headerRow0 = topOffset;
  //     const int headerRow1 = topOffset + 1;
  //     const int dataStartRow = topOffset + 2;

  //     int col = 0;

  //     mergeAndSet(col, headerRow0, col, headerRow1, 'S.N.', groupHeaderStyle());
  //     col++;
  //     mergeAndSet(col, headerRow0, col, headerRow1, 'ROLL', groupHeaderStyle());
  //     col++;
  //     mergeAndSet(
  //       col,
  //       headerRow0,
  //       col,
  //       headerRow1,
  //       'Student Name',
  //       groupHeaderStyle(),
  //     );
  //     col++;

  //     final List<int> subjectStartCol = [];
  //     final List<int> subjectColCount = [];

  //     for (int i = 0; i < subjectsList.length; i++) {
  //       final creditHours = subjectsList[i]['credit_hours']?.toString() ?? '';
  //       final name =
  //           "${subjectsList[i]['subject_name']?.toString() ?? ''}"
  //           "${creditHours.isNotEmpty ? ' (Cr:$creditHours)' : ''}";

  //       final subLabels = <String>['TH', if (subjectHasPractical[i]) 'PR'];

  //       final startCol = col;
  //       final endCol = col + subLabels.length - 1;

  //       mergeAndSet(
  //         startCol,
  //         headerRow0,
  //         endCol,
  //         headerRow0,
  //         name,
  //         groupHeaderStyle(),
  //       );

  //       for (int j = 0; j < subLabels.length; j++) {
  //         setCell(startCol + j, headerRow1, subLabels[j], subHeaderStyle());
  //       }

  //       subjectStartCol.add(startCol);
  //       subjectColCount.add(subLabels.length);

  //       col = endCol + 1;
  //     }

  //     final List<int> extraActivityCol = [];
  //     for (final ea in extraActivitiesSetupList) {
  //       mergeAndSet(
  //         col,
  //         headerRow0,
  //         col,
  //         headerRow1,
  //         ea['activity_name']?.toString() ?? '',
  //         groupHeaderStyle(),
  //       );
  //       extraActivityCol.add(col);
  //       col++;
  //     }

  //     // Trailing summary columns (Number Ledger keeps Total & % in addition
  //     // to the Grade Ledger's trailing set).
  //     final trailingLabels = [
  //       'ATT.',
  //       'TOTAL',
  //       '%',
  //       'GPA',
  //       'RESULT',
  //       'RANK',
  //       'REMARKS',
  //     ];
  //     final List<int> trailingCol = [];
  //     for (final label in trailingLabels) {
  //       mergeAndSet(
  //         col,
  //         headerRow0,
  //         col,
  //         headerRow1,
  //         label,
  //         groupHeaderStyle(),
  //       );
  //       trailingCol.add(col);
  //       col++;
  //     }

  //     final int totalCols = col; // should equal totalColsCalculated

  //     // ---------- Cell value parsing ----------
  //     excel.CellValue parseCellValue(dynamic val) {
  //       if (val == null) return excel.TextCellValue('-');
  //       if (val is num) return excel.DoubleCellValue(val.toDouble());

  //       final strVal = val.toString().trim();
  //       final numVal = double.tryParse(strVal);
  //       if (numVal != null) {
  //         return excel.DoubleCellValue(numVal);
  //       }
  //       return excel.TextCellValue(strVal);
  //     }

  //     // ---------- Data rows ----------
  //     for (int rowIdx = 0; rowIdx < reportList.length; rowIdx++) {
  //       final row = reportList[rowIdx];
  //       final Map marksMap = row['subject_marks'] ?? {};
  //       final Map extraMap = row['extra_activities'] ?? {};
  //       final attendance = row['attendance'];
  //       final excelRow = dataStartRow + rowIdx;

  //       final totalDays =
  //           int.tryParse(
  //             attendance?['total_working_days']?.toString() ?? '0',
  //           ) ??
  //           0;
  //       final presentDays =
  //           int.tryParse(attendance?['days_present']?.toString() ?? '0') ?? 0;

  //       setCell(0, excelRow, parseCellValue(rowIdx + 1), dataStyle());
  //       setCell(
  //         1,
  //         excelRow,
  //         parseCellValue(row['roll_number'] ?? ''),
  //         dataStyle(),
  //       );
  //       setCell(
  //         2,
  //         excelRow,
  //         parseCellValue(row['student_name'] ?? ''),
  //         dataStyle(),
  //       );

  //       for (int i = 0; i < subjectsList.length; i++) {
  //         final rawId = subjectsList[i]['setup_id'];
  //         final sIdStr = rawId.toString();
  //         final sIdInt = int.tryParse(sIdStr);
  //         final m = marksMap[sIdStr] ?? marksMap[sIdInt];

  //         int c = subjectStartCol[i];

  //         if (m != null && m['is_absent'] == 1) {
  //           setCell(c++, excelRow, parseCellValue('Abs'), dataStyle()); // TH
  //           if (subjectHasPractical[i]) {
  //             setCell(c++, excelRow, parseCellValue('Abs'), dataStyle()); // PR
  //           }
  //         } else if (m != null) {
  //           setCell(
  //             c++,
  //             excelRow,
  //             parseCellValue(m['theory'] ?? '-'),
  //             dataStyle(),
  //           );
  //           if (subjectHasPractical[i]) {
  //             setCell(
  //               c++,
  //               excelRow,
  //               parseCellValue(m['practical'] ?? '-'),
  //               dataStyle(),
  //             );
  //           }
  //         } else {
  //           final cols = subjectColCount[i];
  //           for (int k = 0; k < cols; k++) {
  //             setCell(c++, excelRow, parseCellValue('-'), dataStyle());
  //           }
  //         }
  //       }

  //       for (int i = 0; i < extraActivitiesSetupList.length; i++) {
  //         final ea = extraActivitiesSetupList[i];
  //         final rawId = ea['setup_id'];
  //         final eIdStr = rawId.toString();
  //         final eIdInt = int.tryParse(eIdStr);
  //         final em = extraMap[eIdStr] ?? extraMap[eIdInt];
  //         final value = em != null
  //             ? (em['is_absent'] == 1 ? 'Abs' : (em['grade_or_score'] ?? '-'))
  //             : '-';
  //         setCell(
  //           extraActivityCol[i],
  //           excelRow,
  //           parseCellValue(value),
  //           dataStyle(),
  //         );
  //       }

  //       setCell(
  //         trailingCol[0],
  //         excelRow,
  //         parseCellValue(totalDays > 0 ? '$presentDays/$totalDays' : '-'),
  //         dataStyle(),
  //       );
  //       setCell(
  //         trailingCol[1],
  //         excelRow,
  //         parseCellValue(row['total_obtained_marks'] ?? 0),
  //         dataStyle(),
  //       );
  //       setCell(
  //         trailingCol[2],
  //         excelRow,
  //         parseCellValue(row['percentage'] ?? 0),
  //         dataStyle(),
  //       );
  //       setCell(
  //         trailingCol[3],
  //         excelRow,
  //         parseCellValue(row['gpa'] ?? 0.0),
  //         dataStyle(),
  //       );
  //       setCell(
  //         trailingCol[4],
  //         excelRow,
  //         parseCellValue(row['overall_result'] ?? ''),
  //         dataStyle(),
  //       );
  //       setCell(
  //         trailingCol[5],
  //         excelRow,
  //         parseCellValue(row['rank_in_class'] ?? '-'),
  //         dataStyle(),
  //       );
  //       setCell(
  //         trailingCol[6],
  //         excelRow,
  //         parseCellValue(row['remarks'] ?? ''),
  //         dataStyle(),
  //       );
  //     }

  //     // ---------- Column widths ----------
  //     for (int i = 0; i < totalCols; i++) {
  //       sheet.setColumnAutoFit(i);
  //     }

  //     final List<int>? fileBytes = excelFile.save();
  //     if (fileBytes == null) return;

  //     final String defaultFileName =
  //         'NumberLedger_${selectedYear}_${selectedClassName ?? 'Class'}.xlsx';

  //     String? outputPath = await FilePicker.saveFile(
  //       dialogTitle: 'Save Excel File',
  //       fileName: defaultFileName,
  //       type: FileType.custom,
  //       allowedExtensions: ['xlsx'],
  //     );

  //     if (outputPath == null) return;

  //     if (!outputPath.toLowerCase().endsWith('.xlsx')) {
  //       outputPath = '$outputPath.xlsx';
  //     }

  //     final file = File(outputPath);
  //     await file.writeAsBytes(fileBytes, flush: true);

  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Excel saved successfully!\n$outputPath')),
  //       );
  //     }
  //   } catch (e, stackTrace) {
  //     debugPrint('Excel export error: $e\n$stackTrace');
  //     if (mounted) {
  //       ScaffoldMessenger.of(
  //         context,
  //       ).showSnackBar(SnackBar(content: Text('Failed to export Excel: $e')));
  //     }
  //   }
  // }
  Future<void> _exportToExcel() async {
    if (reportList.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No data to export. Please load the report first.'),
          ),
        );
      }
      return;
    }

    try {
      final excelFile = excel.Excel.createExcel();
      final excel.Sheet sheet = excelFile['Ledger'];
      excelFile.delete('Sheet1');

      final List<bool> subjectHasPractical = subjectsList.map((s) {
        final double pFm =
            double.tryParse(s['practical_fm']?.toString() ?? '0') ?? 0;
        return pFm > 0;
      }).toList();

      // ---------- Reusable styles ----------
      excel.CellStyle groupHeaderStyle() => excel.CellStyle(
        bold: true,
        backgroundColorHex: excel.ExcelColor.fromHexString('FFD9E1F2'),
        horizontalAlign: excel.HorizontalAlign.Center,
        verticalAlign: excel.VerticalAlign.Center,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      );

      excel.CellStyle subHeaderStyle() => excel.CellStyle(
        bold: true,
        backgroundColorHex: excel.ExcelColor.fromHexString('FFEDEDED'),
        horizontalAlign: excel.HorizontalAlign.Center,
        verticalAlign: excel.VerticalAlign.Center,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      );

      excel.CellStyle dataStyle() => excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Center,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      );

      // School / exam header block styles
      excel.CellStyle schoolNameStyle() => excel.CellStyle(
        bold: true,
        fontSize: 16,
        horizontalAlign: excel.HorizontalAlign.Center,
        verticalAlign: excel.VerticalAlign.Center,
      );

      excel.CellStyle schoolAddressStyle() => excel.CellStyle(
        bold: false,
        fontSize: 11,
        horizontalAlign: excel.HorizontalAlign.Center,
        verticalAlign: excel.VerticalAlign.Center,
      );

      excel.CellStyle examTitleStyle() => excel.CellStyle(
        bold: true,
        fontSize: 12,
        italic: true,
        horizontalAlign: excel.HorizontalAlign.Center,
        verticalAlign: excel.VerticalAlign.Center,
        backgroundColorHex: excel.ExcelColor.fromHexString('FFF2F2F2'),
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      );

      void setCell(int col, int row, dynamic value, excel.CellStyle style) {
        final cell = sheet.cell(
          excel.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );
        cell.value = value is excel.CellValue
            ? value
            : excel.TextCellValue(value.toString());
        cell.cellStyle = style;
      }

      void mergeAndSet(
        int startCol,
        int startRow,
        int endCol,
        int endRow,
        dynamic value,
        excel.CellStyle style,
      ) {
        final excel.CellValue cellValue = value is excel.CellValue
            ? value
            : excel.TextCellValue(value.toString());

        if (startCol == endCol && startRow == endRow) {
          setCell(startCol, startRow, cellValue, style);
          return;
        }

        sheet.merge(
          excel.CellIndex.indexByColumnRow(
            columnIndex: startCol,
            rowIndex: startRow,
          ),
          excel.CellIndex.indexByColumnRow(
            columnIndex: endCol,
            rowIndex: endRow,
          ),
          customValue: cellValue,
        );

        for (int c = startCol; c <= endCol; c++) {
          for (int r = startRow; r <= endRow; r++) {
            final cell = sheet.cell(
              excel.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
            );
            cell.cellStyle = style;
          }
        }
      }

      // ---------- Pre-calculate total column count ----------
      int totalColsCalculated = 3; // S.N., ROLL, Student Name
      for (int i = 0; i < subjectsList.length; i++) {
        totalColsCalculated += subjectHasPractical[i] ? 2 : 1; // TH, [PR]
      }
      totalColsCalculated += extraActivitiesSetupList.length;
      totalColsCalculated += 7; // ATT., TOTAL, %, GPA, RESULT, RANK, REMARKS

      String? schoolNameText = SchoolConfig.schoolName;
      String? schoolAddressText = SchoolConfig.address;
      String? examNameText = examName;

      const int schoolNameRow = 0;
      const int schoolAddressRow = 1;
      const int examNameRow = 2;
      const int spacerRow = 3;

      mergeAndSet(
        0,
        schoolNameRow,
        totalColsCalculated - 1,
        schoolNameRow,
        schoolNameText,
        schoolNameStyle(),
      );
      mergeAndSet(
        0,
        schoolAddressRow,
        totalColsCalculated - 1,
        schoolAddressRow,
        schoolAddressText,
        schoolAddressStyle(),
      );
      mergeAndSet(
        0,
        examNameRow,
        totalColsCalculated - 1,
        examNameRow,
        examNameText,
        examTitleStyle(),
      );

      // ---------- Build two-row table header ----------
      const int topOffset = spacerRow + 1;
      const int headerRow0 = topOffset;
      const int headerRow1 = topOffset + 1;
      const int dataStartRow = topOffset + 2;

      int col = 0;

      mergeAndSet(col, headerRow0, col, headerRow1, 'S.N.', groupHeaderStyle());
      col++;
      mergeAndSet(col, headerRow0, col, headerRow1, 'ROLL', groupHeaderStyle());
      col++;
      mergeAndSet(
        col,
        headerRow0,
        col,
        headerRow1,
        'Student Name',
        groupHeaderStyle(),
      );
      col++;

      final List<int> subjectStartCol = [];
      final List<int> subjectColCount = [];

      for (int i = 0; i < subjectsList.length; i++) {
        final creditHours = subjectsList[i]['credit_hours']?.toString() ?? '';
        final name =
            "${subjectsList[i]['subject_name']?.toString() ?? ''}"
            "${creditHours.isNotEmpty ? ' (Cr:$creditHours)' : ''}";

        final subLabels = <String>['TH', if (subjectHasPractical[i]) 'PR'];

        final startCol = col;
        final endCol = col + subLabels.length - 1;

        mergeAndSet(
          startCol,
          headerRow0,
          endCol,
          headerRow0,
          name,
          groupHeaderStyle(),
        );

        for (int j = 0; j < subLabels.length; j++) {
          setCell(startCol + j, headerRow1, subLabels[j], subHeaderStyle());
        }

        subjectStartCol.add(startCol);
        subjectColCount.add(subLabels.length);

        col = endCol + 1;
      }

      final List<int> extraActivityCol = [];
      for (final ea in extraActivitiesSetupList) {
        mergeAndSet(
          col,
          headerRow0,
          col,
          headerRow1,
          ea['activity_name']?.toString() ?? '',
          groupHeaderStyle(),
        );
        extraActivityCol.add(col);
        col++;
      }

      final trailingLabels = [
        'ATT.',
        'TOTAL',
        '%',
        'GPA',
        'RESULT',
        'RANK',
        'REMARKS',
      ];
      final List<int> trailingCol = [];
      for (final label in trailingLabels) {
        mergeAndSet(
          col,
          headerRow0,
          col,
          headerRow1,
          label,
          groupHeaderStyle(),
        );
        trailingCol.add(col);
        col++;
      }

      final int totalCols = col;

      // ---------- Cell value parsing ----------
      excel.CellValue parseCellValue(dynamic val) {
        if (val == null) return excel.TextCellValue('-');
        if (val is num) return excel.DoubleCellValue(val.toDouble());

        final strVal = val.toString().trim();
        final numVal = double.tryParse(strVal);
        if (numVal != null) {
          return excel.DoubleCellValue(numVal);
        }
        return excel.TextCellValue(strVal);
      }

      // ---------- Data rows ----------
      for (int rowIdx = 0; rowIdx < reportList.length; rowIdx++) {
        final row = reportList[rowIdx];

        // SAFE MAP EXTRACTION: Check type before casting
        final Map marksMap = (row['subject_marks'] is Map)
            ? row['subject_marks']
            : ((row['subject_grades'] is Map) ? row['subject_grades'] : {});

        final Map extraMap = (row['extra_activities'] is Map)
            ? row['extra_activities']
            : {};

        final Map? attendance = (row['attendance'] is Map)
            ? row['attendance']
            : null;

        final excelRow = dataStartRow + rowIdx;

        final totalDays =
            int.tryParse(
              attendance?['total_working_days']?.toString() ?? '0',
            ) ??
            0;
        final presentDays =
            int.tryParse(attendance?['days_present']?.toString() ?? '0') ?? 0;

        setCell(0, excelRow, parseCellValue(rowIdx + 1), dataStyle());
        setCell(
          1,
          excelRow,
          parseCellValue(row['roll_number'] ?? ''),
          dataStyle(),
        );
        setCell(
          2,
          excelRow,
          parseCellValue(row['student_name'] ?? ''),
          dataStyle(),
        );

        for (int i = 0; i < subjectsList.length; i++) {
          final rawId = subjectsList[i]['setup_id'];
          final sIdStr = rawId.toString();
          final sIdInt = int.tryParse(sIdStr);
          final m =
              marksMap[sIdStr] ?? (sIdInt != null ? marksMap[sIdInt] : null);

          int c = subjectStartCol[i];

          if (m is Map && m['is_absent'] == 1) {
            setCell(c++, excelRow, parseCellValue('Abs'), dataStyle()); // TH
            if (subjectHasPractical[i]) {
              setCell(c++, excelRow, parseCellValue('Abs'), dataStyle()); // PR
            }
          } else if (m is Map) {
            final thVal = m['theory'] ?? m['theory_grade'] ?? '-';
            final prVal = m['practical'] ?? m['practical_grade'] ?? '-';

            setCell(c++, excelRow, parseCellValue(thVal), dataStyle());
            if (subjectHasPractical[i]) {
              setCell(c++, excelRow, parseCellValue(prVal), dataStyle());
            }
          } else {
            final cols = subjectColCount[i];
            for (int k = 0; k < cols; k++) {
              setCell(c++, excelRow, parseCellValue('-'), dataStyle());
            }
          }
        }

        for (int i = 0; i < extraActivitiesSetupList.length; i++) {
          final ea = extraActivitiesSetupList[i];
          final rawId = ea['setup_id'];
          final eIdStr = rawId.toString();
          final eIdInt = int.tryParse(eIdStr);
          final em =
              extraMap[eIdStr] ?? (eIdInt != null ? extraMap[eIdInt] : null);

          final value = (em is Map)
              ? (em['is_absent'] == 1 ? 'Abs' : (em['grade_or_score'] ?? '-'))
              : '-';

          setCell(
            extraActivityCol[i],
            excelRow,
            parseCellValue(value),
            dataStyle(),
          );
        }

        setCell(
          trailingCol[0],
          excelRow,
          parseCellValue(totalDays > 0 ? '$presentDays/$totalDays' : '-'),
          dataStyle(),
        );
        setCell(
          trailingCol[1],
          excelRow,
          parseCellValue(row['total_obtained_marks'] ?? 0),
          dataStyle(),
        );
        setCell(
          trailingCol[2],
          excelRow,
          parseCellValue(row['percentage'] ?? 0),
          dataStyle(),
        );
        setCell(
          trailingCol[3],
          excelRow,
          parseCellValue(row['gpa'] ?? 0.0),
          dataStyle(),
        );
        setCell(
          trailingCol[4],
          excelRow,
          parseCellValue(row['overall_result'] ?? ''),
          dataStyle(),
        );
        setCell(
          trailingCol[5],
          excelRow,
          parseCellValue(row['rank_in_class'] ?? '-'),
          dataStyle(),
        );
        setCell(
          trailingCol[6],
          excelRow,
          parseCellValue(row['remarks'] ?? ''),
          dataStyle(),
        );
      }

      // ---------- Column widths ----------
      for (int i = 0; i < totalCols; i++) {
        sheet.setColumnAutoFit(i);
      }

      final List<int>? fileBytes = excelFile.save();
      if (fileBytes == null) return;

      final String defaultFileName =
          'NumberLedger_${selectedYear}_${selectedClassName ?? 'Class'}.xlsx';

      String? outputPath = await FilePicker.saveFile(
        dialogTitle: 'Save Excel File',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputPath == null) return;

      if (!outputPath.toLowerCase().endsWith('.xlsx')) {
        outputPath = '$outputPath.xlsx';
      }

      final file = File(outputPath);
      await file.writeAsBytes(fileBytes, flush: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel saved successfully!\n$outputPath')),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Excel export error: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export Excel: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                mainAxisSize: MainAxisSize.min,
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

                            var selectedItem = academicClasses.firstWhere(
                              (item) =>
                                  item['class_id'].toString() == newClassId,
                            );

                            setState(() {
                              selectedClassId = newClassId;
                              selectedClassName = selectedItem['class_name']
                                  .toString();
                              selectedSubject = null;
                              extraActivitiesList = [];
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
                            // 1. Find the selected item from the list using newValue
                            final selectedExamItem = examinationsList
                                .firstWhere(
                                  (item) =>
                                      item['exam_id'].toString() == newValue,
                                  orElse: () => null,
                                );

                            // 2. Update state properly inside a block body
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

                  // Action Buttons Row
                  Row(
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
                            : const Text('Show Result Sheet'),
                      ),
                      const SizedBox(width: 12),

                      OutlinedButton.icon(
                        onPressed: reportList.isEmpty ? null : _exportToExcel,
                        icon: const Icon(Icons.table_chart),
                        label: const Text('Export Excel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // --- DATA TABLE / REPORT SECTION ---
            Expanded(
              child: SizedBox(
                child: Container(
                  height: 450, // Explicit height guarantees it won't collapse
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: reportList.isEmpty
                      ? const Center(
                          child: Text(
                            'No results loaded. Select options and click Show.',
                          ),
                        )
                      : PlutoGrid(
                          key: gridKey,
                          columns: columns,
                          columnGroups: columnGroups,
                          rows: rows,
                          onLoaded: (PlutoGridOnLoadedEvent event) {
                            stateManager = event.stateManager;

                            stateManager!.setShowColumnFilter(true);

                            stateManager!.setSelectingMode(
                              PlutoGridSelectingMode.row,
                            );

                            stateManager!.notifyListeners();
                          },
                          mode: PlutoGridMode.readOnly,
                          configuration: PlutoGridConfiguration(
                            columnSize: const PlutoGridColumnSizeConfig(
                              autoSizeMode: PlutoAutoSizeMode.none,
                            ),
                            style: PlutoGridStyleConfig(
                              rowHeight: 40,
                              columnHeight: 45,
                              gridBorderRadius: BorderRadius.circular(6),
                              enableCellBorderHorizontal: true,
                              enableCellBorderVertical: true,
                            ),
                          ),
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
