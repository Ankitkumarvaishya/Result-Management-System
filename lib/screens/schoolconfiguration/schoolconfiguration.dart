import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:result/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'school_config.dart';

class SchoolConfigurationScreen extends StatefulWidget {
  const SchoolConfigurationScreen({super.key});

  @override
  State<SchoolConfigurationScreen> createState() =>
      _SchoolConfigurationScreenState();
}

class _SchoolConfigurationScreenState extends State<SchoolConfigurationScreen> {
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? _logoPath;
  bool _isSaving = false;
  bool _isPickingLogo =
      false; // NEW: drives visual feedback while the file picker is open

  @override
  void initState() {
    super.initState();
    _loadSavedData(); // Load everything saved so far on startup
  }

  // --- Load Data ---
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hostController.text = prefs.getString('saved_host') ?? "";
      _nameController.text = prefs.getString('school_name') ?? "";
      _addressController.text = prefs.getString('school_address') ?? "";
      _phoneController.text = prefs.getString('school_phone') ?? "";
      _logoPath = prefs.getString('school_logo_path');
    });
  }

  // --- Pick Logo ---
  // file_picker opens a native OS file-browser dialog, which works on
  // Windows / macOS / Linux desktop as well as mobile (unlike
  // image_picker's ImageSource.gallery, which is mobile-only).
  Future<void> _pickLogo() async {
    // Give immediate visual feedback the tap registered, since the native
    // file dialog can take a moment to appear (this is what looked "dead"
    // before — nothing on screen changed until the dialog showed up).
    setState(() => _isPickingLogo = true);

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        withData: false,
      );

      if (result == null || result.files.single.path == null) return;

      final pickedPath = result.files.single.path!;
      final extension = pickedPath.split('.').last;

      // Copy into permanent app storage so the file survives even if the
      // originally picked file gets moved or deleted.
      final appDir = await getApplicationDocumentsDirectory();
      final savedImage = await File(
        pickedPath,
      ).copy('${appDir.path}/school_logo.$extension');

      setState(() => _logoPath = savedImage.path);
    } finally {
      if (mounted) setState(() => _isPickingLogo = false);
    }
  }

  // --- Remove Logo ---
  Future<void> _removeLogo() async {
    final pathToDelete = _logoPath;

    setState(() => _logoPath = null);

    // Clear the persisted value too, otherwise it comes back on next launch.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('school_logo_path');

    // Best-effort cleanup of the copied file on disk.
    if (pathToDelete != null) {
      final file = File(pathToDelete);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // Non-fatal — stale file left behind, but app state is already correct.
        }
      }
    }
  }

  // --- Save Data ---
  Future<void> _handleConnect() async {
    setState(() => _isSaving = true);

    final String host = _hostController.text.trim();
    final String name = _nameController.text.trim();
    final String address = _addressController.text.trim();
    final String phone = _phoneController.text.trim();

    if (host.isNotEmpty) {
      // Saves to disk AND updates the global SchoolConfig static fields,
      // so the values are usable anywhere in the app immediately.
      await SchoolConfig.save(
        host: host,
        schoolName: name,
        address: address,
        phoneNumber: phone,
        logoPath: _logoPath,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "School Configuration Saved! Restart of The Application is Needed.",
          ),
        ),
      );

      print("Ready for API calls with base URL: $host");
    }

    setState(() => _isSaving = false);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MyHomePage(title: '')),
    );
  }

  @override
  void dispose() {
    _hostController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.blueAccent),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.blueGrey.shade50, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
    );
  }

  Widget _softField({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  // --- Logo picker widget: avatar + tap ripple + loading spinner + remove badge ---
  Widget _buildLogoPicker() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 0,
          child: InkWell(
            // InkWell gives an immediate ripple on tap, so the user gets
            // feedback the instant they touch it, not just once the file
            // dialog eventually opens.
            customBorder: const CircleBorder(),
            onTap: _isPickingLogo ? null : _pickLogo,
            child: Container(
              height: 110,
              width: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueGrey.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: _isPickingLogo
                    ? const Center(
                        child: SizedBox(
                          height: 28,
                          width: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : (_logoPath != null
                          ? Image.file(File(_logoPath!), fit: BoxFit.cover)
                          : const Icon(
                              Icons.add_a_photo_rounded,
                              color: Colors.blueAccent,
                              size: 32,
                            )),
              ),
            ),
          ),
        ),
        // Remove badge — only shown once a logo is actually set.
        if (_logoPath != null && !_isPickingLogo)
          Positioned(
            right: -4,
            top: -4,
            child: GestureDetector(
              onTap: _removeLogo,
              child: Container(
                height: 28,
                width: 28,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: Color(0xFF0F172A),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 8),
              const Text(
                "School Setup",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Set up your school profile and server address. "
                "These details will be saved for future sessions.",
              ),
              const SizedBox(height: 32),

              // --- Logo Picker ---
              Center(child: _buildLogoPicker()),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _isPickingLogo
                      ? "Opening file picker..."
                      : (_logoPath != null
                            ? "Tap to change · tap × to remove"
                            : "Tap to add logo"),
                  style: TextStyle(
                    color: Colors.blueGrey.shade400,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // --- School Name ---
              _softField(
                child: TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _fieldDecoration(
                    hint: "School Name",
                    icon: Icons.school_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- School Address ---
              _softField(
                child: TextField(
                  controller: _addressController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: _fieldDecoration(
                    hint: "School Address",
                    icon: Icons.location_on_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- Phone Number ---
              _softField(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _fieldDecoration(
                    hint: "Phone Number",
                    icon: Icons.phone_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              const Divider(height: 1),
              const SizedBox(height: 24),

              const Text(
                "Server Address",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),

              // --- Host / IP Input (unchanged) ---
              _softField(
                child: TextField(
                  controller: _hostController,
                  keyboardType: TextInputType.url,
                  decoration: _fieldDecoration(
                    hint: "192.168.1.1 or https://api.host.com",
                    icon: Icons.dns_rounded,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // --- Save/Connect Button ---
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleConnect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Save & Connect",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
