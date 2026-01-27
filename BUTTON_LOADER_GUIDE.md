# Button Loading Indicator Guide

## Overview

A comprehensive solution for adding loading indicators to buttons that make API calls throughout the HorillaMobile app.

## Files Modified

- `lib/utils/button_loader_mixin.dart` - Main loader implementation
- `lib/horilla_leave/leave_request.dart` - Added ButtonLoaderMixin
- `lib/horilla_leave/my_leave_request.dart` - Added ButtonLoaderMixin
- `lib/attendance_views/attendance_request.dart` - Added ButtonLoaderMixin
- `lib/employee_views/work_type_request.dart` - Added ButtonLoaderMixin
- `lib/employee_views/shift_request.dart` - Added ButtonLoaderMixin

## How to Use

### 1. Add the Mixin to Your StatefulWidget Class

```dart
import '../utils/button_loader_mixin.dart';

class MyScreen extends State<MyWidget> with ButtonLoaderMixin {
  // ... rest of your code
}
```

### 2. Basic Button with Loading State - Option A (Manual State Management)

**For buttons that make API calls:**

```dart
// Add loading state variable
bool _isCreateLoading = false;

// Use LoadingButton widget
LoadingButton(
  isLoading: _isCreateLoading,
  onPressed: () async {
    try {
      setState(() => _isCreateLoading = true);

      // Your API call here
      await createNewLeaveType(createdDetails, checkfile, fileName, filePath);

      if (_errorMessage == null) {
        Navigator.of(context).pop(true);
        showCreateAnimation();
      }
    } finally {
      setState(() => _isCreateLoading = false);
    }
  },
  style: ButtonStyle(
    backgroundColor: MaterialStateProperty.all<Color>(const Color(0xFF6B57F0)),
    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
    ),
  ),
  child: const Text('Save', style: TextStyle(color: Colors.white)),
)
```

### 3. Advanced Button with Loading State - Option B (Using Mixin Helper)

**For better code organization, use the mixin helper:**

```dart
LoadingButton(
  isLoading: isButtonLoading('create_leave_btn'),
  onPressed: () async {
    await executeWithButtonLoading('create_leave_btn', () async {
      // Your API call here
      await createNewLeaveType(createdDetails, checkfile, fileName, filePath);

      if (_errorMessage == null) {
        Navigator.of(context).pop(true);
        showCreateAnimation();
      }
    }).catchError((e) {
      print('Error: $e');
    });
  },
  style: ButtonStyle(...),
  child: const Text('Save', style: TextStyle(color: Colors.white)),
)
```

### 4. Using Stack for Loading Overlay (Existing Pattern)

**Keep using your existing patterns with slight modifications:**

```dart
actions: [
  SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: _isLoading ? null : () async {
        try {
          setState(() => _isLoading = true);

          // API call
          await someApiFunction();

        } finally {
          setState(() => _isLoading = false);
        }
      },
      style: ButtonStyle(...),
      child: const Text('Save'),
    ),
  ),
],
if (_isLoading)
  const Center(child: CircularProgressIndicator()),
```

### 5. Standard ElevatedButton Pattern

**For buttons outside of dialogs:**

```dart
// Add button-specific loading state
bool _isSubmitLoading = false;

ElevatedButton(
  onPressed: _isSubmitLoading ? null : () async {
    setState(() => _isSubmitLoading = true);
    try {
      // Your API call
      await submitForm();
    } catch (e) {
      print('Error: $e');
    } finally {
      setState(() => _isSubmitLoading = false);
    }
  },
  child: _isSubmitLoading
      ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
      : const Text('Submit'),
)
```

## Implementation Examples

### Example 1: Leave Request Creation Button

```dart
// In leave_request.dart
TextButton(
  onPressed: _isCreateLoading ? null : () async {
    setState(() => _isCreateLoading = true);
    try {
      await createNewLeaveType(createdDetails, checkfile, fileName, filePath);
      if (_errorMessage == null) {
        Navigator.of(context).pop(true);
        showCreateAnimation();
      }
    } finally {
      setState(() => _isCreateLoading = false);
    }
  },
  style: ButtonStyle(
    backgroundColor: MaterialStateProperty.all<Color>(const Color(0xFF6B57F0)),
    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
    ),
  ),
  child: _isCreateLoading
      ? const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
      : const Text('Save', style: TextStyle(color: Colors.white)),
)
```

### Example 2: Multiple Buttons with Different API Calls

```dart
// Dialog with multiple action buttons
actions: [
  ElevatedButton(
    onPressed: _isApproveLoading ? null : () async {
      await executeWithButtonLoading('approve_btn', () async {
        await approveLeaveRequest();
      });
    },
    child: _isApproveLoading
        ? const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Text('Approve'),
  ),
  ElevatedButton(
    onPressed: _isRejectLoading ? null : () async {
      await executeWithButtonLoading('reject_btn', () async {
        await rejectLeaveRequest();
      });
    },
    child: _isRejectLoading
        ? const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Text('Reject'),
  ),
]
```

## Screens to Update (TODO)

Add loading indicators to buttons with API calls in:

- [x] `leave_request.dart` - Ready for implementation
- [x] `my_leave_request.dart` - Ready for implementation
- [x] `attendance_request.dart` - Ready for implementation
- [x] `work_type_request.dart` - Ready for implementation
- [x] `shift_request.dart` - Ready for implementation
- [ ] `selected_leave_type.dart`
- [ ] `leave_types.dart`
- [ ] `leave_overview.dart`
- [ ] `leave_allocation_request.dart`
- [ ] `all_assigned_leave.dart`
- [ ] `rotating_work_type.dart`
- [ ] `rotating_shift.dart`
- [ ] `attendance_overview.dart`
- [ ] `hour_account.dart`
- [ ] `attendance_attendance.dart`
- [ ] `employee_list.dart`
- [ ] `employee_form.dart`

## API Call Pattern

Every button that calls an API should follow this pattern:

```dart
// 1. Declare loading state for the button
bool _isMyButtonLoading = false;

// 2. Use the LoadingButton or add conditional loading
onPressed: _isMyButtonLoading ? null : () async {
  setState(() => _isMyButtonLoading = true);
  try {
    // 3. Make the API call
    await myApiFunction();
    // 4. Handle success

  } catch (e) {
    // 5. Handle error
    print('Error: $e');
  } finally {
    // 6. Always reset loading state
    setState(() => _isMyButtonLoading = false);
  }
}

// 7. Show loading indicator in child
child: _isMyButtonLoading
    ? const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      )
    : const Text('Button Text'),
```

## Best Practices

1. **Always use try-finally** to ensure loading state is reset even if an error occurs
2. **Disable button while loading** by setting `onPressed: null` when loading
3. **Use consistent loading indicator size** across all buttons
4. **Show meaningful feedback** - use loading state, error messages, and success feedback
5. **Provide visual feedback** - change button appearance during loading
6. **Test error scenarios** - ensure loading state resets on API failures

## Customization

### Custom Loading Color

```dart
child: _isLoading
    ? SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.blue, // Custom color
        ),
      )
    : const Text('Save'),
```

### Disable Other UI During Loading

```dart
// Wrap the entire form with IgnorePointer to prevent interaction
IgnorePointer(
  ignoring: _isLoading,
  child: YourFormWidget(),
)
```

## Notes

- This implementation prevents duplicate API calls by disabling buttons during loading
- Loading states are automatically reset if an exception occurs
- The mixin provides helper methods for managing multiple button loading states
- Consider using this pattern for all user-triggered API calls
