# Button Loader - Before & After Examples

## Example 1: Simple Save Button

### ❌ BEFORE (No Loading Indicator)

```dart
actions: <Widget>[
  SizedBox(
    width: double.infinity,
    child: TextButton(
      onPressed: () async {
        if (isSaveClick == true) {
          isSaveClick = false;
          if (startDate == null) {
            setState(() {
              isSaveClick = true;
              _validateDate = true;
            });
          } else {
            Map<String, dynamic> createdDetails = {
              "start_date": startDateSelect.text,
              'description': descriptionSelect.text,
            };
            await createNewLeaveType(createdDetails, checkfile, fileName, filePath);
            setState(() {
              isSaveClick = false;
            });
            if (_errorMessage == null) {
              Navigator.of(context).pop(true);
              showCreateAnimation();
            }
          }
        }
      },
      style: ButtonStyle(
        backgroundColor: MaterialStateProperty.all<Color>(const Color(0xFF6B57F0)),
        shape: MaterialStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
        ),
      ),
      child: const Text('Save', style: TextStyle(color: Colors.white)),
    ),
  ),
],
```

**Issues:**

- No visual feedback while API is processing
- User doesn't know if button click worked
- User might click multiple times
- No loading indicator

### ✅ AFTER (With Loading Indicator)

```dart
actions: <Widget>[
  SizedBox(
    width: double.infinity,
    child: TextButton(
      onPressed: _isCreateLeaveLoading ? null : () async {
        if (isSaveClick == true) {
          isSaveClick = false;
          if (startDate == null) {
            setState(() {
              isSaveClick = true;
              _validateDate = true;
            });
          } else {
            setState(() => _isCreateLeaveLoading = true); // ← NEW
            try {
              Map<String, dynamic> createdDetails = {
                "start_date": startDateSelect.text,
                'description': descriptionSelect.text,
              };
              await createNewLeaveType(createdDetails, checkfile, fileName, filePath);
              setState(() {
                isSaveClick = false;
              });
              if (_errorMessage == null) {
                Navigator.of(context).pop(true);
                showCreateAnimation();
              }
            } finally {
              setState(() => _isCreateLeaveLoading = false); // ← NEW
            }
          }
        }
      },
      style: ButtonStyle(
        backgroundColor: MaterialStateProperty.all<Color>(const Color(0xFF6B57F0)),
        shape: MaterialStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
        ),
      ),
      child: _isCreateLeaveLoading // ← NEW
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text('Save', style: TextStyle(color: Colors.white)),
    ),
  ),
],
```

**Benefits:**

- ✅ Shows loading spinner while API processes
- ✅ Button disabled during loading (prevents duplicates)
- ✅ Clear visual feedback to user
- ✅ Professional appearance

---

## Example 2: Approve/Reject Dialog Buttons

### ❌ BEFORE (No Loading on Multiple Buttons)

```dart
showDialog(
  context: context,
  builder: (BuildContext context) {
    return AlertDialog(
      title: const Text('Leave Request'),
      content: Text('Do you want to approve this leave request?'),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            await approveLeaveRequest(leaveId);
            Navigator.of(context).pop();
            showDialog(context: context, ...); // Show confirmation
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          child: const Text('Approve'),
        ),
        ElevatedButton(
          onPressed: () async {
            await rejectLeaveRequest(leaveId, rejectReason);
            Navigator.of(context).pop();
            showDialog(context: context, ...); // Show confirmation
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('Reject'),
        ),
      ],
    );
  },
);
```

**Issues:**

- Both Approve and Reject buttons have no loading feedback
- No indication of which button was clicked
- If one API call takes time, user might click again

### ✅ AFTER (With Separate Loading States)

```dart
showDialog(
  context: context,
  builder: (BuildContext context) {
    return AlertDialog(
      title: const Text('Leave Request'),
      content: Text('Do you want to approve this leave request?'),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isApproveLeaveLoading ? null : () async {
            setState(() => _isApproveLeaveLoading = true);
            try {
              await approveLeaveRequest(leaveId);
              Navigator.of(context).pop();
              showDialog(context: context, ...); // Show confirmation
            } catch (e) {
              print('Error: $e');
            } finally {
              setState(() => _isApproveLeaveLoading = false);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            disabledBackgroundColor: Colors.grey, // Optional
          ),
          child: _isApproveLeaveLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Approve'),
        ),
        ElevatedButton(
          onPressed: _isRejectLeaveLoading ? null : () async {
            setState(() => _isRejectLeaveLoading = true);
            try {
              await rejectLeaveRequest(leaveId, rejectReason);
              Navigator.of(context).pop();
              showDialog(context: context, ...); // Show confirmation
            } catch (e) {
              print('Error: $e');
            } finally {
              setState(() => _isRejectLeaveLoading = false);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            disabledBackgroundColor: Colors.grey, // Optional
          ),
          child: _isRejectLeaveLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Reject'),
        ),
      ],
    );
  },
);
```

**Benefits:**

- ✅ Each button has independent loading state
- ✅ Clear indication of which action is processing
- ✅ Other button remains clickable (e.g., Reject while Approve is loading)
- ✅ Professional appearance with separate loaders

---

## Example 3: Icon Button with Loading (File Upload)

### ❌ BEFORE (No Feedback on Icon Button)

```dart
IconButton(
  icon: const Icon(Icons.attach_file),
  onPressed: () async {
    XFile? file = await uploadFile(context);
    if (file != null) {
      setState(() {
        pickedFile = file;
        fileName = file.name;
        filePath = file.path;
        checkfile = true;
        setFileName();
      });
    }
  },
),
```

**Issues:**

- Icon button gives no loading feedback
- Hard to tell if upload is in progress

### ✅ AFTER (With Loading Indicator)

```dart
Stack(
  children: [
    IconButton(
      icon: const Icon(Icons.attach_file),
      onPressed: _isFileUploadLoading ? null : () async {
        setState(() => _isFileUploadLoading = true);
        try {
          XFile? file = await uploadFile(context);
          if (file != null) {
            setState(() {
              pickedFile = file;
              fileName = file.name;
              filePath = file.path;
              checkfile = true;
              setFileName();
            });
          }
        } catch (e) {
          print('Error uploading file: $e');
        } finally {
          setState(() => _isFileUploadLoading = false);
        }
      },
    ),
    if (_isFileUploadLoading)
      const Positioned(
        bottom: 0,
        right: 0,
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.blue,
          ),
        ),
      ),
  ],
),
```

**Benefits:**

- ✅ Small loading indicator on icon button
- ✅ Doesn't obscure the icon completely
- ✅ Clear visual feedback for file upload

---

## Example 4: Using LoadingButton Helper Widget

### ✅ Simplified with LoadingButton

```dart
LoadingButton(
  isLoading: _isCreateLeaveLoading,
  onPressed: () async {
    try {
      setState(() => _isCreateLeaveLoading = true);
      await createNewLeaveType(createdDetails, checkfile, fileName, filePath);

      if (_errorMessage == null) {
        Navigator.of(context).pop(true);
      }
    } finally {
      setState(() => _isCreateLeaveLoading = false);
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

**Benefits:**

- ✅ Less boilerplate code
- ✅ Loading indicator handled automatically
- ✅ Button disabled automatically during loading
- ✅ Clean, readable code

---

## Example 5: Using Mixin Helper Methods

### ✅ Using executeWithButtonLoading Helper

```dart
ElevatedButton(
  onPressed: isButtonLoading('create_leaf') ? null : () {
    executeWithButtonLoading('create_leave', () async {
      await createNewLeaveType(createdDetails, checkfile, fileName, filePath);

      if (_errorMessage == null) {
        Navigator.of(context).pop(true);
        showCreateAnimation();
      }
    }).catchError((e) {
      print('Error: $e');
      showErrorSnackBar(context, 'Failed to create leave');
    });
  },
  child: isButtonLoading('create_leave')
      ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : const Text('Save'),
)
```

**Benefits:**

- ✅ Mixin handles loading state automatically
- ✅ Less manual setState calls
- ✅ Built-in error handling
- ✅ Cleaner code

---

## Quick Reference Table

| Pattern         | Best For         | Code Length | Boilerplate |
| --------------- | ---------------- | ----------- | ----------- |
| Manual setState | Simple buttons   | 15-20 lines | Medium      |
| LoadingButton   | Standard buttons | 10-15 lines | Low         |
| Mixin Helper    | Complex flows    | 10-12 lines | Very Low    |
| Stack overlay   | Icon buttons     | 20-25 lines | High        |

---

## Implementation Difficulty

```
Easiest  → Manual setState
         → LoadingButton helper
         → Mixin executeWithButtonLoading
         → Stack-based overlays  → Hardest
```

**Recommended**: Start with "Manual setState" for first 5-10 buttons, then switch to LoadingButton or Mixin helpers once comfortable.

---

## Testing Checklist

For each button, verify:

- [ ] Click button → loader appears immediately
- [ ] During loading → button is disabled (can't click again)
- [ ] API completes → loader disappears
- [ ] API fails → loader disappears, error shown
- [ ] Loader appears within 100ms of click
- [ ] Loader size is consistent with other buttons
- [ ] Colors match the button style
- [ ] Text/icon is not visible while loading (optional: can fade it)

---

## Common Mistakes to Avoid

### ❌ Mistake 1: Forgetting try-finally

```dart
// WRONG - Loading state never resets if error occurs
onPressed: () async {
  setState(() => _isLoading = true);
  await myApiCall(); // If this throws, _isLoading stays true!
  setState(() => _isLoading = false);
}
```

### ✅ Correct Way

```dart
// CORRECT
onPressed: () async {
  setState(() => _isLoading = true);
  try {
    await myApiCall();
  } finally {
    setState(() => _isLoading = false);
  }
}
```

### ❌ Mistake 2: Not disabling button during loading

```dart
// WRONG - User can click multiple times
onPressed: () async {
  setState(() => _isLoading = true);
  await myApiCall();
  setState(() => _isLoading = false);
}
```

### ✅ Correct Way

```dart
// CORRECT
onPressed: _isLoading ? null : () async {
  setState(() => _isLoading = true);
  try {
    await myApiCall();
  } finally {
    setState(() => _isLoading = false);
  }
}
```

### ❌ Mistake 3: Wrong loading indicator color

```dart
// WRONG - White loader on white button = invisible
child: _isLoading
    ? const CircularProgressIndicator(color: Colors.white)
    : const Text('Save')
```

### ✅ Correct Way

```dart
// CORRECT - Make sure color is visible
child: _isLoading
    ? const CircularProgressIndicator(
        strokeWidth: 2,
        color: Colors.white, // Matches button theme
      )
    : const Text('Save', style: TextStyle(color: Colors.white))
```

---

## Need Help?

Refer to:

1. **BUTTON_LOADER_GUIDE.md** - Full API documentation
2. **IMPLEMENTATION_SUMMARY.md** - Implementation checklist
3. **This file** - Before/After examples
4. **lib/utils/button_loader_mixin.dart** - Source code

Good luck with implementation! 🎉
