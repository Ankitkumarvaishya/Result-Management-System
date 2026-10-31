import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:result/screens/schoolconfiguration/firebase_config.dart';

/// Shown once, before the real app, on a fresh install that has no
/// Firebase project connected yet. The school admin copies these values
/// from THEIR Firebase Console: Project settings -> General -> Your apps
/// -> SDK setup and configuration.
class FirebaseSetupScreen extends StatefulWidget {
  final VoidCallback onConnected;
  const FirebaseSetupScreen({super.key, required this.onConnected});

  @override
  State<FirebaseSetupScreen> createState() => _FirebaseSetupScreenState();
}

class _FirebaseSetupScreenState extends State<FirebaseSetupScreen> {
  final _apiKeyCtrl = TextEditingController();
  final _appIdCtrl = TextEditingController();
  final _senderIdCtrl = TextEditingController();
  final _projectIdCtrl = TextEditingController();
  final _authDomainCtrl = TextEditingController();
  final _storageBucketCtrl = TextEditingController();
  final _measurementIdCtrl = TextEditingController();

  bool _isConnecting = false;
  String? _error;

  static const _navy = Color(0xFF0F172A);
  static const _bg = Color(0xFFF8FAFC);

  bool get _requiredFieldsFilled =>
      _apiKeyCtrl.text.trim().isNotEmpty &&
      _appIdCtrl.text.trim().isNotEmpty &&
      _senderIdCtrl.text.trim().isNotEmpty &&
      _projectIdCtrl.text.trim().isNotEmpty &&
      _authDomainCtrl.text.trim().isNotEmpty &&
      _storageBucketCtrl.text.trim().isNotEmpty;

  Future<void> _connect() async {
    if (!_requiredFieldsFilled) {
      setState(
        () =>
            _error = "Please fill in all fields (Measurement ID is optional).",
      );
      return;
    }

    setState(() {
      _isConnecting = true;
      _error = null;
    });

    try {
      // Initialize Firebase for THIS device using the values just entered.
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: _apiKeyCtrl.text.trim(),
          appId: _appIdCtrl.text.trim(),
          messagingSenderId: _senderIdCtrl.text.trim(),
          projectId: _projectIdCtrl.text.trim(),
          authDomain: _authDomainCtrl.text.trim(),
          storageBucket: _storageBucketCtrl.text.trim(),
          measurementId: _measurementIdCtrl.text.trim().isEmpty
              ? null
              : _measurementIdCtrl.text.trim(),
        ),
      );

      // Only save (and proceed) once Firebase actually accepted the config.
      await FirebaseConfigStore.save(
        apiKey: _apiKeyCtrl.text.trim(),
        appId: _appIdCtrl.text.trim(),
        messagingSenderId: _senderIdCtrl.text.trim(),
        projectId: _projectIdCtrl.text.trim(),
        authDomain: _authDomainCtrl.text.trim(),
        storageBucket: _storageBucketCtrl.text.trim(),
        measurementId: _measurementIdCtrl.text.trim(),
      );

      widget.onConnected();
    } catch (e) {
      setState(
        () => _error =
            "Couldn't connect. Please double-check your values and try again.",
      );
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Widget _softField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool optional = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        decoration: InputDecoration(
          labelText: optional ? '$label (optional)' : label,
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.blueGrey.shade50, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header icon ---
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  color: _navy,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: _navy.withOpacity(0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.orangeAccent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                "Connect Firebase For Result Management System",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Link this app to your school's own Firebase project. "
                "You'll find these values in the Firebase Console under "
                "Project settings → General → Your apps.",
                style: TextStyle(color: Colors.blueGrey.shade400, height: 1.4),
              ),
              const SizedBox(height: 32),

              _softField(
                controller: _apiKeyCtrl,
                label: 'API Key',
                icon: Icons.vpn_key_rounded,
              ),
              const SizedBox(height: 16),
              _softField(
                controller: _appIdCtrl,
                label: 'App ID',
                icon: Icons.apps_rounded,
              ),
              const SizedBox(height: 16),
              _softField(
                controller: _senderIdCtrl,
                label: 'Messaging Sender ID',
                icon: Icons.forward_to_inbox_rounded,
              ),
              const SizedBox(height: 16),
              _softField(
                controller: _projectIdCtrl,
                label: 'Project ID',
                icon: Icons.folder_special_rounded,
              ),
              const SizedBox(height: 16),
              _softField(
                controller: _authDomainCtrl,
                label: 'Auth Domain',
                icon: Icons.lock_outline_rounded,
              ),
              const SizedBox(height: 16),
              _softField(
                controller: _storageBucketCtrl,
                label: 'Storage Bucket',
                icon: Icons.storage_rounded,
              ),
              const SizedBox(height: 16),
              _softField(
                controller: _measurementIdCtrl,
                label: 'Measurement ID',
                icon: Icons.query_stats_rounded,
                optional: true,
              ),

              const SizedBox(height: 12),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _error != null
                    ? Container(
                        key: ValueKey(_error),
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: Colors.red.shade400,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isConnecting ? null : _connect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _isConnecting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.link_rounded, size: 20),
                            SizedBox(width: 10),
                            Text(
                              "Connect",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              Center(
                child: Text(
                  "Your values are stored only on this device.",
                  style: TextStyle(
                    color: Colors.blueGrey.shade300,
                    fontSize: 12,
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
