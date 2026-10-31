import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:result/drawer/appdrawer.dart';
import 'package:result/main.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AcademicYearSetup extends StatefulWidget {
  const AcademicYearSetup({super.key});

  @override
  State<AcademicYearSetup> createState() => _AcademicYearState();
}

class _AcademicYearState extends State<AcademicYearSetup> {
  int? selectedYear;
  Future<void> _pickYear(BuildContext context) async {
    int currentYear = selectedYear ?? DateTime.now().year;
    DateTime selectedDate = DateTime(currentYear);

    final int? picked = await showDialog<int>(
      context: context,
      builder: (context) {
        return Dialog(
          child: SizedBox(
            width: 320,
            height: 400,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Select Academic Year",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: YearPicker(
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2300),
                    selectedDate: selectedDate,
                    onChanged: (DateTime dateTime) {
                      Navigator.pop(context, dateTime.year);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedYear = picked;
      });
    }
  }

  Future<void> _deleteAcademicYear() async {
    final prefs = await SharedPreferences.getInstance();

    // Here you are "reading" that saved variable back from the disk
    String? host = prefs.getString('saved_host');
    var url = Uri.parse(
      "http://$host/systemsetupapi.php?action=deleteacademicyear",
    );

    var response = await http.post(
      url,
      body: {'year_name': selectedYear.toString()},
    );

    try {
      if (response.statusCode == 200) {
        print("Data Deleted");
      }
    } catch (e) {
      print(e);
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MyHomePage(title: '')),
    );
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    String? host = prefs.getString('saved_host');
    try {
      var res = await http.post(
        Uri.parse("http://$host/systemsetupapi.php?action=insertacademicyear"),
        body: {"selectedyear": selectedYear.toString()},
      );
      if (!mounted) return;

      print("RAW RESPONSE FROM SERVER: ${res.body}");
      var response = jsonDecode(res.body);

      if (response["status"] == "success") {
        print("Record inserted");

        // Show Alert Dialog Box
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Success"),
              content: const Text("Year Saved Successfully!"),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog

                    // Optional: Navigate ONLY after they click OK on the success dialog
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MyHomePage(title: ''),
                      ),
                    );
                  },
                  child: const Text("OK"),
                ),
              ],
            );
          },
        );
      } else {
        String errorMsg = response["error"] ?? "Unknown server error occurred.";
        print("Server Error: $errorMsg");

        // Guard check before using context
        if (!mounted) return;

        // Show Alert Dialog Box with the server error
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Creation Failed"),
              content: Text(
                errorMsg,
              ), // Displays the exact server error message
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                  },
                  child: const Text("OK"),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print("Caught Error: $e");

      // Optional: Show a dialog or snackbar if the connection completely fails
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Connection Error"),
            content: Text("Could not connect to server: $e"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("OK"),
              ),
            ],
          );
        },
      );
    }
  }

  void _clear() {
    setState(() {
      selectedYear = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,

        title: Text("Result Management System"),
      ),
      drawer: const AppDrawer(),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 500),
          margin: EdgeInsets.all(16),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.blue.shade200, width: 1.5),
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  //  Header with title + close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Academic Year Setup",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          // Navigating to a screen called "DetailsScreen"
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MyHomePage(title: ''),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(50),
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.close, size: 22),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Year Picker
                  InkWell(
                    onTap: () => _pickYear(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedYear?.toString() ?? "Select Year",
                            style: TextStyle(fontSize: 16),
                          ),
                          Icon(Icons.calendar_today_outlined),
                        ],
                      ),
                    ),
                  ),

                  //activate academic year
                  SizedBox(height: 24),
                  // Buttons (Responsive)
                  width < 400
                      ? Column(
                          children: [
                            _button("Save", Colors.blue, _save),
                            SizedBox(height: 10),
                            _button("Clear", Colors.blue, _clear),
                            SizedBox(height: 10),
                            _button("Delete", Colors.blue, _deleteAcademicYear),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _button("Save", Colors.blue, _save),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _button("Clear", Colors.blue, _clear),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _button(
                                "Delete",
                                Colors.blue,
                                _deleteAcademicYear,
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _button(String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 14),
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      child: Text(text, style: TextStyle(fontSize: 16, color: Colors.white)),
    );
  }
}
