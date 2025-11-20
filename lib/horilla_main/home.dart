import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:geocoding/geocoding.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../checkin_checkout/checkin_checkout_views/geofencing.dart';

const Color _baseColor = Color(0xFF6B57F0);

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late StreamSubscription subscription;
  var isDeviceConnected = false;
  final ScrollController _scrollController = ScrollController();
  final _pageController = PageController(initialPage: 0);
  final _controller = NotchBottomBarController(index: 0);
  late Map<String, dynamic> arguments = {};
  bool permissionCheck = false;
  bool isLoading = true;
  bool isFirstFetch = true;
  bool isAlertSet = false;
  bool permissionLeaveOverviewCheck = false;
  bool permissionLeaveTypeCheck = false;
  bool permissionGeoFencingMapViewCheck = false;
  bool geoFencingEnabled = false;
  bool permissionWardCheck = false;
  bool permissionLeaveAssignCheck = false;
  bool permissionLeaveRequestCheck = false;
  bool permissionMyLeaveRequestCheck = false;
  bool permissionLeaveAllocationCheck = false;
  int initialTabIndex = 0;
  int notificationsCount = 0;
  int maxCount = 5;
  String? duration;
  List<Map<String, dynamic>> notifications = [];
  Timer? _notificationTimer;
  Set<int> seenNotificationIds = {};
  int currentPage = 0;
  List<dynamic> responseDataLocation = [];
  final List<LocationWithRadius> locations = [];
  LocationWithRadius? selectedLocation;
  late final AnimatedMapController _mapController;
  bool _isPermissionLoading = true;
  bool isAuthenticated = true;

  @override
  void initState() {
    super.initState();
    _mapController = AnimatedMapController(vsync: this);
    _scrollController.addListener(_scrollListener);
    _initializePermissionsAndData();
  }

  Future _initializePermissionsAndData() async {
    await checkAllPermissions();
    await Future.wait([
      permissionGeoFencingMapView(),
      loadGeoFencingPreference(),
      permissionLeaveOverviewChecks(),
      permissionLeaveTypeChecks(),
      permissionLeaveRequestChecks(),
      permissionLeaveAssignChecks(),
      permissionWardChecks(),
      fetchNotifications(),
      unreadNotificationsCount(),
      prefetchData(),
      fetchData(),
    ]);
    setState(() {
      _isPermissionLoading = false;
      isLoading = false;
    });
  }

  Future<void> loadGeoFencingPreference() async {
    final prefs = await SharedPreferences.getInstance();
    bool? geoFencing = prefs.getBool("geo_fencing");
    setState(() {
      geoFencingEnabled = geoFencing ?? false;
    });
  }

  Future<void> permissionLeaveOverviewChecks() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/leave/check-perm/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    setState(() {
      if (response.statusCode == 200) {
        permissionLeaveOverviewCheck = true;
        permissionMyLeaveRequestCheck = true;
        permissionLeaveAllocationCheck = true;
      } else {
        permissionMyLeaveRequestCheck = true;
        permissionLeaveAllocationCheck = true;
      }
    });
  }

  Future<void> permissionLeaveTypeChecks() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/leave/check-type/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    setState(() {
      if (response.statusCode == 200) {
        permissionLeaveTypeCheck = true;
        permissionMyLeaveRequestCheck = true;
        permissionLeaveAllocationCheck = true;
      } else {
        permissionMyLeaveRequestCheck = true;
        permissionLeaveAllocationCheck = true;
      }
    });
  }

  Future<void> permissionGeoFencingMapView() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/geofencing/setup-check/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    setState(() {
      permissionGeoFencingMapViewCheck = response.statusCode == 200;
    });
  }

  Future<void> permissionLeaveRequestChecks() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/leave/check-request/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    setState(() {
      if (response.statusCode == 200) {
        permissionLeaveRequestCheck = true;
        permissionMyLeaveRequestCheck = true;
        permissionLeaveAllocationCheck = true;
      } else {
        permissionMyLeaveRequestCheck = true;
        permissionLeaveAllocationCheck = true;
      }
    });
  }

  Future<void> permissionLeaveAssignChecks() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/leave/check-assign/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    setState(() {
      if (response.statusCode == 200) {
        permissionLeaveAssignCheck = true;
        permissionMyLeaveRequestCheck = true;
        permissionLeaveAllocationCheck = true;
      } else {
        permissionMyLeaveRequestCheck = true;
        permissionLeaveAllocationCheck = true;
      }
    });
  }

  void getConnectivity() {
    subscription = InternetConnectionChecker().onStatusChange.listen((status) {
      setState(() {
        isDeviceConnected = status == InternetConnectionStatus.connected;
        if (!isDeviceConnected && !isAlertSet) {
          showSnackBar();
          isAlertSet = true;
        } else if (isDeviceConnected && isAlertSet) {
          isAlertSet = false;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      });
    });
  }

  final List<Widget> bottomBarPages = [
    const Home(),
    const Overview(),
    const User(),
  ];

  void _scrollListener() {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange) {
      currentPage++;
      fetchNotifications();
    }
  }

  Future<void> _refreshHome() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
    });

    await Future.wait([
      permissionGeoFencingMapView(),
      loadGeoFencingPreference(),
      permissionLeaveOverviewChecks(),
      permissionLeaveTypeChecks(),
      permissionLeaveRequestChecks(),
      permissionLeaveAssignChecks(),
      permissionWardChecks(),
      prefetchData(),
      fetchData(),
      fetchNotifications(),
      unreadNotificationsCount(),
    ]);

    if (mounted) {
      setState(() {
        isLoading = false;
        _isPermissionLoading = false;
      });
    }
  }

  Future<void> fetchData() async {
    await permissionWardChecks();
    setState(() {});
  }

  void permissionChecks() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri =
        Uri.parse('$typedServerUrl/api/attendance/permission-check/attendance');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    setState(() {
      permissionCheck = response.statusCode == 200;
    });
  }

  Future<void> permissionWardChecks() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/ward/check-ward/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    setState(() {
      permissionWardCheck = response.statusCode == 200;
    });
  }

  Future<void> prefetchData() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var employeeId = prefs.getInt("employee_id");
    var uri = Uri.parse('$typedServerUrl/api/employee/employees/$employeeId');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      setState(() {
        arguments = {
          'employee_id': responseData['id'] ?? '',
          'employee_name': (responseData['employee_first_name'] ?? '') +
              ' ' +
              (responseData['employee_last_name'] ?? ''),
          'badge_id': responseData['badge_id'] ?? '',
          'email': responseData['email'] ?? '',
          'phone': responseData['phone'] ?? '',
          'date_of_birth': responseData['dob'] ?? '',
          'gender': responseData['gender'] ?? '',
          'address': responseData['address'] ?? '',
          'country': responseData['country'] ?? '',
          'state': responseData['state'] ?? '',
          'city': responseData['city'] ?? '',
          'qualification': responseData['qualification'] ?? '',
          'experience': responseData['experience'] ?? '',
          'marital_status': responseData['marital_status'] ?? '',
          'children': responseData['children'] ?? '',
          'emergency_contact': responseData['emergency_contact'] ?? '',
          'emergency_contact_name':
              responseData['emergency_contact_name'] ?? '',
          'employee_work_info_id': responseData['employee_work_info_id'] ?? '',
          'employee_bank_details_id':
              responseData['employee_bank_details_id'] ?? '',
          'employee_profile': responseData['employee_profile'] ?? '',
          'job_position_name': responseData['job_position_name'] ?? ''
        };
      });
    }
  }

  Future<void> fetchNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");

    List<Map<String, dynamic>> allNotifications = [];
    int page = 1;
    bool hasMore = true;

    while (hasMore) {
      var uri = Uri.parse(
          '$typedServerUrl/api/notifications/notifications/list/unread?page=$page');

      var response = await http.get(uri, headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      });

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        var results = responseData['results'] as List;

        if (results.isEmpty) break;

        // Filter out deleted notifications
        List<Map<String, dynamic>> fetched = results
            .where((n) => n['deleted'] == false)
            .cast<Map<String, dynamic>>()
            .toList();

        allNotifications.addAll(fetched);

        // Check if there's a next page
        if (responseData['next'] == null) {
          hasMore = false;
        } else {
          page++;
        }
      } else {
        print('Failed to fetch notifications: ${response.statusCode}');
        hasMore = false;
      }
    }

    // Deduplicate notifications by converting to JSON strings
    Set<String> uniqueMapStrings = allNotifications
        .map((notification) => jsonEncode(notification))
        .toSet();

    setState(() {
      notifications = uniqueMapStrings
          .map((jsonString) => jsonDecode(jsonString))
          .cast<Map<String, dynamic>>()
          .toList();
      notificationsCount = notifications.length;
      isLoading = false;
    });
  }

  Future<void> unreadNotificationsCount() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse(
        '$typedServerUrl/api/notifications/notifications/list/unread');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });

    if (response.statusCode == 200) {
      setState(() {
        notificationsCount = jsonDecode(response.body)['count'];
        isLoading = false;
      });
    }
  }

  Future<void> markReadNotification(int notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse(
        '$typedServerUrl/api/notifications/notifications/$notificationId/');
    var response = await http.post(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      setState(() {
        notifications.removeWhere((item) => item['id'] == notificationId);
        unreadNotificationsCount();
        fetchNotifications();
      });
    }
  }

  Future<void> markAllReadNotification() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri =
        Uri.parse('$typedServerUrl/api/notifications/notifications/bulk-read/');
    var response = await http.post(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      setState(() {
        notifications.clear();
        unreadNotificationsCount();
        fetchNotifications();
      });
    }
  }

  Future checkAllPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");

    Future<bool> _getPerm(String endpoint) async {
      try {
        var uri = Uri.parse('$typedServerUrl$endpoint');
        var res = await http.get(uri, headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        });
        return res.statusCode == 200;
      } catch (e) {
        print("Permission check failed for $endpoint: $e");
        return false;
      }
    }

    bool overview =
        await _getPerm("/api/attendance/permission-check/attendance");
    bool att = true;
    bool attReq = true;
    bool hourAcc = true;

    await prefs.setBool("perm_overview", overview);
    await prefs.setBool("perm_attendance", att);
    await prefs.setBool("perm_attendance_request", attReq);
    await prefs.setBool("perm_hour_account", hourAcc);

    print("✅ Permissions saved in SharedPreferences");
  }

  Future<void> clearAllUnreadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse(
        '$typedServerUrl/api/notifications/notifications/bulk-delete-unread/');
    var response = await http.delete(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      setState(() {
        notifications.clear();
        unreadNotificationsCount();
        fetchNotifications();
      });
    }
  }

  Future<void> clearToken(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    String? typedServerUrl = prefs.getString("typed_url");
    await prefs.remove('token');
    isAuthenticated = false;
    _notificationTimer?.cancel();
    _notificationTimer = null;

    Navigator.pushNamed(context, '/login', arguments: typedServerUrl);
  }

  Future<void> enableFaceDetection() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/facedetection/config/');
    var response = await http.put(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        'start': true,
      }),
    );
    print('Face Detection Enable Response: ${response.statusCode}');
    print(response.body);
  }

  Future<void> disableFaceDetection() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/facedetection/config/');
    var response = await http.put(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        'start': false,
      }),
    );
    print('Face Detection Disable Response: ${response.statusCode}');
  }

  Future<bool> getFaceDetection() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/facedetection/config/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      bool isEnabled = data['start'] ?? false;
      return isEnabled;
    } else {
      print('Failed to get face detection');
      return false;
    }
  }

  Future<bool?> getGeoFence() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/geofencing/setup/');

    try {
      var response = await http.get(uri, headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      });

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        var data = jsonDecode(response.body);
        bool isEnabled = data['start'] ?? false;
        return isEnabled;
      } else if (response.statusCode == 404) {
        print('Geofencing not configured yet');
        return null;
      } else {
        print('Failed to get geofencing: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error getting geofencing: $e');
      return false;
    }
  }

  Future<void> enableGeoFenceLocation() async {
    await getGeoFenceLocation();
    if (responseDataLocation.isEmpty) return;
    var locationId = responseDataLocation[0]['id'];
    final prefs = await SharedPreferences.getInstance();
    var companyId = prefs.getInt("company_id");
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/geofencing/setup/$locationId/');
    var response = await http.put(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        'latitude': selectedLocation?.coordinates.latitude,
        'longitude': selectedLocation?.coordinates.longitude,
        'radius_in_meters': selectedLocation?.radius,
        'start': true,
        'company_id': companyId
      }),
    );
    print('GeoFence Enable Response: ${response.statusCode}');
  }

  Future<void> disableGeoFenceLocation() async {
    await getGeoFenceLocation();
    if (responseDataLocation.isEmpty) return;

    var locationId = responseDataLocation[0]['id'];
    final prefs = await SharedPreferences.getInstance();
    var companyId = prefs.getInt("company_id");
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/geofencing/setup/$locationId/');
    var response = await http.put(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        'latitude': selectedLocation?.coordinates.latitude,
        'longitude': selectedLocation?.coordinates.longitude,
        'radius_in_meters': selectedLocation?.radius,
        'start': false,
        'company_id': companyId
      }),
    );
    print('GeoFence Disable Response: ${response.statusCode}');
  }

  Future<void> getGeoFenceLocation() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/geofencing/setup/');

    try {
      var response = await http.get(uri, headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.isNotEmpty) {
          final lat = data['latitude'];
          final lng = data['longitude'];
          final rad = data['radius_in_meters'];

          if (lat != null && lng != null && rad != null) {
            final locationName = await _getLocationName(lat, lng);
            final location = LocationWithRadius(
              LatLng(lat, lng),
              locationName,
              (rad).toDouble(),
            );

            setState(() {
              responseDataLocation = [data];
              locations.clear();
              locations.add(location);
              selectedLocation = location;
              _mapController.animateTo(dest: location.coordinates, zoom: 12.0);
            });
            print('responseDataLocation: $responseDataLocation');
          }
        }
      } else {
        print('Failed to load geofence data: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching geofence data: $e");
    }
  }

  Future<String> _getLocationName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String name = "${place.locality ?? ''}, ${place.country ?? ''}".trim();
        return name.isEmpty ? "Unknown Location" : name;
      }
      return "Unknown Location";
    } catch (e) {
      print('Error getting location name: $e');
      return "Unknown Location";
    }
  }

  Future<void> showSavedAnimation() async {
    String jsonContent = '''
{
  "imagePath": "Assets/gif22.gif"
}
''';
    Map<String, dynamic> jsonData = json.decode(jsonContent);
    String imagePath = jsonData['imagePath'];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.3,
            width: MediaQuery.of(context).size.width * 0.85,
            child: SingleChildScrollView(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(imagePath,
                        width: 180, height: 180, fit: BoxFit.cover),
                    const SizedBox(height: 16),
                    const Text(
                      "Values Marked Successfully",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    Future.delayed(const Duration(seconds: 3), () async {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(),
        ),
      );
    });
  }

  void _showUnreadNotifications(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Stack(
              children: [
                AlertDialog(
                  backgroundColor: Colors.white,
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Notifications",
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.05,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          Navigator.of(context).pop(true);
                        },
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              await markAllReadNotification();
                              Navigator.pop(context);
                              _showUnreadNotifications(context);
                            },
                            icon: Icon(Icons.done_all,
                                color: _baseColor,
                                size:
                                    MediaQuery.of(context).size.width * 0.0357),
                            label: Text(
                              'Mark as Read',
                              style: TextStyle(
                                  color: _baseColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: MediaQuery.of(context).size.width *
                                      0.0368),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await clearAllUnreadNotifications();
                              Navigator.pop(context);
                              _showUnreadNotifications(context);
                            },
                            icon: Icon(Icons.clear,
                                color: _baseColor,
                                size:
                                    MediaQuery.of(context).size.width * 0.0357),
                            label: Text(
                              'Clear all',
                              style: TextStyle(
                                  color: _baseColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: MediaQuery.of(context).size.width *
                                      0.0368),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16.0),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.8,
                        height: MediaQuery.of(context).size.height * 0.3,
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.8,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.0357),
                          child: Center(
                            child: isLoading
                                ? Shimmer.fromColors(
                                    baseColor: Colors.grey[300]!,
                                    highlightColor: Colors.grey[100]!,
                                    child: ListView.builder(
                                      itemCount: 3,
                                      itemBuilder: (context, index) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8.0),
                                        child: Container(
                                          width: double.infinity,
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.0616,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  )
                                : notifications.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.notifications,
                                              color: Colors.black,
                                              size: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.2054,
                                            ),
                                            SizedBox(
                                                height: MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    0.0205),
                                            Text(
                                              "There are no notification records to display",
                                              style: TextStyle(
                                                fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.0268,
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Column(
                                        children: [
                                          Expanded(
                                            child: ListView.builder(
                                              itemCount: notifications.length,
                                              itemBuilder: (context, index) {
                                                final record =
                                                    notifications[index];
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.all(4.0),
                                                  child: Column(
                                                    children: [
                                                      if (record['verb'] !=
                                                          null)
                                                        buildListItem(context,
                                                            record, index),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                          ),
                        ),
                      )
                    ],
                  ),
                  actions: <Widget>[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/notifications_list');
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.0134,
                              vertical:
                                  MediaQuery.of(context).size.width * 0.0134),
                          backgroundColor: _baseColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'View all notifications',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize:
                                  MediaQuery.of(context).size.width * 0.0335),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget buildListItem(
      BuildContext context, Map<String, dynamic> record, int index) {
    final timestamp = DateTime.parse(record['timestamp']);
    final timeAgo = timeago.format(timestamp);
    final user = arguments['employee_name'];
    return Padding(
      padding: const EdgeInsets.all(0),
      child: GestureDetector(
        onTap: () async {
          setState(() {});
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.red.shade100),
            borderRadius: BorderRadius.circular(8.0),
            color: Colors.red.shade100,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
                vertical: MediaQuery.of(context).size.height * 0.0082),
            child: Container(
              color: Colors.red.shade100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 6.0),
                    child: Container(
                      margin: EdgeInsets.only(
                          right: MediaQuery.of(context).size.width * 0.0357),
                      width: MediaQuery.of(context).size.width * 0.0223,
                      height: MediaQuery.of(context).size.width * 0.0223,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.shade500,
                        border: Border.all(
                            color: Colors.grey,
                            width: MediaQuery.of(context).size.width * 0.0022),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record['verb'],
                          style: TextStyle(
                              fontSize:
                                  MediaQuery.of(context).size.width * 0.0313,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          '$timeAgo by User $user',
                          style: TextStyle(
                              fontSize:
                                  MediaQuery.of(context).size.width * 0.0268),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GestureDetector(
                      onTap: () async {
                        var notificationId = record['id'];
                        await markReadNotification(notificationId);
                        Navigator.pop(context);
                        _showUnreadNotifications(context);
                      },
                      child: Icon(
                        Icons.check,
                        color: Colors.red.shade500,
                        size: 20.0,
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        forceMaterialTransparency: true,
        backgroundColor: Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _baseColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'Assets/horilla-logo.png',
                width: 20,
                height: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Greaterchange',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          if (_isPermissionLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else ...[
            Visibility(
              visible: permissionGeoFencingMapViewCheck,
              child: IconButton(
                icon: Icon(
                  Icons.settings,
                  color: _baseColor,
                ),
                onPressed: () async {
                  var faceDetection = await getFaceDetection();
                  var geoFencingResponse = await getGeoFence();
                  final prefs = await SharedPreferences.getInstance();

                  bool geoFencingSetupExists = geoFencingResponse != null;
                  bool geoFencingEnabled =
                      geoFencingSetupExists ? geoFencingResponse : false;

                  prefs.remove('face_detection');
                  prefs.setBool("face_detection", faceDetection);
                  prefs.remove('geo_fencing');
                  prefs.setBool("geo_fencing", geoFencingEnabled);

                  showDialog(
                    context: context,
                    builder: (context) {
                      bool tempFaceDetection = faceDetection;
                      bool tempGeofencing = geoFencingEnabled;
                      bool isGeofencingSetup = geoFencingSetupExists;

                      return StatefulBuilder(
                        builder: (context, setState) {
                          return AlertDialog(
                            title: const Text('Settings'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SwitchListTile(
                                  title: const Text('Face Detection'),
                                  value: tempFaceDetection,
                                  onChanged: (val) {
                                    setState(() {
                                      tempFaceDetection = val;
                                    });
                                    // Immediately apply face detection changes
                                    if (val) {
                                      enableFaceDetection();
                                    } else {
                                      disableFaceDetection();
                                    }
                                  },
                                ),
                                SwitchListTile(
                                  title: const Text('Geofencing'),
                                  value: tempGeofencing,
                                  onChanged: (val) async {
                                    setState(() {
                                      tempGeofencing = val;
                                    });
                                    print('wswsws');
                                    print(isGeofencingSetup);

                                    if (!isGeofencingSetup && val) {
                                      Navigator.pop(
                                          context); // Close settings dialog
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const MapScreen(),
                                        ),
                                      );
                                      return;
                                    }

                                    if (val) {
                                      await enableGeoFenceLocation();
                                    } else {
                                      await disableGeoFenceLocation();
                                    }
                                  },
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setBool(
                                      "face_detection", tempFaceDetection);
                                  await prefs.setBool(
                                      "geo_fencing", tempGeofencing);

                                  setState(() {
                                    geoFencingEnabled = tempGeofencing;
                                  });

                                  Navigator.pop(context);
                                  await showSavedAnimation();
                                },
                                child: const Text('OK'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Visibility(
              visible: permissionGeoFencingMapViewCheck && geoFencingEnabled,
              child: IconButton(
                icon: Icon(
                  Icons.location_on,
                  color: _baseColor,
                ),
                onPressed: () async {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MapScreen(),
                    ),
                  );
                },
              ),
            ),
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications,
                    color: _baseColor,
                  ),
                  onPressed: () {
                    markAllReadNotification();
                    Navigator.pushNamed(context, '/notifications_list');
                    setState(() {
                      fetchNotifications();
                      unreadNotificationsCount();
                    });
                  },
                ),
                if (notificationsCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width * 0.012,
                        vertical: MediaQuery.of(context).size.width * 0.004,
                      ),
                      decoration: const BoxDecoration(
                        color: _baseColor,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width * 0.032,
                        minHeight: MediaQuery.of(context).size.height * 0.016,
                      ),
                      child: Center(
                        child: Text(
                          '$notificationsCount',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: MediaQuery.of(context).size.width * 0.018,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: Icon(
                Icons.logout,
                color: _baseColor,
              ),
              onPressed: () async {
                await clearToken(context);
              },
            )
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshHome,
        color: _baseColor,
        edgeOffset: 16,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: (_isPermissionLoading || isLoading)
              ? _buildLoadingState(context)
              : _buildHomeContent(context),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: (bottomBarPages.length <= maxCount)
          ? AnimatedNotchBottomBar(
              notchBottomBarController: _controller,
              color: _baseColor,
              showLabel: true,
              notchColor: _baseColor,
              kBottomRadius: 28.0,
              kIconSize: 24.0,
              removeMargins: false,
              bottomBarWidth: MediaQuery.of(context).size.width * 1,
              durationInMilliSeconds: 500,
              bottomBarItems: const [
                BottomBarItem(
                  inActiveItem: Icon(
                    Icons.home_filled,
                    color: Colors.white,
                  ),
                  activeItem: Icon(
                    Icons.home_filled,
                    color: Colors.white,
                  ),
                ),
                BottomBarItem(
                  inActiveItem: Icon(
                    Icons.update_outlined,
                    color: Colors.white,
                  ),
                  activeItem: Icon(
                    Icons.update_outlined,
                    color: Colors.white,
                  ),
                ),
                BottomBarItem(
                  inActiveItem: Icon(
                    Icons.person,
                    color: Colors.white,
                  ),
                  activeItem: Icon(
                    Icons.person,
                    color: Colors.white,
                  ),
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
                      Navigator.pushNamed(
                          context, '/employee_checkin_checkout');
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
            )
          : null,
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return ListView.builder(
      key: const ValueKey('loading_state'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      itemCount: 4,
      itemBuilder: (_, __) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHomeContent(BuildContext context) {
    final modules = _moduleTiles(context);
    final quickActions = _quickActions(context);

    final bottomInset = MediaQuery.of(context).padding.bottom + 80;

    return ListView(
      key: const ValueKey('home_content'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 20, 16, bottomInset),
      children: [
        _buildHeroHeader(context),
        if (quickActions.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionHeader(
            title: 'Quick actions',
            subtitle: 'Do more with fewer taps',
            icon: Icons.flash_on,
          ),
          const SizedBox(height: 10),
          _buildQuickActionChips(quickActions),
        ],
        if (modules.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionHeader(
            title: 'Modules',
            subtitle: 'Your day-to-day toolkit',
            icon: Icons.auto_awesome,
          ),
          const SizedBox(height: 10),
          _buildModuleGrid(modules),
        ],
      ],
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    final String employeeName =
        (arguments['employee_name'] as String?)?.trim().isNotEmpty == true
            ? arguments['employee_name']
            : 'there';
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_baseColor, Color(0xFF8F75FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _baseColor.withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back,',
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            employeeName,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildHeroMetric(
                label: 'Pending Alerts',
                value: notificationsCount.toString(),
              ),
              const SizedBox(width: 16),
              _buildHeroMetric(
                label: 'Geo Fencing',
                value: geoFencingEnabled ? 'On' : 'Off',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric({required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    IconData? icon,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _baseColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: _baseColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionChips(List<_QuickAction> actions) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: actions
          .map(
            (action) => ActionChip(
              label: Text(action.label),
              avatar: Icon(
                action.icon,
                size: 18,
                color: _baseColor,
              ),
              backgroundColor: _baseColor.withOpacity(0.08),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF2A2A2A),
              ),
              onPressed: action.onTap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: _baseColor.withOpacity(0.2),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildModuleGrid(List<_ModuleTile> modules) {
    return GridView.builder(
      itemCount: modules.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) => _ModuleCard(
        tile: modules[index],
      ),
    );
  }

  Widget _buildNotificationsPreview(BuildContext context) {
    if (notifications.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: const [
            Icon(Icons.inbox_outlined, color: Colors.grey),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'You are all caught up. Enjoy your day!',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    final latestNotifications = notifications.take(3).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var notification in latestNotifications) ...[
            ListTile(
              onTap: () {
                Navigator.pushNamed(context, '/notifications_list');
              },
              leading: CircleAvatar(
                backgroundColor: _baseColor.withOpacity(0.15),
                child: Icon(
                  Icons.notifications_active,
                  color: _baseColor,
                ),
              ),
              title: Text(
                notification['verb'] ?? 'Notification',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                timeago.format(DateTime.parse(notification['timestamp'])),
              ),
            ),
            if (notification != latestNotifications.last)
              const Divider(height: 0),
          ],
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/notifications_list');
            },
            child: const Text('View all notifications'),
          ),
        ],
      ),
    );
  }

  List<_ModuleTile> _moduleTiles(BuildContext context) {
    return [
      _ModuleTile(
        title: 'Employees',
        subtitle: 'Manage workforce records',
        icon: Icons.people,
        accentColor: _baseColor,
        onTap: () {
          Navigator.pushNamed(
            context,
            '/employees_list',
            arguments: permissionCheck,
          );
        },
      ),
      _ModuleTile(
        title: 'Attendance',
        subtitle: 'Oversee daily presence',
        icon: Icons.fingerprint,
        accentColor: _baseColor,
        onTap: () {
          if (permissionCheck) {
            Navigator.pushNamed(
              context,
              '/attendance_overview',
              arguments: permissionCheck,
            );
          } else {
            Navigator.pushNamed(
              context,
              '/employee_hour_account',
              arguments: permissionCheck,
            );
          }
        },
      ),
      _ModuleTile(
        title: 'Leaves',
        subtitle: 'Approve or request time off',
        icon: Icons.calendar_month_outlined,
        accentColor: _baseColor,
        onTap: () {
          if (permissionLeaveOverviewCheck) {
            Navigator.pushNamed(context, '/leave_overview');
          } else {
            Navigator.pushNamed(context, '/my_leave_request');
          }
        },
      ),
    ];
  }

  List<_QuickAction> _quickActions(BuildContext context) {
    return [
      _QuickAction(
        label: permissionCheck ? 'Attendance overview' : 'Hour account',
        icon: Icons.schedule,
        onTap: () {
          if (permissionCheck) {
            Navigator.pushNamed(
              context,
              '/attendance_overview',
              arguments: permissionCheck,
            );
          } else {
            Navigator.pushNamed(
              context,
              '/employee_hour_account',
              arguments: permissionCheck,
            );
          }
        },
      ),
      _QuickAction(
        label: 'Leave request',
        icon: Icons.airplane_ticket,
        onTap: () {
          Navigator.pushNamed(context, '/my_leave_request');
        },
      ),
    ];
  }

  void showSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _baseColor,
        content: const Text('Please check your internet connectivity',
            style: TextStyle(color: Colors.white)),
        action: SnackBarAction(
          backgroundColor: _baseColor,
          label: 'close',
          textColor: Colors.white,
          onPressed: () async {
            setState(() => isAlertSet = false);
            isDeviceConnected = await InternetConnectionChecker().hasConnection;
            if (!isDeviceConnected && !isAlertSet) {
              showSnackBar();
              setState(() => isAlertSet = true);
            }
          },
        ),
        duration: const Duration(hours: 1),
      ),
    );
  }
}

class _ModuleTile {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isVisible;
  final Color accentColor;

  _ModuleTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isVisible = true,
    this.accentColor = _baseColor,
  });
}

class _QuickAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class _ModuleCard extends StatelessWidget {
  final _ModuleTile tile;

  const _ModuleCard({Key? key, required this.tile}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: tile.onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: tile.accentColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tile.accentColor.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: tile.accentColor.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tile.accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  tile.icon,
                  color: tile.accentColor,
                ),
              ),
              const Spacer(),
              Text(
                tile.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                tile.subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[700],
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Home extends StatelessWidget {
  const Home({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushNamed(context, '/home');
    });
    return Container(
      color: Colors.white,
      child: const Center(child: Text('Page 1')),
    );
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushNamed(context, '/user');
    });
    return Container(
      color: Colors.white,
      child: const Center(child: Text('Page 1')),
    );
  }
}
