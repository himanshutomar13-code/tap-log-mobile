import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/attendance_provider.dart';
import 'models/duty_state.dart';

const String appId = '2';
const String companyName = 'Alert Intelligence Services Ltd';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: TapLogApp()));
}

class TapLogApp extends ConsumerWidget {
  const TapLogApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Tap Log',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: authState.when(
        data: (user) {
          if (user != null) {
            return const HomeScreen();
          } else {
            return const AuthScreen();
          }
        },
        loading: () => const SplashScreen(),
        error: (error, stackTrace) {
          return Scaffold(
            body: Center(
              child: Text('Error: $error'),
            ),
          );
        },
      ),
    );
  }
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final TextEditingController _employeeIdController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _employeeIdController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final employeeId = _employeeIdController.text.trim();
    if (employeeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Employee ID')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authProvider.notifier).login(employeeId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Tap Log Field App',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                companyName,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _employeeIdController,
                decoration: InputDecoration(
                  labelText: 'Employee ID',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.badge),
                ),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _restoreDutyState();
    _ensureDailyTravelRequestIfNeeded();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _restoreDutyState() async {
    final prefs = await SharedPreferences.getInstance();
    final user = ref.read(authProvider).value;

    if (user != null && mounted) {
      final lastDutyState = prefs.getString('dutyState_${user.id}');
      if (lastDutyState == 'on_duty') {
        ref.read(attendanceProvider.notifier).startDuty();
        // Restore travel mode for all employees
        final isTravelMode = prefs.getBool('travelMode_${user.id}') ?? false;
        if (isTravelMode && mounted) {
          ref.read(attendanceProvider.notifier).updateTravelMode(true);
        }
      }
    }
  }

  void _ensureDailyTravelRequestIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final user = ref.read(authProvider).value;

    if (user != null) {
      final lastTravelRequestDate =
          prefs.getString('lastTravelRequestDate_${user.id}');
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Create a daily travel request for an employee
      if (lastTravelRequestDate != today) {
        // Logic to create a new travel request
        prefs.setString('lastTravelRequestDate_${user.id}', today);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final attendanceState = ref.watch(attendanceProvider);
    final now = DateTime.now();
    final currentDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    if (user == null) {
      return const AuthScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tap Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _currentPage = index);
        },
        children: [
          _buildAttendanceSection(user, attendanceState, currentDate),
          _buildTravelSection(user),
          _buildSettingsSection(user),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentPage,
        onTap: (index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Travel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSection(
      dynamic user, DutyState attendanceState, String currentDate) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Date and Time',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentDate,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Duty Status',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    attendanceState.isDutyOn ? 'On Duty' : 'Off Duty',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: attendanceState.isDutyOn
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (attendanceState.isDutyOn) {
                          ref.read(attendanceProvider.notifier).stopDuty();
                        } else {
                          ref.read(attendanceProvider.notifier).startDuty();
                        }
                      },
                      child: Text(
                        attendanceState.isDutyOn ? 'Stop Duty' : 'Start Duty',
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

  Widget _buildTravelSection(dynamic user) {
    final attendanceState = ref.watch(attendanceProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Track My Travel',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Enable Travel Mode'),
                    value: attendanceState.isTravelMode,
                    onChanged: (value) {
                      ref
                          .read(attendanceProvider.notifier)
                          .updateTravelMode(value);
                    },
                  ),
                  if (attendanceState.isTravelMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        'Travel mode is active. Your location is being tracked.',
                        style: Theme.of(context).textTheme.bodySmall,
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

  Widget _buildSettingsSection(dynamic user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 16),
                  Text('Employee ID: ${user.id}'),
                  const SizedBox(height: 8),
                  Text('Name: ${user.name}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                ref.read(authProvider.notifier).logout();
              },
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
