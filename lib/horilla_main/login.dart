import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late StreamSubscription subscription;
  bool _passwordVisible = false;
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  double horizontalMargin = 0.0;
  Timer? _notificationTimer;

  final String fixedServerAddress = "https://greaterchange.ai";

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      double screenWidth = MediaQuery.of(context).size.width;
      setState(() {
        horizontalMargin = screenWidth * 0.1;
      });
    });
  }

  void _startNotificationTimer() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (isAuthenticated) {
        fetchNotifications();
        unreadNotificationsCount();
      } else {
        timer.cancel();
        _notificationTimer = null;
      }
    });
  }

  Future<void> _login() async {
    String username = usernameController.text.trim();
    String password = passwordController.text.trim();
    String url = '$fixedServerAddress/api/auth/login/';

    try {
      http.Response response = await http.post(
        Uri.parse(url),
        body: {'username': username, 'password': password},
      ).timeout(Duration(seconds: 3));

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);

        var token = responseBody['access'] ?? '';
        var employeeId = responseBody['employee']?['id'] ?? 0;
        var companyId = responseBody['company_id'] ?? 0;
        bool face_detection = responseBody['face_detection'] ?? false;
        bool geo_fencing = responseBody['geo_fencing'] ?? false;
        var face_detection_image =
            responseBody['face_detection_image']?.toString() ?? '';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", token);
        await prefs.setString("typed_url", fixedServerAddress);
        await prefs.setString("face_detection_image", face_detection_image);
        await prefs.setBool("face_detection", face_detection);
        await prefs.setBool("geo_fencing", geo_fencing);
        await prefs.setInt("employee_id", employeeId);
        await prefs.setInt("company_id", companyId);

        isAuthenticated = true;
        _startNotificationTimer();
        prefetchData();

        Navigator.pushReplacementNamed(context, '/employee_checkin_checkout');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid email or password'),
            backgroundColor: const Color(0xFF6B57F0),
          ),
        );
      }
    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection timeout'),
          backgroundColor: const Color(0xFF6B57F0),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to reach server'),
          backgroundColor: const Color(0xFF6B57F0),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Container(
          width: double.infinity,
          height: double.infinity,

          /// 🔥 Background Image Added Here
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("Assets/bg.png"), // <-- your local image
              fit: BoxFit.fill,
            ),
          ),

          child: Stack(
            children: [
              SingleChildScrollView(
                physics: ClampingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).size.height * 0.15,
                    left: horizontalMargin,
                    right: horizontalMargin,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      /// LOGO BOX
                      ClipOval(
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(1, 5, 15, 5),
                          child: Image.asset(
                            'Assets/horilla-logo.png',
                            height: MediaQuery.of(context).size.height * 0.11,
                            width: MediaQuery.of(context).size.height * 0.11,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      SizedBox(height: 30),

                      /// LOGIN CARD
                      Container(
                        padding: const EdgeInsets.all(15.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white54),
                          borderRadius: BorderRadius.circular(20.0),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: <Widget>[
                            const Text(
                              'Sign In',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.02),
                            _buildTextFormField(
                              'Email',
                              usernameController,
                              false,
                            ),
                            SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.02),
                            _buildTextFormField(
                              'Password',
                              passwordController,
                              true,
                              _passwordVisible,
                              () {
                                setState(() {
                                  _passwordVisible = !_passwordVisible;
                                });
                              },
                            ),
                            SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.04),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _login,
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: const Color(0xFF6B57F0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10.0),
                                  child: Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField(
    String label,
    TextEditingController controller,
    bool isPassword, [
    bool? passwordVisible,
    VoidCallback? togglePasswordVisibility,
  ]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 5),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? !(passwordVisible ?? false) : false,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderSide: BorderSide(width: 1),
              borderRadius: BorderRadius.circular(8.0),
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      passwordVisible!
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: togglePasswordVisibility,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }
}
