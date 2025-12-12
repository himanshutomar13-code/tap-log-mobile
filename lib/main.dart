import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as lm;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'firebase_options.dart';

const String appId = 'tap-log';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const TapLogMobileApp());
}

class TapLogMobileApp extends StatelessWidget {
  const TapLogMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tap Log Field App',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const RootScreen(),
    );
  }
}

class AppUserProfile {
  final String id;
  final String empId;
  final String name;
  final String email;
  final String phone;
  final String role; // employee / admin / manager
  final String employeeCategory; // Direct / Indirect / Contract / Vendor
  final String dutyType; // Field / Static
  final String status; // Active / Inactive
  // Reporting manager info (used for leave/travel approvals)
  final String managerEmpId;
  final String managerName;
  final String managerEmail;

  AppUserProfile({
    required this.id,
    required this.empId,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.employeeCategory,
    required this.dutyType,
    required this.status,
    required this.managerEmpId,
    required this.managerName,
    required this.managerEmail,
  });

  factory AppUserProfile.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return AppUserProfile(
      id: id,
      empId: data['empId'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'employee',
      employeeCategory: data['employeeCategory'] ?? 'Direct',
      dutyType: data['dutyType'] ?? 'Field',
      status: data['status'] ?? 'Active',
      managerEmpId: data['managerEmpId'] ??
          data['reportingManagerEmpId'] ??
          data['manager_emp_id'] ??
          '',
      managerName: data['managerName'] ??
          data['reportingManagerName'] ??
          data['manager_name'] ??
          '',
      managerEmail: data['managerEmail'] ??
          data['reportingManagerEmail'] ??
          data['manager_email'] ??
          '',
    );
  }
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return const AuthScreen();
        }
        return FutureBuilder<AppUserProfile?>(
          future: _loadUserProfile(user.uid),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (!snap.hasData || snap.data == null) {
              return const Scaffold(
                body: Center(
                  child: Text('No profile found for this user.'),
                ),
              );
            }
            final profile = snap.data!;
            if (profile.role == 'admin' || profile.role == 'manager') {
              return AdminHomeScreen(profile: profile);
            }
            return EmployeeHomeScreen(profile: profile);
          },
        );
      },
    );
  }

  Future<AppUserProfile?> _loadUserProfile(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('artifacts')
        .doc(appId)
        .collection('public')
        .doc('data')
        .collection('users')
        .doc(uid)
        .get();

    if (!doc.exists) return null;
    return AppUserProfile.fromFirestore(doc.id, doc.data()!);
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message ?? 'Login failed';
      });
    } catch (e) {
      setState(() {
        _error = 'Login failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Icon(Icons.location_on, size: 64, color: Colors.indigo),
                const SizedBox(height: 12),
                const Text(
                  'Tap Log Field App',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Login'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ==== Employee App (field/static user) ====

class EmployeeHomeScreen extends StatefulWidget {
  final AppUserProfile profile;
  const EmployeeHomeScreen({super.key, required this.profile});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  int _tabIndex = 0; // 0 = Attendance, 1 = Tasks, 2 = Requests

  bool _dutyOn = false;
  bool _initializing = false;
  bool _travelMode = false; // For Static employees
  bool _exportingTravel = false; // for Export Today's Travel

  StreamSubscription<Position>? _positionSub;

  // --- Mini-map state ---
  final List<lm.LatLng> _pathPoints = [];
  lm.LatLng? _currentMapCenter;
  // Controller to allow programmatic map movement so the map follows the user
  final MapController _mapController = MapController();
  double _mapZoom = 15.0;

  final _picker = ImagePicker();

  DocumentReference<Map<String, dynamic>> get _rootDoc {
    return FirebaseFirestore.instance
        .collection('artifacts')
        .doc(appId)
        .collection('public')
        .doc('data');
  }
    DocumentReference<Map<String, dynamic>> get _dutyStateDoc {
    return _rootDoc.collection('duty_state').doc(widget.profile.id);
  }

  // Base duty type as configured in profile
  bool get _isBaseFieldEmployee {
    final t = widget.profile.dutyType.toUpperCase();
    return t == 'FIELD';
  }

  // Effective duty type for tracking: base Field OR Static + travel mode
  bool get _isEffectiveFieldEmployee => _isBaseFieldEmployee || _travelMode;

  @override
  void initState() {
    super.initState();
    _restoreDutyState();
  }

  Future<void> _restoreDutyState() async {
    try {
      // Read existing duty state from Firestore
      final snapshot = await _dutyStateDoc.get();
      if (!snapshot.exists) return;

      final data = snapshot.data();
      if (data == null) return;

      final onDuty = data['onDuty'] == true;
      if (!onDuty) return; // nothing to restore

      final savedTravelMode = data['travelMode'];

      if (mounted) {
        setState(() {
          _dutyOn = true;
          // restore travel toggle only for static employees
          if (!_isBaseFieldEmployee && savedTravelMode is bool) {
            _travelMode = savedTravelMode;
          }
        });
      }

      // Kick background tracking back on
      final ok = await _ensureLocationPermission();
      if (!ok) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _startTracking(pos);
    } catch (e) {
      // optional: ignore or log
      debugPrint('Failed to restore duty state: $e');
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable location services on the device.'),
          ),
        );
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Location permission is required for live tracking.'),
          ),
        );
      }
      return false;
    }

    return true;
  }

  /// Store a point for the mini-map path
  void _addPathPoint(Position position) {
    if (!mounted) return;
    final point = lm.LatLng(position.latitude, position.longitude);
    setState(() {
      _currentMapCenter = point;
      _pathPoints.add(point);
      // Keep the list from growing forever (last 300 points)
      if (_pathPoints.length > 300) {
        _pathPoints.removeRange(0, _pathPoints.length - 300);
      }
    });
    // Move the map to keep the current position centered. Schedule after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mapController.move(point, _mapZoom);
      } catch (_) {
        // controller may not be ready yet; ignore failures
      }
    });
  }

  /// Write punch for dashboard
  Future<void> _recordPunch({
    required String type, // 'in' or 'out'
    required Position position,
  }) async {
    final locationText =
        'Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)}';

    final now = Timestamp.now();
    final upper = type.toUpperCase(); // 'IN' or 'OUT'

    await _rootDoc.collection('attendance').add({
      'userId': widget.profile.id,
      'userName': widget.profile.name,
      'empId': widget.profile.empId,
      'employeeCategory': widget.profile.employeeCategory,
      'dutyType': widget.profile.dutyType,
      'effectiveDutyType':
          _isEffectiveFieldEmployee ? 'Field' : widget.profile.dutyType,
      'travelMode': _travelMode,
      'type': type, // 'in' / 'out'
      'action': upper, // 'IN' / 'OUT'
      'timestamp': now,
      'time': now,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'locationText': locationText,
      'deviceType': 'mobile',
      'source': 'field-app',
    });
  }

  Future<void> _sendLiveLocation(Position position) async {
    final latestDoc =
        _rootDoc.collection('live_locations').doc(widget.profile.id);

    await Future.wait([
      latestDoc.set({
        'userId': widget.profile.id,
        'userName': widget.profile.name,
        'empId': widget.profile.empId,
        'employeeCategory': widget.profile.employeeCategory,
        'dutyType': widget.profile.dutyType,
        'effectiveDutyType':
            _isEffectiveFieldEmployee ? 'Field' : widget.profile.dutyType,
        'travelMode': _travelMode,
        'dutyOn': true,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      _rootDoc.collection('location_trails').add({
        'userId': widget.profile.id,
        'userName': widget.profile.name,
        'empId': widget.profile.empId,
        'employeeCategory': widget.profile.employeeCategory,
        'dutyType': widget.profile.dutyType,
        'effectiveDutyType':
            _isEffectiveFieldEmployee ? 'Field' : widget.profile.dutyType,
        'travelMode': _travelMode,
        'dutyOn': true,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'timestamp': FieldValue.serverTimestamp(),
      }),
    ]);
  }

  Future<void> _startTracking(Position initialPosition) async {
    // First point: store locally AND in Firestore
    _addPathPoint(initialPosition);
    await _sendLiveLocation(initialPosition);

    // Continuous tracking only for effective Field employees
    if (!_isEffectiveFieldEmployee) return;

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // ~5 meters
      ),
    ).listen((position) async {
      _addPathPoint(position);
      await _sendLiveLocation(position);
    });
  }

  Future<void> _stopTracking() async {
    await _positionSub?.cancel();
    _positionSub = null;

    final latestDoc =
        _rootDoc.collection('live_locations').doc(widget.profile.id);

    await latestDoc.set({
      'dutyOn': false,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

    /// Auto-create a simple travel request for *today* when
  /// a STATIC employee uses "Track my travel" and starts duty.
  Future<void> _ensureDailyTravelRequestIfNeeded(Position position) async {
    // Only when travel toggle is ON
    if (!_travelMode) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final p = widget.profile;

    // Normalised date key so we don't create duplicates for the same day
    final now = DateTime.now();
    final dateKey =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    // Check if an auto travel request already exists for today
    final existing = await _rootDoc
        .collection('travelRequests')
        .where('userId', isEqualTo: user.uid)
        .where('dateKey', isEqualTo: dateKey)
        .where('autoCreated', isEqualTo: true)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      // Already created for today – nothing to do
      return;
    }

    // Create a very simple, auto-generated travel request
    await _rootDoc.collection('travelRequests').add({
      'userId': user.uid,
      'empId': p.empId,
      'name': p.name,

      // Single-day travel: from = to = today
      'fromDate': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
      'toDate': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),

      'fromLocation': 'Auto: Mobile tracking started',
      'toLocation': null,
      'purpose': 'Auto travel (field tracking) for this day',
      'estimatedCost': null,

      'status': 'Pending',

      // Manager snapshot (for approvals)
      'managerEmpId': p.managerEmpId,
      'managerName': p.managerName,
      'managerEmail': p.managerEmail,

      'createdAt': FieldValue.serverTimestamp(),

      // Flags/metadata
      'autoCreated': true,
      'dateKey': dateKey,
      'startLat': position.latitude,
      'startLng': position.longitude,
      'source': 'mobile-auto',
    });
  }


  Future<void> _toggleDuty() async {
    if (_initializing) return;

    setState(() => _initializing = true);

    try {
      final ok = await _ensureLocationPermission();
      if (!ok) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!_dutyOn) {
        // START DUTY => fresh path + Punch IN + start tracking
        _pathPoints.clear();
        _currentMapCenter = null;

        await _recordPunch(type: 'in', position: position);

        // 🔹 NEW: if "Track my travel" is ON, auto-create a travel request for today
        await _ensureDailyTravelRequestIfNeeded(position);

        await _startTracking(position);

        // 🔹 Save duty state in Firestore so we can auto-resume later
        await _dutyStateDoc.set({
          'onDuty': true,
          'startedAt': FieldValue.serverTimestamp(),
          'travelMode': _travelMode,
          'effectiveDutyType':
              _isEffectiveFieldEmployee ? 'Field' : widget.profile.dutyType,
        }, SetOptions(merge: true));

        if (mounted) {
          setState(() => _dutyOn = true);
        }
      } else {
        // STOP DUTY => Punch OUT + stop tracking + clear path
        await _recordPunch(type: 'out', position: position);
        await _stopTracking();
        _pathPoints.clear();
        _currentMapCenter = null;

        // 🔹 Mark duty session as closed
        await _dutyStateDoc.set({
          'onDuty': false,
          'endedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          setState(() => _dutyOn = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update duty: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _initializing = false);
      }
    }
  }

  Future<void> _exportTodayTravel() async {
    if (_exportingTravel) return;

    setState(() {
      _exportingTravel = true;
    });

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // 1) Load today's trail points for this user
      final query = await _rootDoc
          .collection('location_trails')
          .where('userId', isEqualTo: widget.profile.id)
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp',
              isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('timestamp')
          .get();

      final docs = query.docs;
      if (docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No travel data recorded for today.'),
            ),
          );
        }
        return;
      }

      // Build a simple PDF
      final pdf = pw.Document();

      // Extract basic stats
      final firstTs = (docs.first['timestamp'] as Timestamp).toDate();
      final lastTs = (docs.last['timestamp'] as Timestamp).toDate();
      final duration = lastTs.difference(firstTs);

      String _fmtDate(DateTime d) =>
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      String _fmtTime(DateTime d) =>
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return [
              pw.Text('Tap Log – Daily Travel Report',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  )),
              pw.SizedBox(height: 8),
              pw.Text('Date: ${_fmtDate(startOfDay)}'),
              pw.Text('Employee: ${widget.profile.name} (${widget.profile.empId})'),
              pw.Text('Duty Type: ${widget.profile.dutyType}'),
              pw.SizedBox(height: 8),
              pw.Text(
                  'From: ${_fmtTime(firstTs)}   To: ${_fmtTime(lastTs)}   Duration: ${duration.inHours}h ${(duration.inMinutes % 60).toString().padLeft(2, '0')}m'),
              pw.SizedBox(height: 16),
              pw.Text(
                'Travel points (time, latitude, longitude)',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Table.fromTextArray(
                headerStyle:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headers: ['#', 'Time', 'Latitude', 'Longitude'],
                data: List<List<String>>.generate(docs.length, (index) {
                  final data = docs[index].data();
                  final ts = (data['timestamp'] as Timestamp).toDate();
                  final lat = (data['latitude'] ?? '').toString();
                  final lng = (data['longitude'] ?? '').toString();
                  return [
                    (index + 1).toString(),
                    _fmtTime(ts),
                    lat,
                    lng,
                  ];
                }),
              ),
            ];
          },
        ),
      );

      final Uint8List bytes = await pdf.save();

      // 3) Upload to Firebase Storage
      final storage = FirebaseStorage.instance;
      final dateStr =
          '${startOfDay.year}-${startOfDay.month.toString().padLeft(2, '0')}-${startOfDay.day.toString().padLeft(2, '0')}';
      final fileName =
          'travel_${widget.profile.empId}_${dateStr}_${now.millisecondsSinceEpoch}.pdf';

      final ref = storage
          .ref()
          .child('travel-summaries')
          .child(widget.profile.id)
          .child(fileName);

      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'application/pdf'),
      );

      final url = await ref.getDownloadURL();

      // 4) Save metadata in Firestore for portal
      await _rootDoc.collection('travelSummaries').add({
        'userId': widget.profile.id,
        'empId': widget.profile.empId,
        'name': widget.profile.name,
        'date': Timestamp.fromDate(startOfDay),
        'fromTimestamp': Timestamp.fromDate(firstTs),
        'toTimestamp': Timestamp.fromDate(lastTs),
        'points': docs.length,
        'fileUrl': url,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Today\'s travel exported and saved.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export travel: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _exportingTravel = false;
        });
      }
    }
  }

  Future<void> _openLeaveRequestSheet() async {
    final p = widget.profile;

    DateTime? fromDate;
    DateTime? toDate;
    final reasonController = TextEditingController();
    bool submitting = false;
    String? error;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            Future<void> pickFrom() async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => fromDate = picked);
              }
            }

            Future<void> pickTo() async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: fromDate ?? DateTime.now(),
                firstDate: fromDate ?? DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => toDate = picked);
              }
            }

            Future<void> submit() async {
              if (submitting) return;
              if (fromDate == null || toDate == null) {
                setState(() => error = 'Please select from and to dates.');
                return;
              }
              if (reasonController.text.trim().isEmpty) {
                setState(() => error = 'Please enter a reason.');
                return;
              }

              setState(() {
                submitting = true;
                error = null;
              });

              try {
                final rootDoc = FirebaseFirestore.instance
                    .collection('artifacts')
                    .doc(appId)
                    .collection('public')
                    .doc('data');

                await rootDoc.collection('leaveRequests').add({
                  'userId': FirebaseAuth.instance.currentUser?.uid,
                  'empId': p.empId,
                  'name': p.name,
                  'fromDate': Timestamp.fromDate(fromDate!),
                  'toDate': Timestamp.fromDate(toDate!),
                  'reason': reasonController.text.trim(),
                  'status': 'Pending',
                  // snapshot of reporting manager at time of request
                  'managerEmpId': p.managerEmpId,
                  'managerName': p.managerName,
                  'managerEmail': p.managerEmail,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (Navigator.of(ctx).canPop()) {
                  Navigator.of(ctx).pop();
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Leave request submitted for approval.'),
                    ),
                  );
                }
              } catch (e) {
                setState(() {
                  submitting = false;
                  error = 'Error submitting leave: $e';
                });
              }
            }

            String _format(DateTime? d) {
              if (d == null) return 'Select date';
              return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Apply for Leave',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Employee: ${p.name} (${p.empId})',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: pickFrom,
                          child: Text('From: ${_format(fromDate)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton(
                          onPressed: pickTo,
                          child: Text('To: ${_format(toDate)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (error != null) ...[
                    Text(
                      error!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: submitting ? null : submit,
                      child: Text(
                        submitting ? 'Submitting...' : 'Submit Leave Request',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openTravelRequestSheet() async {
    final p = widget.profile;

    DateTime? fromDate;
    DateTime? toDate;
    final fromLocationController = TextEditingController();
    final toLocationController = TextEditingController();
    final purposeController = TextEditingController();
    final costController = TextEditingController();
    bool submitting = false;
    String? error;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            Future<void> pickFromDate() async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => fromDate = picked);
              }
            }

            Future<void> pickToDate() async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: fromDate ?? DateTime.now(),
                firstDate: fromDate ?? DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => toDate = picked);
              }
            }

            String _format(DateTime? d) {
              if (d == null) return 'Select date';
              return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
            }

            Future<void> submit() async {
              if (submitting) return;

              if (fromDate == null || toDate == null) {
                setState(() => error = 'Please select from and to dates.');
                return;
              }
              if (fromLocationController.text.trim().isEmpty ||
                  toLocationController.text.trim().isEmpty) {
                setState(() => error = 'Please enter from and to locations.');
                return;
              }
              if (purposeController.text.trim().isEmpty) {
                setState(() => error = 'Please enter travel purpose.');
                return;
              }

              setState(() {
                submitting = true;
                error = null;
              });

              try {
                final rootDoc = FirebaseFirestore.instance
                    .collection('artifacts')
                    .doc(appId)
                    .collection('public')
                    .doc('data');

                double? estimatedCost;
                if (costController.text.trim().isNotEmpty) {
                  estimatedCost = double.tryParse(costController.text.trim());
                }

                await rootDoc.collection('travelRequests').add({
                  'userId': FirebaseAuth.instance.currentUser?.uid,
                  'empId': p.empId,
                  'name': p.name,
                  'fromDate': Timestamp.fromDate(fromDate!),
                  'toDate': Timestamp.fromDate(toDate!),
                  'fromLocation': fromLocationController.text.trim(),
                  'toLocation': toLocationController.text.trim(),
                  'purpose': purposeController.text.trim(),
                  'estimatedCost': estimatedCost,
                  'status': 'Pending',
                  // snapshot of reporting manager
                  'managerEmpId': p.managerEmpId,
                  'managerName': p.managerName,
                  'managerEmail': p.managerEmail,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (Navigator.of(ctx).canPop()) {
                  Navigator.of(ctx).pop();
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Travel request submitted for approval.'),
                    ),
                  );
                }
              } catch (e) {
                setState(() {
                  submitting = false;
                  error = 'Error submitting travel request: $e';
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Request Travel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Employee: ${p.name} (${p.empId})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: pickFromDate,
                            child: Text('From: ${_format(fromDate)}'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton(
                            onPressed: pickToDate,
                            child: Text('To: ${_format(toDate)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: fromLocationController,
                      decoration: const InputDecoration(
                        labelText: 'From Location',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: toLocationController,
                      decoration: const InputDecoration(
                        labelText: 'To Location',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: purposeController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Purpose',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: costController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Estimated Cost (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (error != null) ...[
                      Text(
                        error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: submitting ? null : submit,
                        child: Text(
                          submitting
                              ? 'Submitting...'
                              : 'Submit Travel Request',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAttendanceBody(BuildContext context) {
    final p = widget.profile;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.indigo.shade100,
                    child: Text(
                      p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${p.empId} • ${p.employeeCategory}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Duty Type: ${p.dutyType.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _dutyOn
                          ? Colors.greenAccent.shade100
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _dutyOn ? 'ON DUTY' : 'OFF DUTY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            _dutyOn ? Colors.green.shade700 : Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Travel toggle for non-FIELD employees
          if (!_isBaseFieldEmployee) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Track my travel today',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _dutyOn
                            ? 'Stop duty to change this option.'
                            : 'Use this when you are visiting a client or travelling.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _travelMode,
                  onChanged: _dutyOn
                      ? null
                      : (val) {
                          setState(() {
                            _travelMode = val;
                          });
                        },
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_initializing)
                    Column(
                      children: const [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Starting location tracking...',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    )
                  else
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _toggleDuty,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _dutyOn
                                    ? [
                                        Colors.redAccent,
                                        Colors.red.shade700
                                      ]
                                    : [
                                        Colors.greenAccent.shade400,
                                        Colors.green.shade700
                                      ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (_dutyOn ? Colors.red : Colors.green)
                                          .withOpacity(0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                )
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _dutyOn ? 'STOP DUTY' : 'START DUTY',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Mini map showing today's path
                        if (_dutyOn && _currentMapCenter != null) ...[
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 170,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: _currentMapCenter!,
                                  initialZoom: _mapZoom,
                                  interactionOptions:
                                      const InteractionOptions(
                                    flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
                                  ),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    subdomains: const ['a', 'b', 'c'],
                                  ),
                                  if (_pathPoints.isNotEmpty)
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(
                                          points: _pathPoints,
                                          strokeWidth: 2,
                                          color: Colors.blueAccent,
                                        ),
                                      ],
                                    ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: _currentMapCenter!,
                                        width: 40,
                                        height: 40,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.blue,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.25),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                        Text(
                          _dutyOn
                              ? 'We are sending your location to Tap Log.\nKeep the app open to continue tracking.'
                              : 'Tap to start your duty.\nLocation will be recorded for attendance & tracking.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Note: Location is used only for attendance & live tracking\n'
            'as per your company policy.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tap Log – Field App'),
        actions: [
          IconButton(
            tooltip: 'Request Travel',
            icon: const Icon(Icons.route_outlined),
            onPressed: _openTravelRequestSheet,
          ),
          IconButton(
            tooltip: 'Apply for Leave',
            icon: const Icon(Icons.beach_access_outlined),
            onPressed: _openLeaveRequestSheet,
          ),
          IconButton(
            tooltip: 'Export today\'s travel',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exportingTravel ? null : _exportTodayTravel,
          ),
          if (_exportingTravel)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _stopTracking();
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
            body: _tabIndex == 0
          ? _buildAttendanceBody(context)
          : _tabIndex == 1
              ? EmployeeTasksTab(
                  profile: widget.profile,
                  rootDoc: _rootDoc,
                )
              : MyRequestsTab(
                  profile: widget.profile,
                  rootDoc: _rootDoc,
                ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.checklist),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            label: 'My Requests',
          ),
        ],
      ),

    );
  }
}

class EmployeeTasksTab extends StatelessWidget {
  final AppUserProfile profile;
  final DocumentReference<Map<String, dynamic>> rootDoc;

  const EmployeeTasksTab({
    super.key,
    required this.profile,
    required this.rootDoc,
  });

  @override
  Widget build(BuildContext context) {
    // Currently we show all tasks; later we can filter to only this employee.
    final tasksQuery = rootDoc.collection('tasks');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Tasks',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Showing all tasks from portal (temporary).',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: tasksQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading tasks:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No tasks found in the system.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();

                    final title = (data['title'] ?? 'Untitled Task').toString();
                    final description =
                        (data['description'] ?? '').toString();
                    final status =
                        (data['status'] ?? 'Pending').toString().trim();
                    final assigneeName =
                        (data['assignedToName'] ?? data['userName'] ?? '')
                            .toString();
                    final targetSites =
                        (data['targetSiteNames'] ?? data['siteNames'] ?? '')
                            .toString();

                    // Handle dueDate as either String or Timestamp
                    final rawDue = data['dueDate'];
                    String dueStr = 'No due date';
                    if (rawDue is Timestamp) {
                      final dt = rawDue.toDate();
                      dueStr =
                          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
                    } else if (rawDue is String && rawDue.isNotEmpty) {
                      dueStr = rawDue;
                    }

                    final isDone = status.toUpperCase() == 'COMPLETED' ||
                        status.toUpperCase() == 'VERIFIED';

                    Color statusBg;
                    Color statusFg;
                    if (status.toUpperCase() == 'PENDING') {
                      statusBg = Colors.orange.shade50;
                      statusFg = Colors.orange.shade700;
                    } else if (isDone) {
                      statusBg = Colors.green.shade50;
                      statusFg = Colors.green.shade700;
                    } else {
                      statusBg = Colors.blue.shade50;
                      statusFg = Colors.blue.shade700;
                    }

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title + status pill
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusBg,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: statusFg,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            if (assigneeName.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Assigned to: $assigneeName',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                description,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                            if (targetSites.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'At: $targetSites',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.indigo,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              'Due: $dueStr',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),

                            // Button for proof upload + complete
                            if (!isDone) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () =>
                                      _openProofSheet(context, doc),
                                  child: const Text(
                                    'Add Photos / Videos & Complete',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                            if (isDone) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Proof submitted. Waiting for approval.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green,
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom sheet for selecting photos/videos and marking task completed.
  Future<void> _openProofSheet(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> taskDoc,
  ) async {
    final picker = ImagePicker();
    List<XFile> cameraPhotos = [];
    List<XFile> galleryPhotos = [];
    List<XFile> videos = [];
    bool uploading = false;
    String? error;

    Future<Position?> _getPositionWithPermission() async {
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          return null;
        }
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return null;
        }
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (_) {
        return null;
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            Future<void> pickCameraPhoto() async {
              try {
                final picked = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                );
                if (picked != null) {
                  setState(() => cameraPhotos = [...cameraPhotos, picked]);
                }
              } catch (e) {
                setState(() => error = 'Error capturing photo: $e');
              }
            }

            Future<void> pickGalleryPhotos() async {
              try {
                final picked = await picker.pickMultiImage(
                  imageQuality: 80,
                );
                if (picked.isNotEmpty) {
                  setState(
                      () => galleryPhotos = [...galleryPhotos, ...picked]);
                }
              } catch (e) {
                setState(() => error = 'Error picking photos: $e');
              }
            }

            Future<void> pickVideo() async {
              try {
                final picked =
                    await picker.pickVideo(source: ImageSource.camera);
                if (picked != null) {
                  setState(() => videos = [...videos, picked]);
                }
              } catch (e) {
                setState(() => error = 'Error capturing video: $e');
              }
            }

            Future<void> uploadAndComplete() async {
              if (uploading) return;

              final totalPhotos =
                  cameraPhotos.length + galleryPhotos.length;
              final totalVideos = videos.length;

              if (totalPhotos == 0 && totalVideos == 0) {
                setState(() =>
                    error = 'Please add at least one photo or video.');
                return;
              }

              setState(() {
                uploading = true;
                error = null;
              });

              try {
                final pos = await _getPositionWithPermission();
                final storage = FirebaseStorage.instance;
                final List<String> urls = [];
                final List<Map<String, dynamic>> proofs = [];
                final taskId = taskDoc.id;

                // Upload camera photos
                for (var i = 0; i < cameraPhotos.length; i++) {
                  final file = cameraPhotos[i];
                  final now = DateTime.now().millisecondsSinceEpoch;
                  final path =
                      'task-proofs/$taskId/${now}_cam_img_$i.${file.path.split('.').last}';
                  final ref = storage.ref().child(path);
                  await ref.putFile(File(file.path));
                  final url = await ref.getDownloadURL();
                  urls.add(url);
                  proofs.add({
                    'url': url,
                    'type': 'photo',
                    'source': 'camera',
                    'takenAt': Timestamp.now(),
                    'lat': pos?.latitude,
                    'lng': pos?.longitude,
                  });
                }

                // Upload gallery photos
                for (var i = 0; i < galleryPhotos.length; i++) {
                  final file = galleryPhotos[i];
                  final now = DateTime.now().millisecondsSinceEpoch;
                  final path =
                      'task-proofs/$taskId/${now}_gal_img_$i.${file.path.split('.').last}';
                  final ref = storage.ref().child(path);
                  await ref.putFile(File(file.path));
                  final url = await ref.getDownloadURL();
                  urls.add(url);
                  proofs.add({
                    'url': url,
                    'type': 'photo',
                    'source': 'gallery',
                    'takenAt': Timestamp.now(),
                    'lat': pos?.latitude,
                    'lng': pos?.longitude,
                  });
                }

                // Upload videos (camera)
                for (var i = 0; i < videos.length; i++) {
                  final file = videos[i];
                  final now = DateTime.now().millisecondsSinceEpoch;
                  final path =
                      'task-proofs/$taskId/${now}_vid_$i.${file.path.split('.').last}';
                  final ref = storage.ref().child(path);
                  await ref.putFile(File(file.path));
                  final url = await ref.getDownloadURL();
                  urls.add(url);
                  proofs.add({
                    'url': url,
                    'type': 'video',
                    'source': 'camera',
                    'takenAt': Timestamp.now(),
                    'lat': pos?.latitude,
                    'lng': pos?.longitude,
                  });
                }

                await taskDoc.reference.set({
                  'status': 'Completed',
                  'completedAt': FieldValue.serverTimestamp(),
                  'proofUrls': FieldValue.arrayUnion(urls),
                  'proofs': FieldValue.arrayUnion(proofs),
                }, SetOptions(merge: true));

                if (Navigator.of(ctx).canPop()) {
                  Navigator.of(ctx).pop();
                }
              } catch (e) {
                setState(() {
                  error = 'Error uploading proof: $e';
                  uploading = false;
                });
              }
            }

            final totalPhotos =
                cameraPhotos.length + galleryPhotos.length;
            final totalVideos = videos.length;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Submit Task Proof',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: uploading ? null : pickCameraPhoto,
                          child: const Text('Camera Photo'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: uploading ? null : pickGalleryPhotos,
                          child: const Text('Gallery Photos'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: uploading ? null : pickVideo,
                      child: const Text('Record Video'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Selected photos: $totalPhotos, videos: $totalVideos',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  if (error != null) ...[
                    Text(
                      error!,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: uploading ? null : uploadAndComplete,
                      child: Text(
                        uploading
                            ? 'Uploading...'
                            : 'Upload & Mark as Completed',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class MyRequestsTab extends StatelessWidget {
  final AppUserProfile profile;
  final DocumentReference<Map<String, dynamic>> rootDoc;

  const MyRequestsTab({
    super.key,
    required this.profile,
    required this.rootDoc,
  });

  Future<void> _openNewExpenseSheet(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DateTime expenseDate = DateTime.now();
    String category = 'Travel';
    final amountController = TextEditingController();
    final descController = TextEditingController();
    List<XFile> billPhotos = [];
    bool submitting = false;
    String? error;

    final picker = ImagePicker();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: expenseDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => expenseDate = picked);
              }
            }

            Future<void> addCameraBill() async {
              try {
                final picked = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                );
                if (picked != null) {
                  setState(() {
                    billPhotos = [...billPhotos, picked];
                  });
                }
              } catch (e) {
                setState(() {
                  error = 'Error capturing bill photo: $e';
                });
              }
            }

            Future<void> addGalleryBills() async {
              try {
                final picked = await picker.pickMultiImage(
                  imageQuality: 85,
                );
                if (picked.isNotEmpty) {
                  setState(() {
                    billPhotos = [...billPhotos, ...picked];
                  });
                }
              } catch (e) {
                setState(() {
                  error = 'Error picking bill photos: $e';
                });
              }
            }

            Future<void> submit() async {
              if (submitting) return;

              final amtText = amountController.text.trim();
              final descText = descController.text.trim();

              double? amount = double.tryParse(amtText);
              if (amount == null || amount <= 0) {
                setState(() {
                  error = 'Please enter a valid amount.';
                });
                return;
              }

              if (descText.isEmpty) {
                setState(() {
                  error = 'Please enter a short description.';
                });
                return;
              }

              setState(() {
                submitting = true;
                error = null;
              });

              try {
                final expensesCol = rootDoc.collection('expenses');
                final docRef = expensesCol.doc(); // pre-generate ID

                // Upload bill photos first
                final storage = FirebaseStorage.instance;
                final List<Map<String, dynamic>> attachments = [];

                for (var i = 0; i < billPhotos.length; i++) {
                  final file = billPhotos[i];
                  final ext = file.path.split('.').last;
                  final path =
                      'expense-attachments/${profile.id}/${docRef.id}/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';

                  final ref = storage.ref().child(path);
                  await ref.putFile(File(file.path));
                  final url = await ref.getDownloadURL();

                  attachments.add({
                    'url': url,
                    'storagePath': path,
                    'fileType': 'photo',
                    'source': 'camera_or_gallery',
                    'uploadedAt': Timestamp.now(),
                  });
                }

                await docRef.set({
                  'userId': user.uid,
                  'empId': profile.empId,
                  'name': profile.name,
                  'managerEmpId': profile.managerEmpId,
                  'managerName': profile.managerName,
                  'managerEmail': profile.managerEmail,
                  'expenseDate': Timestamp.fromDate(
                    DateTime(
                      expenseDate.year,
                      expenseDate.month,
                      expenseDate.day,
                    ),
                  ),
                  'createdAt': FieldValue.serverTimestamp(),
                  'category': category,
                  'amount': amount,
                  'currency': 'INR',
                  'description': descText,
                  'attachments': attachments,
                  'status': 'Pending',
                  'statusByEmpId': null,
                  'statusByName': null,
                  'statusAt': null,
                  'statusRemark': null,
                  'financeStatus': 'Not Submitted',
                  'financeSubmittedAt': null,
                  'financeReference': null,
                  'summaryPdfUrl': null,
                });

                if (Navigator.of(ctx).canPop()) {
                  Navigator.of(ctx).pop();
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Expense submitted for approval.'),
                  ),
                );
              } catch (e) {
                setState(() {
                  submitting = false;
                  error = 'Error submitting expense: $e';
                });
              }
            }

            String _formatDate(DateTime d) {
              return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
            }

            final totalBills = billPhotos.length;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'New Expense',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${profile.name} (${profile.empId})',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: pickDate,
                            child: Text('Date: ${_formatDate(expenseDate)}'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: category,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 8),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Travel',
                                child: Text('Travel'),
                              ),
                              DropdownMenuItem(
                                value: 'Food',
                                child: Text('Food'),
                              ),
                              DropdownMenuItem(
                                value: 'Stay',
                                child: Text('Stay'),
                              ),
                              DropdownMenuItem(
                                value: 'Misc',
                                child: Text('Miscellaneous'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => category = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Amount (INR)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description / Remarks',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: submitting ? null : addCameraBill,
                            child: const Text('Bill from Camera'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: submitting ? null : addGalleryBills,
                            child: const Text('Bill from Gallery'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Selected bill photos: $totalBills',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    if (error != null) ...[
                      Text(
                        error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: submitting ? null : submit,
                        child: Text(
                          submitting
                              ? 'Submitting...'
                              : 'Submit Expense for Approval',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    final empId = profile.empId;

    if (userId == null) {
      return const Center(
        child: Text(
          'Not logged in.',
          style: TextStyle(color: Colors.red),
        ),
      );
    }

    final leaveQuery = rootDoc
        .collection('leaveRequests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    final travelQuery = rootDoc
        .collection('travelRequests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    final expensesQuery = rootDoc
        .collection('expenses')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Text(
            'My Requests',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${profile.name} (${empId})',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const TabBar(
            labelColor: Colors.indigo,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.indigo,
            tabs: [
              Tab(text: 'Leave'),
              Tab(text: 'Travel'),
              Tab(text: 'Expenses'),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: TabBarView(
              children: [
                // ---- Leave Requests tab ----
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: leaveQuery.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading leave requests:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No leave requests found.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        final status =
                            (data['status'] ?? 'Pending').toString();
                        final reason =
                            (data['reason'] ?? '').toString();
                        final fromTs = data['fromDate'] as Timestamp?;
                        final toTs = data['toDate'] as Timestamp?;
                        final createdAt =
                            data['createdAt'] as Timestamp?;
                        final managerName =
                            (data['managerName'] ?? '').toString();

                        String _fmtDate(Timestamp? t) {
                          if (t == null) return '-';
                          final d = t.toDate();
                          return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
                        }

                        String createdText = '';
                        if (createdAt != null) {
                          final d = createdAt.toDate();
                          createdText =
                              '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
                              '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
                        }

                        Color statusColor;
                        if (status.toUpperCase() == 'APPROVED') {
                          statusColor = Colors.green;
                        } else if (status.toUpperCase() == 'REJECTED') {
                          statusColor = Colors.red;
                        } else {
                          statusColor = Colors.orange;
                        }

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.beach_access,
                                        size: 18,
                                        color: Colors.indigo),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Leave Request',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3),
                                      decoration: BoxDecoration(
                                        color: statusColor
                                            .withOpacity(0.08),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'From: ${_fmtDate(fromTs)}  •  To: ${_fmtDate(toTs)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (reason.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    reason,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                if (managerName.isNotEmpty)
                                  Text(
                                    'Manager: $managerName',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                if (createdText.isNotEmpty)
                                  Text(
                                    'Requested at: $createdText',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                // ---- Travel Requests tab ----
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: travelQuery.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading travel requests:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No travel requests found.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        final status =
                            (data['status'] ?? 'Pending').toString();
                        final purpose =
                            (data['purpose'] ?? '').toString();
                        final fromLoc =
                            (data['fromLocation'] ?? '').toString();
                        final toLoc =
                            (data['toLocation'] ?? '').toString();
                        final estCost = data['estimatedCost'];
                        final createdAt =
                            data['createdAt'] as Timestamp?;

                        final fromTs = data['fromDate'] as Timestamp?;
                        final toTs = data['toDate'] as Timestamp?;

                        String _fmtDate(Timestamp? t) {
                          if (t == null) return '-';
                          final d = t.toDate();
                          return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
                        }

                        String createdText = '';
                        if (createdAt != null) {
                          final d = createdAt.toDate();
                          createdText =
                              '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
                              '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
                        }

                        Color statusColor;
                        if (status.toUpperCase() == 'APPROVED') {
                          statusColor = Colors.green;
                        } else if (status.toUpperCase() == 'REJECTED') {
                          statusColor = Colors.red;
                        } else {
                          statusColor = Colors.orange;
                        }

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.route,
                                        size: 18,
                                        color: Colors.indigo),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Travel Request',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3),
                                      decoration: BoxDecoration(
                                        color: statusColor
                                            .withOpacity(0.08),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'From: ${_fmtDate(fromTs)}  •  To: ${_fmtDate(toTs)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (fromLoc.isNotEmpty ||
                                    toLoc.isNotEmpty)
                                  Text(
                                    '${fromLoc.isNotEmpty ? "From: $fromLoc" : ""}'
                                    '${fromLoc.isNotEmpty && toLoc.isNotEmpty ? "  →  " : ""}'
                                    '${toLoc.isNotEmpty ? "To: $toLoc" : ""}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                if (purpose.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    purpose,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                                if (estCost != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Estimated Cost: $estCost',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                                if (createdText.isNotEmpty)
                                  Text(
                                    'Requested at: $createdText',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                // ---- Expenses tab ----
                Column(
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                      'My Expenses',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _openNewExpenseSheet(context),
                      child: const Text('New Expense'),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: expensesQuery.snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error loading expenses:\n${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }

                          final docs = snapshot.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return const Center(
                              child: Text(
                                'No expenses submitted yet.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final data = docs[index].data();
                              final category =
                                  (data['category'] ?? 'Misc').toString();
                              final amount = data['amount'] ?? 0;
                              final description =
                                  (data['description'] ?? '').toString();
                              final status =
                                  (data['status'] ?? 'Pending').toString();
                              final financeStatus =
                                  (data['financeStatus'] ?? 'Not Submitted')
                                      .toString();
                              final createdAt =
                                  data['createdAt'] as Timestamp?;
                              final expenseDate =
                                  data['expenseDate'] as Timestamp?;

                              String _fmtDate(Timestamp? t) {
                                if (t == null) return '-';
                                final d = t.toDate();
                                return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
                              }

                              Color statusColor;
                              if (status.toUpperCase() == 'APPROVED') {
                                statusColor = Colors.green;
                              } else if (status.toUpperCase() ==
                                  'REJECTED') {
                                statusColor = Colors.red;
                              } else {
                                statusColor = Colors.orange;
                              }

                              Color financeColor = Colors.grey;
                              if (financeStatus == 'Submitted') {
                                financeColor = Colors.blue;
                              } else if (financeStatus == 'Processed') {
                                financeColor = Colors.green;
                              }

                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 1,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.receipt_long,
                                              size: 18,
                                              color: Colors.indigo),
                                          const SizedBox(width: 6),
                                          Text(
                                            category,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '₹ $amount',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Date: ${_fmtDate(expenseDate)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      if (description.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          description,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3),
                                            decoration: BoxDecoration(
                                              color: statusColor
                                                  .withOpacity(0.08),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: statusColor,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3),
                                            decoration: BoxDecoration(
                                              color: financeColor
                                                  .withOpacity(0.08),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              financeStatus,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: financeColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Submitted: ${createdAt != null ? _fmtDate(createdAt) : '-'}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ==== Admin App (mobile summary view) ====
/// Very simple read-only view for admin/managers on mobile.

class AdminHomeScreen extends StatelessWidget {
  final AppUserProfile profile;
  const AdminHomeScreen({super.key, required this.profile});

  DocumentReference<Map<String, dynamic>> get _rootDoc {
    return FirebaseFirestore.instance
        .collection('artifacts')
        .doc(appId)
        .collection('public')
        .doc('data');
  }

  @override
  Widget build(BuildContext context) {
    final latestLocationsStream =
        _rootDoc.collection('live_locations').snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tap Log – Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: latestLocationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No live locations yet.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final name = data['userName'] ?? 'Unknown';
              final empId = data['empId'] ?? '';
              final dutyType = data['effectiveDutyType'] ?? data['dutyType'];
              final dutyOn = data['dutyOn'] == true;
              final lat = data['latitude'];
              final lng = data['longitude'];
              final timestamp = data['timestamp'] as Timestamp?;
              final dt = timestamp?.toDate();

              String timeText = 'No time';
              if (dt != null) {
                timeText =
                    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
                    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
              }

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (empId.isNotEmpty)
                        Text(
                          'Emp ID: $empId',
                          style: const TextStyle(fontSize: 12),
                        ),
                      Text(
                        'Duty: $dutyType • ${dutyOn ? 'ON' : 'OFF'}',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              dutyOn ? Colors.green.shade700 : Colors.redAccent,
                        ),
                      ),
                      if (lat != null && lng != null)
                        Text(
                          'Lat: $lat, Lng: $lng',
                          style: const TextStyle(fontSize: 11),
                        ),
                      Text(
                        'Last update: $timeText',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  trailing: Icon(
                    dutyOn ? Icons.radio_button_on : Icons.radio_button_off,
                    color: dutyOn ? Colors.green : Colors.redAccent,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
