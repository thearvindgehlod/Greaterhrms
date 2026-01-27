import 'package:flutter/material.dart';

/// Mixin to manage button loading states
/// Usage: class MyWidget extends State<MyStatefulWidget> with ButtonLoaderMixin
mixin ButtonLoaderMixin<T extends StatefulWidget> on State<T> {
  /// Map to track loading state for each button by its unique key
  final Map<String, bool> _buttonLoadingStates = {};

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

  /// Wrapper function to handle loading state for async operations
  /// Usage: await executeWithButtonLoading('button_key', myAsyncFunction())
  Future<T?> executeWithButtonLoading<T>(
    String buttonKey,
    Future<T> Function() asyncFunction,
  ) async {
    try {
      setButtonLoading(buttonKey, true);
      final result = await asyncFunction();
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
