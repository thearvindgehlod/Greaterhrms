import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:Greaterchange/checkin_checkout/checkin_checkout_views/stopwatch.dart';
import 'package:permission_handler/permission_handler.dart' as AppSettings;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:shimmer/shimmer.dart';
import 'package:geolocator/geolocator.dart';
import '../../horilla_main/home.dart';
import 'face_detection.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class CheckInCheckOutFormPage extends StatefulWidget {
  const CheckInCheckOutFormPage({super.key});

  @override
  _CheckInCheckOutFormPageState createState() =>
      _CheckInCheckOutFormPageState();
}

class _CheckInCheckOutFormPageState extends State<CheckInCheckOutFormPage>
    with WidgetsBindingObserver {
  // --- UI/State ---
  late String swipeDirection;
  late String baseUrl = '';
  late String requestsEmpMyFirstName = '';
  late String requestsEmpMyLastName = '';
  late String requestsEmpMyBadgeId = '';
  late String requestsEmpMyDepartment = '';
  late String requestsEmpProfile = '';
  late String requestsEmpMyWorkInfoId = '';
  late String requestsEmpMyShiftName = '';
  bool clockCheckBool = false;
  bool clockCheckedIn = false; // true => user is currently checked-in
  bool isLoading = true;
  bool isCheckIn = false;

  String? checkInFormattedTime = '00:00';
  String elapsedTimeString = '00:00:00';
  String? checkOutFormattedTime = '00:00';
  String? workingTime = '00:00:00';

  String? duration; // from API (string "HH:mm:ss")
  String? timeDisplay;

  final StopwatchManager stopwatchManager = StopwatchManager();
  final _controller = NotchBottomBarController(index: 1);
  Map<String, dynamic> arguments = {};
  Duration elapsedTime = Duration.zero;
  Position? userLocation;
  bool _locationSnackBarShown = false;
  late String getToken = '';

  // Local persistence keys
  static const _kIsCheckedIn = 'is_checked_in';
  static const _kCheckInTs = 'check_in_timestamp';
  static const _kLastElapsedMs = 'last_elapsed_ms';
  static const _kCheckinDisplay = 'checkin_display_str';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    swipeDirection = 'Swipe to Check-In';
    
    // Show UI immediately - don't wait for data
    setState(() {
      isLoading = false;
    });
    
    // Restore timer from local storage immediately (fast)
    _restoreTimerFromLocal();
    
    // Load data in background
    _initializeData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Handle app lifecycle — sync with server on resume
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      // First restore from local (fast)
      await _restoreTimerFromLocal();
      // Then sync with server (server is source of truth)
      await getCheckIn();
    }
  }

  // ---------- Local persistence helpers ----------
  Future<void> _setIsCheckedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsCheckedIn, value);
  }

  Future<bool> _getIsCheckedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kIsCheckedIn) ?? false;
  }

  Future<void> _saveCheckInTime(DateTime checkInTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCheckInTs, checkInTime.millisecondsSinceEpoch);
  }

  Future<void> _clearCheckInTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCheckInTs);
  }

  Future<DateTime?> _getSavedCheckInTime() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_kCheckInTs);
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts);
  }

  Future<void> _saveLastElapsed(Duration d) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastElapsedMs, d.inMilliseconds);
  }

  Future<Duration?> _getLastElapsed() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_kLastElapsedMs);
    if (ms == null) return null;
    return Duration(milliseconds: ms);
  }

  Future<void> _saveCheckinDisplay(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCheckinDisplay, value);
  }

  Future<String?> _getCheckinDisplay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCheckinDisplay);
  }

  Duration _calculateElapsedTime(DateTime checkInTime) {
    return DateTime.now().difference(checkInTime);
  }

  // Restore timer consistently on app start/resume
  // Note: This is called immediately, but server sync happens in background
  Future<void> _restoreTimerFromLocal() async {
    final isIn = await _getIsCheckedIn();
    final display = await _getCheckinDisplay();
    
    if (isIn) {
      final saved = await _getSavedCheckInTime();
      if (saved != null) {
        // Calculate elapsed from saved timestamp
        final elapsed = _calculateElapsedTime(saved);
        stopwatchManager.startStopwatch(initialTime: elapsed);
        if (mounted) {
          setState(() {
            clockCheckedIn = true;
            clockCheckBool = true;
            workingTime = formatDuration(elapsed);
            elapsedTimeString = formatDuration(elapsed);
            checkInFormattedTime = display ?? checkInFormattedTime ?? '00:00';
          });
        }
      } else {
        // No saved timestamp - reset to not checked in
        await _setIsCheckedIn(false);
        stopwatchManager.stopStopwatch();
        stopwatchManager.resetStopwatch();
        if (mounted) {
          setState(() {
            clockCheckedIn = false;
            clockCheckBool = false;
            workingTime = '00:00:00';
            elapsedTimeString = '00:00:00';
            checkInFormattedTime = '00:00';
          });
        }
      }
    } else {
      // Not checked in => reset everything
      stopwatchManager.stopStopwatch();
      stopwatchManager.resetStopwatch();
      if (mounted) {
        setState(() {
          clockCheckedIn = false;
          clockCheckBool = false;
          elapsedTimeString = '00:00:00';
          workingTime = '00:00:00';
          checkInFormattedTime = '00:00';
          checkOutFormattedTime = '00:00';
        });
      }
    }
  }

  // ---------- Init data flow ----------
  Future<void> fetchToken() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    setState(() {
      getToken = token ?? '';
    });
  }

  Future<void> _initializeData() async {
    try {
      // Load local preferences first (fast)
      final prefs = await SharedPreferences.getInstance();
      final faceDetectionEnabled = await getFaceDetection();
      await prefs.setBool("face_detection", faceDetectionEnabled);
      
      // Load token immediately
      fetchToken();

      // Initialize location in background (non-blocking)
      _initializeLocation();

      // Load all API data in parallel
      await Future.wait<void>([
        prefetchData(),
        getBaseUrl(),
        getLoginEmployeeRecord(),
      ]);

      // Sync check-in status from server (server is source of truth)
      // This will update all state including check-in time, timer, etc.
      await getCheckIn();
    } catch (e) {
      // Handle errors gracefully - UI already shown
      if (mounted) {
        // Optionally show a non-blocking error message
      }
    }
  }

  Future<void> _initializeLocation() async {
    final prefs = await SharedPreferences.getInstance();
    var geo_fencing = prefs.getBool("geo_fencing");
    if (geo_fencing != true) return;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!_locationSnackBarShown) {
          _locationSnackBarShown = true;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    'Location services are disabled. Please enable them.'),
                action: SnackBarAction(
                  label: 'Enable',
                  onPressed: () {
                    Geolocator.openLocationSettings();
                  },
                ),
              ),
            );
          }
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied.')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  const Text('Location permissions are permanently denied.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () {
                  AppSettings.openAppSettings();
                },
              ),
            ),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        userLocation = position;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    }
  }

  // ---------- API ----------
  String _extractCheckInDisplay(Map<String, dynamic> jsonBody) {
    // Try multiple field names that backend might return (server is source of truth)
    final c1 = jsonBody['clock_in_time'];
    final c2 = jsonBody['clock_in'];
    final c3 = jsonBody['check_in_time'];
    
    // Try formatted time first
    if (c1 is String && c1.trim().isNotEmpty) {
      // If already formatted (h:mm a), return as is
      if (c1.contains('AM') || c1.contains('PM') || c1.contains('am') || c1.contains('pm')) {
        return c1;
      }
      // Otherwise try to parse and format
      try {
        final dt = DateTime.parse(c1).toLocal();
        return DateFormat('h:mm a').format(dt);
      } catch (_) {
        return c1;
      }
    }
    
    // Try clock_in field
    if (c2 is String && c2.trim().isNotEmpty) {
      try {
        final dt = DateTime.parse(c2).toLocal();
        return DateFormat('h:mm a').format(dt);
      } catch (_) {
        return c2;
      }
    }
    
    // Try check_in_time field
    if (c3 is String && c3.trim().isNotEmpty) {
      try {
        final dt = DateTime.parse(c3).toLocal();
        return DateFormat('h:mm a').format(dt);
      } catch (_) {
        return c3;
      }
    }
    
    // Fallback: current time (shouldn't happen if server provides data)
    return DateFormat('h:mm a').format(DateTime.now());
  }

  Future<void> getCheckIn() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    if (typedServerUrl == null || token == null) return;

    try {
      final uri = Uri.parse('$typedServerUrl/api/attendance/checking-in');
      final response = await http.get(uri, headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Server is the source of truth - sync everything from server
        if (data['status'] == true) {
          // Server says currently checked-in - get all info from server
          final display = _extractCheckInDisplay(data);
          
          // Extract check-in timestamp from server (source of truth)
          DateTime serverCheckInTime;
          try {
            final clockInStr = data['clock_in'] ?? data['clock_in_time'] ?? '';
            if (clockInStr.toString().isNotEmpty) {
              serverCheckInTime = DateTime.parse(clockInStr.toString()).toLocal();
            } else {
              // Fallback to current time if server doesn't provide timestamp
              serverCheckInTime = DateTime.now();
            }
          } catch (_) {
            serverCheckInTime = DateTime.now();
          }
          
          // Calculate elapsed time from server check-in time
          final elapsed = DateTime.now().difference(serverCheckInTime);
          
          // Sync local state with server (server is source of truth)
          await _setIsCheckedIn(true);
          await _saveCheckInTime(serverCheckInTime);
          await _saveCheckinDisplay(display);
          
          // Start/restart timer with server's elapsed time
          stopwatchManager.startStopwatch(initialTime: elapsed);
          
          if (mounted) {
            setState(() {
              duration = data['duration'] ?? formatDuration(elapsed);
              checkInFormattedTime = display;
              clockCheckedIn = true;
              clockCheckBool = true;
              workingTime = formatDuration(elapsed);
              elapsedTimeString = formatDuration(elapsed);
            });
          }
        } else {
          // Server says not checked-in - reset everything
          await _setIsCheckedIn(false);
          await _clearCheckInTime();
          await _saveLastElapsed(Duration.zero);
          stopwatchManager.stopStopwatch();
          stopwatchManager.resetStopwatch();
          
          if (mounted) {
            setState(() {
              clockCheckedIn = false;
              clockCheckBool = false;
              duration = data['duration'] ?? '00:00:00';
              checkInFormattedTime = '00:00';
              checkOutFormattedTime = '00:00';
              workingTime = '00:00:00';
              elapsedTimeString = '00:00:00';
            });
          }
        }
      }
    } catch (e) {
      // Handle errors gracefully - don't break the app
      print('Error fetching check-in status: $e');
    }
  }

  // ---- POST helpers ----
  Future<Map<String, dynamic>?> _postCheckoutGeoOrSimple(
      {required bool geoFencing}) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    if (typedServerUrl == null || token == null) return null;
    final uri = Uri.parse('$typedServerUrl/api/attendance/clock-out/');
    final body = geoFencing
        ? jsonEncode({
            "latitude": userLocation?.latitude,
            "longitude": userLocation?.longitude,
          })
        : null;
    final response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: body,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      if (mounted)
        showActionFailedDialog(
            context, 'Check-Out Failed', getErrorMessage(response.body));
      return null;
    }
  }

  Future<Map<String, dynamic>?> _postCheckinGeoOrSimple(
      {required bool geoFencing}) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    if (typedServerUrl == null || token == null) return null;
    final uri = Uri.parse('$typedServerUrl/api/attendance/clock-in/');
    final body = geoFencing
        ? jsonEncode({
            "latitude": userLocation?.latitude,
            "longitude": userLocation?.longitude,
          })
        : null;
    final response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: body,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      if (mounted)
        showActionFailedDialog(
            context, 'Check-In Failed', getErrorMessage(response.body));
      return null;
    }
  }

  // ---------- UI BUILD ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF6B57F0),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await clearToken();
              stopwatchManager.resetStopwatch();
              await _setIsCheckedIn(false);
              await _clearCheckInTime();
              await _saveLastElapsed(Duration.zero);
              if (mounted) Navigator.pushNamed(context, '/login');
            },
          ),
        ],
      ),
      body: isLoading
          ? _buildLoadingWidget()
          : _buildCheckInCheckoutWidget(getToken),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom > 0 
                ? MediaQuery.of(context).padding.bottom - 8 
                : 8,
          ),
          child: AnimatedNotchBottomBar(
            notchBottomBarController: _controller,
            color: const Color(0xFF6B57F0),
            showLabel: true,
            notchColor: const Color(0xFF6B57F0),
            kBottomRadius: 28.0,
            kIconSize: 24.0,
            removeMargins: false,
            bottomBarWidth: MediaQuery.of(context).size.width,
            durationInMilliSeconds: 500,
        bottomBarItems: const [
          BottomBarItem(
            inActiveItem: Icon(Icons.home_filled, color: Colors.white),
            activeItem: Icon(Icons.home_filled, color: Colors.white),
          ),
          BottomBarItem(
            inActiveItem: Icon(Icons.update_outlined, color: Colors.white),
            activeItem: Icon(Icons.update_outlined, color: Colors.white),
          ),
          BottomBarItem(
            inActiveItem: Icon(Icons.person, color: Colors.white),
            activeItem: Icon(Icons.person, color: Colors.white),
          ),
        ],
            onTap: (index) async {
              switch (index) {
                case 0:
                  Future.delayed(const Duration(milliseconds: 1000), () {
                    Navigator.pushNamed(context, '/home');
                  });
                  break;
                case 1:
                  Future.delayed(const Duration(milliseconds: 1000), () {
                    Navigator.pushNamed(context, '/employee_checkin_checkout');
                  });
                  break;
                case 2:
                  Future.delayed(const Duration(milliseconds: 1000), () {
                    Navigator.pushNamed(context, '/employees_form',
                        arguments: arguments);
                  });
                  break;
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    checkInFormattedTime = timeDisplay;
    return ListView(
      children: [
        if (clockCheckBool || clockCheckedIn)
          _headerClockIn()
        else
          _headerClockOut(),
        SizedBox(height: MediaQuery.of(context).size.height * 0.02),
        _skeletonCard(),
        _buttonPlaceholder(),
      ],
    );
  }

  Widget _buildCheckInCheckoutWidget(token) {
    checkInFormattedTime = timeDisplay ?? checkInFormattedTime;
    return ListView(
      children: [
        if (clockCheckBool || clockCheckedIn)
          _headerClockIn()
        else
          _headerClockOut(),
        SizedBox(height: MediaQuery.of(context).size.height * 0.02),
        _profileCard(token),
        SizedBox(height: MediaQuery.of(context).size.height * 0.02),
        _actionButton(), // <-- button replaces swipe
      ],
    );
  }

  // ---- Header widgets ----
  Widget _headerClockIn() {
    return Container(
      color: const Color(0xFF6B57F0),
      height: MediaQuery.of(context).size.height * 0.25,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Clock In',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20)),
                Text('00:00:00', style: TextStyle(color: Colors.white)),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.05),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.access_alarm),
                      color: Colors.white,
                      iconSize: 40,
                    ),
                    StreamBuilder<int>(
                      stream: Stream.periodic(const Duration(milliseconds: 250),
                          (_) {
                        return stopwatchManager.elapsed.inMilliseconds;
                      }),
                      builder: (context, snapshot) {
                        final ms = snapshot.data ?? 0;
                        final d = Duration(milliseconds: ms);
                        final formatted =
                            '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
                        return Text(
                          formatted,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 25),
                        );
                      },
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Clocked In: ',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text(
                      checkInFormattedTime ??
                          DateFormat('h:mm a').format(DateTime.now()),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerClockOut() {
    return Container(
      color: const Color(0xFF6B57F0),
      height: MediaQuery.of(context).size.height * 0.25,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Clock Out',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20)),
                Text(elapsedTimeString,
                    style: const TextStyle(color: Colors.white)),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.05),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.access_alarm),
                      color: Colors.white,
                      iconSize: 40,
                    ),
                    Text(
                      elapsedTimeString,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 25),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- Skeletons ----
  Widget _skeletonCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 1,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[50]!),
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade400.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                              width: 90.0,
                              height: 90.0,
                              decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                    height: 20.0, color: Colors.grey[300]),
                                const SizedBox(height: 5.0),
                                Container(
                                    height: 120.0,
                                    width: 90.0,
                                    color: Colors.grey[300]),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5.0),
                      Container(
                          height: 16.0,
                          width: double.infinity,
                          color: Colors.grey[300]),
                      const SizedBox(height: 5.0),
                      Container(
                          height: 16.0,
                          width: double.infinity,
                          color: Colors.grey[300]),
                      const SizedBox(height: 5.0),
                      Container(
                          height: 16.0,
                          width: double.infinity,
                          color: Colors.grey[300]),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buttonPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ---- Profile card ----
  Widget _profileCard(String token) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.0),
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300, width: 0.0),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.shade50.withOpacity(0.3),
                spreadRadius: 7,
                blurRadius: 1,
                offset: const Offset(0, 1)),
          ],
        ),
        width: MediaQuery.of(context).size.width * 0.50,
        height: MediaQuery.of(context).size.height * 0.3,
        child: Card(
          shape: RoundedRectangleBorder(
              side: const BorderSide(color: Colors.white, width: 0.0),
              borderRadius: BorderRadius.circular(10.0)),
          color: Colors.white,
          elevation: 0.1,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 40.0,
                      height: 40.0,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey, width: 1.0)),
                      child: const Icon(Icons.person),
                    ),
                    SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$requestsEmpMyFirstName $requestsEmpMyLastName',
                            style: const TextStyle(
                                fontSize: 16.0, fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(requestsEmpMyBadgeId,
                              style: const TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.normal)),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.005),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Department'),
                      Text(requestsEmpMyDepartment),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Check-In'),
                      Text(checkInFormattedTime ?? '--'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Shift'),
                      Text(requestsEmpMyShiftName),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- BUTTON control ----
  Widget _actionButton() {
    final isIn = clockCheckedIn;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: SizedBox(
        height: 56,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: isIn ? Colors.red : Colors.green,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: Icon(isIn ? Icons.logout : Icons.login),
          label: Text(isIn ? 'Check Out' : 'Check In',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            final faceDetection = prefs.getBool("face_detection") == true;
            final geoFencing = prefs.getBool("geo_fencing") == true;

            if (geoFencing && userLocation == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Location unavailable. Cannot proceed.')),
              );
              return;
            }

            if (isIn) {
              await _handleCheckout(
                  faceDetection: faceDetection, geoFencing: geoFencing);
            } else {
              await _handleCheckin(
                  faceDetection: faceDetection, geoFencing: geoFencing);
            }
          },
        ),
      ),
    );
  }

  Future<void> _handleCheckin(
      {required bool faceDetection, required bool geoFencing}) async {
    Map<String, dynamic>? apiJson;

    // Remote check-in
    if (faceDetection) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FaceScanner(
            userLocation: userLocation,
            userDetails: arguments,
            attendanceState: 'NOT_CHECKED_IN',
          ),
        ),
      );
      if (!(result != null && result['checkedIn'] == true)) return;
      apiJson = result; // Use full result from face detection
    } else if (geoFencing) {
      apiJson = await _postCheckinGeoOrSimple(geoFencing: true);
      if (apiJson == null) return;
    } else {
      apiJson = await _postCheckinGeoOrSimple(geoFencing: false);
      if (apiJson == null) return;
    }

    // Ensure apiJson is not null
    if (apiJson == null) return;
    
    // Store in non-nullable variable for safe access
    final responseData = apiJson;
    
    // Extract check-in time from API response (server is source of truth)
    final display = _extractCheckInDisplay(responseData);
    
    // Extract server timestamp
    DateTime serverCheckInTime;
    try {
      final clockInStr = responseData['clock_in'] ?? responseData['clock_in_time'] ?? '';
      if (clockInStr.toString().isNotEmpty) {
        serverCheckInTime = DateTime.parse(clockInStr.toString()).toLocal();
      } else {
        // Fallback to current time if server doesn't provide timestamp
        serverCheckInTime = DateTime.now();
      }
    } catch (_) {
      serverCheckInTime = DateTime.now();
    }

    // Sync local state with server (server is source of truth)
    await _saveCheckinDisplay(display);
    await _setIsCheckedIn(true);
    await _saveCheckInTime(serverCheckInTime);
    await _saveLastElapsed(Duration.zero);
    
    // Reset and start timer from zero
    stopwatchManager.resetStopwatch();
    stopwatchManager.startStopwatch(initialTime: Duration.zero);

    // Extract duration before setState
    final durationValue = responseData['duration'] ?? '00:00:00';

    if (mounted) {
      setState(() {
        isCheckIn = true;
        clockCheckedIn = true;
        clockCheckBool = true;
        checkInFormattedTime = display;
        checkOutFormattedTime = '00:00';
        workingTime = '00:00:00';
        elapsedTimeString = '00:00:00';
        duration = durationValue;
      });
    }

    await _saveClockStateUIOnly(clockCheckedIn, 1, display);
    
    // Refresh check-in status from server to ensure sync
    await getCheckIn();
  }

  Future<void> _handleCheckout(
      {required bool faceDetection, required bool geoFencing}) async {
    Map<String, dynamic>? apiJson;

    if (faceDetection) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FaceScanner(
            userLocation: userLocation,
            userDetails: arguments,
            attendanceState: 'CHECKED_IN',
          ),
        ),
      );
      if (!(result != null && result['checkedOut'] == true)) return;
      apiJson = result;
    } else if (geoFencing) {
      apiJson = await _postCheckoutGeoOrSimple(geoFencing: true);
      if (apiJson == null) return;
    } else {
      apiJson = await _postCheckoutGeoOrSimple(geoFencing: false);
      if (apiJson == null) return;
    }

    // Extract checkout time from server (server is source of truth)
    final serverClockOut = apiJson?['clock_out_time'] ??
        apiJson?['clock_out'] ??
        DateFormat('h:mm a').format(DateTime.now());

    // Reset everything - server confirmed checkout
    await _setIsCheckedIn(false);
    await _clearCheckInTime();
    await _saveLastElapsed(Duration.zero); // Reset elapsed time to zero
    stopwatchManager.stopStopwatch();
    stopwatchManager.resetStopwatch(); // Reset timer completely

    if (mounted) {
      setState(() {
        isCheckIn = false;
        clockCheckedIn = false;
        clockCheckBool = false;
        workingTime = '00:00:00'; // Reset to zero
        elapsedTimeString = '00:00:00'; // Reset to zero
        checkOutFormattedTime = serverClockOut;
        checkInFormattedTime = '00:00'; // Reset check-in time
        duration = apiJson?['duration'] ?? '00:00:00';
      });
    }

    // Save UI state
    await _saveClockStateUIOnly(false, 2, serverClockOut);
    
    // Refresh check-in status from server to ensure sync
    await getCheckIn();
  }

  // ---------- Utils ----------
  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  void showActionFailedDialog(
      BuildContext context, String title, String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(errorMessage),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => HomePage()),
                );
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> prefetchData() async {
    final prefs = await SharedPreferences.getInstance();
    var geo_fencing = prefs.getBool("geo_fencing");
    if (geo_fencing == true) {
      userLocation = await fetchCurrentLocation();
    }
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var employeeId = prefs.getInt("employee_id");
    if (typedServerUrl == null || token == null || employeeId == null) return;

    final uri = Uri.parse('$typedServerUrl/api/employee/employees/$employeeId');
    final response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      arguments = {
        'employee_id': responseData['id'],
        'employee_name':
            '${responseData['employee_first_name']} ${responseData['employee_last_name']}',
        'badge_id': responseData['badge_id'],
        'email': responseData['email'],
        'phone': responseData['phone'],
        'date_of_birth': responseData['dob'],
        'gender': responseData['gender'],
        'address': responseData['address'],
        'country': responseData['country'],
        'state': responseData['state'],
        'city': responseData['city'],
        'qualification': responseData['qualification'],
        'experience': responseData['experience'],
        'marital_status': responseData['marital_status'],
        'children': responseData['children'],
        'emergency_contact': responseData['emergency_contact'],
        'emergency_contact_name': responseData['emergency_contact_name'],
        'employee_work_info_id': responseData['employee_work_info_id'],
        'employee_bank_details_id': responseData['employee_bank_details_id'],
        'employee_profile': responseData['employee_profile']
      };
    }
  }

  Future<void> _loadClockStateUIOnly() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      clockCheckedIn = prefs.getBool('clockCheckedIn') ?? false;
      checkInFormattedTime = prefs.getString('checkin') ?? '00:00';
      checkOutFormattedTime = prefs.getString('checkout') ?? '00:00';
    });
  }

  Future<void> _saveClockStateUIOnly(bool isCheckedIn, int option,
      [String? t]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('clockCheckedIn', isCheckedIn);
    if (t != null && option == 2) {
      await prefs.setString('checkout', t);
    } else if (t != null) {
      await prefs.setString('checkin', t);
    }
  }

  Future<void> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    var typedServerUrl = prefs.getString("typed_url");
    setState(() {
      baseUrl = typedServerUrl ?? '';
    });
  }

  Future<void> getLoginEmployeeRecord() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var employeeId = prefs.getInt("employee_id");
    if (typedServerUrl == null || token == null || employeeId == null) return;

    final uri = Uri.parse('$typedServerUrl/api/employee/employees/$employeeId');
    final response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      setState(() {
        requestsEmpMyFirstName = body['employee_first_name'] ?? '';
        requestsEmpMyLastName = body['employee_last_name'] ?? '';
        requestsEmpMyBadgeId = body['badge_id'] ?? '';
        requestsEmpMyDepartment = body['department_name'] ?? '';
        requestsEmpProfile = body['employee_profile'] ?? '';
        requestsEmpMyWorkInfoId = body['employee_work_info_id'] ?? '';
      });
      await getLoginEmployeeWorkInfoRecord(requestsEmpMyWorkInfoId);
    }
  }

  Future<void> getLoginEmployeeWorkInfoRecord(
      String requestsEmpMyWorkInfoId) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    if (typedServerUrl == null ||
        token == null ||
        requestsEmpMyWorkInfoId.isEmpty) return;

    final uri = Uri.parse(
        '$typedServerUrl/api/employee/employee-work-information/$requestsEmpMyWorkInfoId');
    final response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      setState(() {
        requestsEmpMyShiftName = body['shift_name'] ?? "None";
      });
    }
  }

  Future<Position?> fetchCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> getFaceDetection() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    if (typedServerUrl == null || token == null) return false;

    final uri = Uri.parse('$typedServerUrl/api/facedetection/config/');
    final response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['start'] ?? false) == true;
    }
    return false;
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  String getErrorMessage(String responseBody) {
    try {
      final Map<String, dynamic> decoded = json.decode(responseBody);
      return decoded['message'] ?? 'Unknown error occurred';
    } catch (e) {
      return 'Error parsing server response';
    }
  }
}

// ---- Dummy route wrappers ----
class Home extends StatelessWidget {
  const Home({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance
        .addPostFrameCallback((_) => Navigator.pushNamed(context, '/home'));
    return Container(
        color: Colors.white, child: const Center(child: Text('Page 1')));
  }
}

class Overview extends StatelessWidget {
  const Overview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Colors.white, child: const Center(child: Text('Page 2')));
  }
}

class User extends StatelessWidget {
  const User({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance
        .addPostFrameCallback((_) => Navigator.pushNamed(context, '/user'));
    return Container(
        color: Colors.white, child: const Center(child: Text('Page 1')));
  }
}
