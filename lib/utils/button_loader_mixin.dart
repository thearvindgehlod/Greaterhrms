import 'package:flutter/material.dart';

/// Mixin to manage button loading states
/// Usage: class MyWidget extends State<MyStatefulWidget> with ButtonLoaderMixin
mixin ButtonLoaderMixin<T extends StatefulWidget> on State<T> {
  /// Map to track loading state for each button by its unique key
  final Map<String, bool> _buttonLoadingStates = {};

  /// Minimum duration (milliseconds) to show loader to ensure smooth UX
  /// Even if API responds faster, loader will show for at least this duration
  static const int minLoaderDuration = 1000; // 1 second minimum

  /// Set loading state for a button
  void setButtonLoading(String buttonKey, bool isLoading) {
    if (mounted) {
      setState(() {
        _buttonLoadingStates[buttonKey] = isLoading;
      });
    }
  }

  /// Check if a button is loading
  bool isButtonLoading(String buttonKey) {
    return _buttonLoadingStates[buttonKey] ?? false;
  }

  /// Reset all button loading states
  void resetAllButtonLoading() {
    if (mounted) {
      setState(() {
        _buttonLoadingStates.clear();
      });
    }
  }

  /// Wrapper function to handle loading state for async operations with minimum delay
  /// Ensures loader shows for at least [minLoaderDuration] milliseconds for better UX
  /// Usage: await executeWithButtonLoading('button_key', myAsyncFunction())
  Future<T?> executeWithButtonLoading<T>(
    String buttonKey,
    Future<T> Function() asyncFunction, {
    int? customMinDuration,
  }) async {
    try {
      setButtonLoading(buttonKey, true);
      final minDuration = customMinDuration ?? minLoaderDuration;

      // Execute API call and minimum delay in parallel, wait for both to complete
      final result = await Future.wait<dynamic>([
        asyncFunction(),
        Future.delayed(Duration(milliseconds: minDuration)),
      ]).then((results) => results[0] as T?);

      return result;
    } catch (e) {
      print('Error in button operation: $e');
      rethrow;
    } finally {
      setButtonLoading(buttonKey, false);
    }
  }

  /// Alternative method for quick API calls that need guaranteed minimum loader time
  /// Use this when you want to ensure loader displays for at least the duration
  /// regardless of API response speed
  /// Usage: await executeWithMinLoadTime('button_key', myAsyncFunction(), duration: 2000)
  Future<T?> executeWithMinLoadTime<T>(
    String buttonKey,
    Future<T> Function() asyncFunction, {
    int duration = minLoaderDuration,
  }) async {
    try {
      setButtonLoading(buttonKey, true);

      // Start timer and API call simultaneously
      final startTime = DateTime.now();
      final result = await asyncFunction();
      final elapsedTime = DateTime.now().difference(startTime).inMilliseconds;

      // If API responded faster than min duration, wait for the remaining time
      if (elapsedTime < duration) {
        await Future.delayed(Duration(milliseconds: duration - elapsedTime));
      }

      return result;
    } catch (e) {
      print('Error in button operation: $e');
      rethrow;
    } finally {
      setButtonLoading(buttonKey, false);
    }
  }
}

/// Widget to show loading indicator on button
class LoadingButtonWrapper extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final Color? loadingColor;

  const LoadingButtonWrapper({
    Key? key,
    required this.isLoading,
    required this.child,
    this.loadingColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isLoading) {
      return child;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: 0.5,
          child: child,
        ),
        CircularProgressIndicator(
          color: loadingColor,
          strokeWidth: 2,
        ),
      ],
    );
  }
}

/// Helper widget to create a loading button
class LoadingButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final Color? loadingColor;

  const LoadingButton({
    Key? key,
    required this.isLoading,
    required this.onPressed,
    required this.child,
    this.style,
    this.loadingColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: loadingColor ?? Colors.white,
                strokeWidth: 2,
              ),
            )
          : child,
    );
  }
}
