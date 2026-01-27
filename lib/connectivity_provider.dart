import 'package:flutter/material.dart';

class ConnectivityBanner extends StatefulWidget {
  final Widget child;

  const ConnectivityBanner({super.key, required this.child});

  @override
  _ConnectivityBannerState createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  final bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    // Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
    //   setState(() {
    //     _isOffline = result == ConnectivityResult.none;
    //   });
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isOffline)
          Container(
            color: const Color(0xFF6B57F0),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            child: const Text(
              'No Internet Connection',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
