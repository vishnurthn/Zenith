import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math';
import 'dart:async';
import 'package:zenith/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDznJnYcixH2oUF8lcOnIb5ECu1UkMgloc",
        authDomain: "zenith-bb0c6.firebaseapp.com",
        appId: "1:598537285105:android:729fb4480529a571fa6850",
        messagingSenderId: "598537285105",
        projectId: "zenith-bb0c6",
        storageBucket: "zenith-bb0c6.appspot.com",
      ),
    );
  }
  runApp(const MaterialApp(
    home: AuthWrapper(),
    debugShowCheckedModeBanner: false,
  ));
}

// --- 1. THE SAFETY WRAPPER ---
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LoginScreen();

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .snapshots(),
          builder: (context, prof) {
            if (prof.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Colors.black,
                body:
                    Center(child: CircularProgressIndicator(color: Colors.red)),
              );
            }

            if (!prof.hasData || !prof.data!.exists) {
              return const InitialSetupPage();
            }

            final data = prof.data!.data() as Map<String, dynamic>? ?? {};

            // Critical Safety Verification: Force Registration setup if parameters are blank
            if (data['contact'] == null ||
                data['emergency'] == null ||
                data['contact'].toString().trim().isEmpty ||
                data['emergency'].toString().trim().isEmpty) {
              return const InitialSetupPage();
            }

            return ZenithDashboard(userData: data);
          },
        );
      },
    );
  }
}

// --- 2. THE LOGIN SCREEN ---
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 80, color: Colors.red),
            const Text("ZENITH",
                style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Colors.red,
                    shadows: [Shadow(color: Colors.red, blurRadius: 20)],
                    letterSpacing: 10)),
            const SizedBox(height: 50),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade900,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              onPressed: () async {
                try {
                  UserCredential userCredential = await FirebaseAuth.instance
                      .signInWithPopup(GoogleAuthProvider());

                  User? user = userCredential.user;

                  if (user != null) {
                    DocumentReference userRef = FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid);

                    DocumentSnapshot doc = await userRef.get();

                    if (!doc.exists) {
                      await userRef.set({
                        'name': user.displayName ?? "New User",
                        'email': user.email,
                        'vehicleNo': "",
                        'contact': "",
                        'emergency': "",
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    }
                  }
                } catch (e) {
                  debugPrint("Login Error: $e");
                }
              },
              child: const Text("SIGN IN WITH GOOGLE"),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 3. DEDICATED MANDATORY INITIAL REGISTRATION PAGE ---
class InitialSetupPage extends StatefulWidget {
  const InitialSetupPage({super.key});

  @override
  State<InitialSetupPage> createState() => _InitialSetupPageState();
}

class _InitialSetupPageState extends State<InitialSetupPage> {
  final _nameController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _contactController = TextEditingController();
  final _emergencyController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameController.text = user.displayName ?? "";
    }
  }

  void _submitRegistration() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String name = _nameController.text.trim();
    String vehicle = _vehicleController.text.trim();
    String contact = _contactController.text.trim();
    String emergency = _emergencyController.text.trim();

    if (name.isEmpty ||
        vehicle.isEmpty ||
        contact.isEmpty ||
        emergency.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            backgroundColor: Colors.red,
            content: Text("All fields are mandatory!")),
      );
      return;
    }

    if (contact == emergency) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            backgroundColor: Colors.red,
            content: Text("Emergency contact cannot match your own number!")),
      );
      return;
    }

    setState(() => _isSaving = true);

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'name': name,
      'email': user.email,
      'vehicleNo': vehicle,
      'contact': contact,
      'emergency': emergency,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isSaving
            ? const Center(child: CircularProgressIndicator(color: Colors.red))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("COMPLETE PROFILE",
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5)),
                    const SizedBox(height: 10),
                    const Text(
                        "Required emergency details configuration missing.",
                        style: TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 30),
                    _buildInputField(
                        "FULL NAME", _nameController, Icons.person),
                    const SizedBox(height: 15),
                    _buildInputField("VEHICLE NUMBER", _vehicleController,
                        Icons.directions_car),
                    const SizedBox(height: 15),
                    _buildInputField("PRIMARY CONTACT NUMBER",
                        _contactController, Icons.phone,
                        inputType: TextInputType.phone),
                    const SizedBox(height: 15),
                    _buildInputField("EMERGENCY CONTACT NUMBER",
                        _emergencyController, Icons.emergency,
                        inputType: TextInputType.phone),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade900,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _submitRegistration,
                      child: const Text("REGISTER ACCOUNT",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInputField(
      String label, TextEditingController controller, IconData icon,
      {TextInputType inputType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.red.shade900,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: inputType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.red.shade900, size: 18),
            filled: true,
            fillColor: const Color(0xFF0D0D0D),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red)),
          ),
        ),
      ],
    );
  }
}

// --- 4. MAIN DASHBOARD ---

class ZenithDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ZenithDashboard({super.key, required this.userData});

  @override
  State<ZenithDashboard> createState() => _ZenithDashboardState();
}

class _ZenithDashboardState extends State<ZenithDashboard> {
  dynamic get userData => widget.userData;

  double _speed = 0.0;
  double _gForce = 1.0;
  String _coords = "LINKING GPS...";

  int _secondsRemaining = 10;
  int _selectedIndex = 0;

  bool _isPersistentAlarmActive = false;
  bool _isCrashTimerRunning = false;
  bool _isCountingDown = false;
  bool _isAccelPressed = false;
  bool _isBrakePressed = false;

  Timer? _physicsTimer, _logicTimer, _sosCountdownTimer, _webSimulationTimer;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _initSensors();
    _startPhysicsLoop();
    _runMasterLogicLoop();
  }

  void _initSensors() async {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    ).listen((pos) {
      if (!mounted) return;

      setState(() {
        if (!_isAccelPressed && !_isBrakePressed && _speed < 2) {
          _speed = pos.speed < 0 ? 0 : pos.speed * 3.6;
        }

        _coords =
            "${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}";
      });
    });

    userAccelerometerEvents.listen((event) {
      double linearForceMagnitude =
          sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));

      double dynamicG = linearForceMagnitude / 9.80665;

      if (mounted) {
        setState(() {
          _gForce = 1.0 + dynamicG;
        });
      }

      if (dynamicG > 3.0 &&
          !_isCrashTimerRunning &&
          !_isPersistentAlarmActive) {
        _triggerCrashSOS();
      }
    });

    _webSimulationTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_gForce == 0.0 || _gForce == 1.0) {
        setState(() {
          if (_speed == 0) {
            _gForce = 1.0;
          } else {
            double speedFactor = _speed / 220.0;

            double vibration =
                sin(DateTime.now().millisecondsSinceEpoch * 0.05) * 0.04;

            _gForce = 1.0 + (speedFactor * 0.8) + vibration;
          }
        });
      }
    });
  }

  void _startPhysicsLoop() {
    _physicsTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;

      setState(() {
        if (_isAccelPressed) {
          _speed += 2.5;
        } else if (_isBrakePressed) {
          _speed -= 6.0;
        } else {
          _speed -= 0.6;
        }

        if (_speed < 0.5) _speed = 0;
        if (_speed > 220) _speed = 220;
      });
    });
  }

  void _runMasterLogicLoop() {
    _logicTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_speed >= 100 && !_isPersistentAlarmActive) {
        setState(() {
          _isCountingDown = true;

          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _triggerSpeedAlarm();
          }
        });
      } else if (_speed < 100 &&
          !_isPersistentAlarmActive &&
          !_isCrashTimerRunning) {
        setState(() {
          _isCountingDown = false;
          _secondsRemaining = 10;
        });
      }

      if (_isPersistentAlarmActive && _speed < 80) {
        _stopSafetyAlarms();
      }
    });
  }

  void _triggerCrashSOS() {
    setState(() {
      _isCrashTimerRunning = true;
      _isCountingDown = true;
      _secondsRemaining = 10;
    });

    _sosCountdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted || !_isCrashTimerRunning) {
          timer.cancel();
          return;
        }

        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
            Vibration.vibrate(duration: 100);
          } else {
            timer.cancel();
            _triggerSpeedAlarm();
          }
        });
      },
    );
  }

  void _triggerSpeedAlarm() async {
    if (_isPersistentAlarmActive) return;

    setState(() {
      _isPersistentAlarmActive = true;
      _isCountingDown = false;
    });

    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('alarm.mp3'));
      Vibration.vibrate(duration: 2000, repeat: 0);
    } catch (e) {
      debugPrint("Audio Error: $e");
    }
  }

  void _stopSafetyAlarms() {
    _audioPlayer.stop();
    Vibration.cancel();
    _sosCountdownTimer?.cancel();

    if (mounted) {
      setState(() {
        _isPersistentAlarmActive = false;
        _isCrashTimerRunning = false;
        _secondsRemaining = 10;
        _isCountingDown = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Color activeThemeColor = _isPersistentAlarmActive || _isCrashTimerRunning
        ? Colors.redAccent
        : (_speed >= 100 ? Colors.red : Colors.red.shade900);

    String userName = widget.userData['name'] ?? "User";

    String profileInitial =
        userName.isNotEmpty ? userName[0].toUpperCase() : "";

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(profileInitial, userName),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  _buildDashboard(activeThemeColor),
                  ZenithMapPage(userData: userData),
                  _buildAlertsPage(),
                  const EditProfilePage(),
                ],
              ),
            ),
            _buildBottomNavBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(Color activeThemeColor) {
    return Stack(
      children: [
        Column(
          children: [
            const Spacer(),
            _buildAnimatedSpeedometer(activeThemeColor),
            const Spacer(),
            _buildTelemetryPanel(),
            _buildActionButtons(),
            const SizedBox(height: 20),
          ],
        ),
        if (_isCrashTimerRunning)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning, color: Colors.red, size: 80),
                  const SizedBox(height: 20),
                  const Text(
                    "CRASH DETECTED",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Alerting emergency in $_secondsRemaining seconds",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade900,
                    ),
                    onPressed: _stopSafetyAlarms,
                    child: const Text(
                      "I AM SAFE",
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                ],
              ),
            ),
          )
      ],
    );
  }

  Widget _buildAnimatedSpeedometer(Color color) {
    double progress = (_speed / 220).clamp(0, 1);

    bool isDanger =
        _isPersistentAlarmActive || _isCrashTimerRunning || _speed >= 100;

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: isDanger
                ? [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.8),
                      blurRadius: 40,
                      spreadRadius: 10,
                    )
                  ]
                : [],
          ),
        ),
        SizedBox(
          width: 280,
          height: 280,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, child) {
              return CircularProgressIndicator(
                value: value,
                strokeWidth: 12,
                backgroundColor: Colors.white.withOpacity(0.05),
                valueColor: AlwaysStoppedAnimation(
                  isDanger ? Colors.redAccent : color,
                ),
              );
            },
          ),
        ),
        SizedBox(
          width: 240,
          height: 240,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation(
              Colors.red.withOpacity(0.4),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isCountingDown)
              Text(
                "$_secondsRemaining",
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 35,
                  fontWeight: FontWeight.bold,
                ),
              ),
            Text(
              "${_speed.toInt()}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 110,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              "KM/H",
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildTopBar(String initial, String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIndex = 3;
                  });
                },
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.red.shade900,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "ZENITH",
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    "ACTIVE: $name",
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                ],
              )
            ],
          ),
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout, color: Colors.red),
          )
        ],
      ),
    );
  }

  Widget _buildTelemetryPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.red.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _telemetryItem("G-FORCE", "${_gForce.toStringAsFixed(2)}G"),
          _telemetryItem("LOCATION", _coords),
        ],
      ),
    );
  }

  Widget _telemetryItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.red.shade900,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        )
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _actionBtn("BRAKE", Colors.red.shade900, false),
        _actionBtn("ACCEL", Colors.red, true),
      ],
    );
  }

  Widget _actionBtn(String label, Color color, bool isAccel) {
    return GestureDetector(
      onTapDown: (_) => setState(() {
        if (isAccel) {
          _isAccelPressed = true;
        } else {
          _isBrakePressed = true;
        }
      }),
      onTapUp: (_) => setState(() {
        if (isAccel) {
          _isAccelPressed = false;
        } else {
          _isBrakePressed = false;
        }
      }),
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: color.withOpacity(0.5),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlertsPage() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _alertTile(
          Icons.speed,
          "Overspeed Warning",
          "Vehicle crossed safe speed threshold",
        ),
        _alertTile(
          Icons.warning,
          "Crash Detection",
          "Impact monitoring active",
        ),
        _alertTile(
          Icons.location_on,
          "GPS Tracking",
          "Live location services enabled",
        ),
      ],
    );
  }

  Widget _alertTile(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.red.withOpacity(0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.red),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      margin: const EdgeInsets.only(left: 15, right: 15, bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.dashboard_outlined, "DASHBOARD", 0),
          _navItem(Icons.map_outlined, "MAP", 1),
          _navItem(Icons.notifications_none, "ALERTS", 2),
          _navItem(Icons.person_outline, "PROFILE", 3),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    bool active = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: active ? Colors.red : Colors.white54,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.red : Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _physicsTimer?.cancel();
    _logicTimer?.cancel();
    _sosCountdownTimer?.cancel();
    _webSimulationTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}

// --- 5. ENHANCED EDIT PROFILE PAGE ---
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  late TextEditingController _nameController;
  late TextEditingController _vehicleController;
  late TextEditingController _contactController;
  late TextEditingController _emergencyController;
  late TextEditingController _emailController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _vehicleController = TextEditingController();
    _contactController = TextEditingController();
    _emergencyController = TextEditingController();
    _emailController = TextEditingController();
    _loadUserData();
  }

  void _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _nameController.text = data['name'] ?? "";
          _vehicleController.text = data['vehicleNo'] ?? "";
          _contactController.text = data['contact'] ?? "";
          _emergencyController.text = data['emergency'] ?? "";
          _emailController.text = data['email'] ?? user.email ?? "";
          _isLoading = false;
        });
      }
    }
  }

  void _saveDetails() async {
    final user = _auth.currentUser;
    if (user == null) return;

    String contact = _contactController.text.trim();
    String emergency = _emergencyController.text.trim();

    if ((contact.isEmpty || emergency.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            backgroundColor: Colors.red,
            content: Text("Phone numbers cannot be left completely blank!")),
      );
      return;
    }

    if (contact == emergency) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
                "Emergency contact cannot be the same as your primary number!")),
      );
      return;
    }

    await _firestore.collection('users').doc(user.uid).update({
      'name': _nameController.text.trim(),
      'vehicleNo': _vehicleController.text.trim(),
      'contact': contact,
      'emergency': emergency,
      'email': _emailController.text.trim(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile Updated Successfully")));
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _vehicleController.dispose();
    _contactController.dispose();
    _emergencyController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text("EDIT PROFILE",
            style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
        iconTheme: const IconThemeData(color: Colors.red),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(25.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 20)
                          ],
                          border:
                              Border.all(color: Colors.red.shade900, width: 2)),
                      child: const CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.black,
                        child: Icon(Icons.person, color: Colors.red, size: 45),
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildEditField("FULL NAME", _nameController, Icons.badge),
                    const SizedBox(height: 15),
                    _buildEditField("VEHICLE NUMBER", _vehicleController,
                        Icons.directions_car),
                    const SizedBox(height: 15),
                    _buildEditField(
                        "CONTACT NO", _contactController, Icons.phone,
                        inputType: TextInputType.phone),
                    const SizedBox(height: 15),
                    _buildEditField("EMERGENCY CONTACT", _emergencyController,
                        Icons.emergency_share,
                        inputType: TextInputType.phone),
                    const SizedBox(height: 15),
                    _buildEditField("EMAIL ID", _emailController, Icons.email,
                        inputType: TextInputType.emailAddress),
                    const SizedBox(height: 40),
                    GestureDetector(
                      onTap: _saveDetails,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                            color: Colors.red.shade900,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.red.withOpacity(0.3),
                                  blurRadius: 15)
                            ]),
                        child: const Center(
                            child: Text("SAVE CHANGES",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEditField(
      String label, TextEditingController controller, IconData icon,
      {TextInputType inputType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.red.shade900,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: inputType,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.red.shade900, size: 18),
            filled: true,
            fillColor: const Color(0xFF0D0D0D),
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red.withOpacity(0.1))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red)),
          ),
        ),
      ],
    );
  }
}
