import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:result/drawer/appdrawer.dart';

class Examsetup extends StatefulWidget {
  const Examsetup({super.key});

  @override
  State<Examsetup> createState() => _ExamsetupState();
}

class _ExamsetupState extends State<Examsetup> {
  // Controller to manage and clear the text input field
  final TextEditingController _examNameController = TextEditingController();
  List<dynamic> examinationsList = [];
  //for the time
  Timer? _timer;

  @override
  void dispose() {
    _examNameController.dispose();
    _timer?.cancel();
    examinationsList.clear();
    super.dispose();
  }

  // saving the exam details
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    String? host = prefs.getString('saved_host');

    // Validation check before network request
    if (_examNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text("Please enter an exam name.")),
        ),
      );
      return;
    }

    try {
      var res = await http.post(
        Uri.parse("http://$host/resultsetupapi.php?action=saveexamdetails"),
        // FIXED: Changed parameter key from "student_name" to "exam_name"
        body: {"exam_name": _examNameController.text.toUpperCase().trim()},
      );

      print("RAW RESPONSE FROM SERVER: ${res.body}");
      var response = jsonDecode(res.body);

      if (response["status"] == "success") {
        print("Record inserted");

        // Optional: Clear out the input field box upon successful creation
        _examNameController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Center(
              child: Text("Examination Registered Successfully!"),
            ),
          ),
        );
        await fetchExaminations();
      } else {
        // FIXED: Read response["message"] instead of response["error"] to match your PHP JSON output
        print("Server Error: ${response["message"]}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Center(
              child: Text(
                response["message"] ?? "Examination Registration Failed!",
              ),
            ),
          ),
        );
      }
    } catch (e) {
      print("Caught Error: $e");
    }
  }

  /// 🔷 FETCH DATA FROM PHP
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

  Future<void> deleteExamination(var id) async {
    final prefs = await SharedPreferences.getInstance();

    // Here you are "reading" that saved variable back from the disk
    String? host = prefs.getString('saved_host');
    var url = Uri.parse(
      "http://$host/resultsetupapi.php?action=deleteExamination",
    );

    var response = await http.post(url, body: {"id": id});

    if (response.statusCode == 200) {
      print("Response: ${response.body}");
      fetchExaminations(); // refresh table
    } else {
      print("Delete failed");
    }
  }

  //for update examination
  Future<void> updateExamName(String examId, String newName) async {
    final prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('saved_host');

    if (host == null) return;

    try {
      // Explicitly pass action in the URL string so $_GET['action'] catches it instantly
      var url = Uri.parse(
        "http://$host/resultsetupapi.php?action=updateExamName",
      );

      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'exam_id': int.tryParse(examId) ?? 0,
          'exam_name': newName,
        }),
      );

      var resData = jsonDecode(response.body);

      if (resData['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Exam name updated successfully!")),
        );
        // 🔄 Call your fetch function here to refresh the UI/table immediately
        await fetchExaminations();
        // TODO: Refresh your UI or list data here
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resData['message'] ?? "Failed to update.")),
        );
      }
    } catch (e) {
      print("Error updating exam name: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    fetchExaminations();

    // _timer = Timer.periodic(
    //   Duration(seconds: 3),
    //   (timer) => fetchExaminations(),
    // );
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
                    "Exam Name:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _examNameController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter exam name (e.g., Final Exam)',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // Handle your Save logic here
                          _save();
                        },
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
                          // Clears the input field box
                          _examNameController.clear();
                        },
                        child: const Text("Clear"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Right Half of the Screen (Left blank for later)
          Expanded(
            flex: 2, // 2 parts (wider)
            child: Container(
              color: Colors.green.shade50,
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  const SizedBox(height: 10),

                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text("S.N.")),

                            DataColumn(label: Text("Examination Name")),
                            DataColumn(label: Text("Active Year")),
                            DataColumn(label: Text("Actions")),
                          ],
                          rows: examinationsList.asMap().entries.map((entry) {
                            int index =
                                entry.key; // This gives you 0, 1, 2, 3...
                            var item = entry.value;
                            return DataRow(
                              cells: [
                                DataCell(Text((index + 1).toString())),
                                DataCell(
                                  Text(
                                    item['exam_name'].toString().toUpperCase(),
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
                                          Icons.edit,
                                          color: Colors.green,
                                        ),
                                        onPressed: () {
                                          // Controller to hold the exam name input, pre-filled with the current name
                                          final TextEditingController
                                          examController =
                                              TextEditingController(
                                                text: item['exam_name'],
                                              );

                                          showDialog(
                                            context: context,
                                            builder: (context) {
                                              return AlertDialog(
                                                title: const Text(
                                                  "Update Exam Name",
                                                ),
                                                content: TextField(
                                                  controller: examController,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: "Exam Name",
                                                        border:
                                                            OutlineInputBorder(),
                                                      ),
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
                                                              Colors.green,
                                                        ),
                                                    onPressed: () async {
                                                      String newExamName =
                                                          examController.text
                                                              .trim();
                                                      if (newExamName
                                                          .isNotEmpty) {
                                                        // Close the dialog first
                                                        Navigator.pop(context);

                                                        // Call function to update via API
                                                        await updateExamName(
                                                          item['exam_id']
                                                              .toString(),
                                                          newExamName,
                                                        );
                                                      }
                                                    },
                                                    child: const Text("Update"),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
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
                                                      deleteExamination(
                                                        item['exam_id']
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
