# New Tool Specifications

## 1. SmartWaitTool

### Basic Info
- **Interface**: `ExtendedTool`
- **Class**: `SmartWaitTool`
- **File**: `android/app/src/main/kotlin/com/agent/aios/agent/tools/SmartWaitTool.kt`
- **TAG**: `AIOS-SmartWait`
- **name**: `smart_wait`
- **Risk Level**: `ToolRisk.LOW` (read-only polling, no state mutation)

### Description
```
Wait for a condition to be met on screen. Args: {action: wait_for_text|wait_for_idle|wait_for_app, text: string (for wait_for_text), package_name: string (for wait_for_app), timeout: int (seconds, default 10)}
```

### Parameters JSON
```json
{
  "action": "wait_for_text|wait_for_idle|wait_for_app",
  "text": "string, text to wait for (required for wait_for_text)",
  "package_name": "string, app package name (required for wait_for_app)",
  "timeout": "integer, max wait in seconds (default 10, max 30)"
}
```

### Actions

#### `wait_for_text`
- **Required params**: `text`
- **Behavior**: Polls `AIOSAccessibilityService.findNodesByText(text)` every 500ms. Returns success when nodes found, error on timeout.
- **Return on success**: `"Text '$text' appeared on screen"`
- **Return on timeout**: `"Error: Timed out waiting for text '$text' after ${timeout}s"`
- **Return on missing param**: `"Error: 'text' parameter required for wait_for_text"`

#### `wait_for_idle`
- **Required params**: none
- **Behavior**: Polls `AIOSAccessibilityService.getScreenText()` every 500ms. Compares consecutive reads. Returns success when two consecutive reads are identical (screen stopped changing).
- **Return on success**: `"Screen is idle (no changes for 1s)"`
- **Return on timeout**: `"Error: Timed out waiting for idle screen after ${timeout}s"`

#### `wait_for_app`
- **Required params**: `package_name`
- **Behavior**: Polls `AIOSAccessibilityService.getRootNode()?.packageName` every 500ms. Returns success when packageName matches.
- **Return on success**: `"App '$package_name' is now in foreground"`
- **Return on timeout**: `"Error: Timed out waiting for app '$package_name' after ${timeout}s"`
- **Return on missing param**: `"Error: 'package_name' parameter required for wait_for_app"`

### Implementation Notes
- Internal polling loop: `Thread.sleep(500)` between checks (same pattern as TimerTool)
- Support interruption: check `Thread.currentThread().isInterrupted` in loop
- Timeout range: 1-30 seconds (reject 0 or >30 with error)
- Accessibility service null check at start: `"Error: Accessibility service not enabled"`

---

## 2. AppStateTool

### Basic Info
- **Interface**: `ExtendedTool`
- **Class**: `AppStateTool`
- **File**: `android/app/src/main/kotlin/com/agent/aios/agent/tools/AppStateTool.kt`
- **TAG**: `AIOS-AppState`
- **name**: `app_state`
- **Risk Level**: `ToolRisk.SAFE` (read-only, no state mutation)

### Description
```
Check current app state. Args: {action: current_app|is_home|is_running, package_name: string (for is_running)}
```

### Parameters JSON
```json
{
  "action": "current_app|is_home|is_running",
  "package_name": "string, app package name to check (required for is_running)"
}
```

### Actions

#### `current_app`
- **Required params**: none
- **Behavior**: Gets `AIOSAccessibilityService.getRootNode()?.packageName` and returns JSON with package name.
- **Return on success**: `{"package_name": "com.google.android.youtube", "activity": "com.google.android.youtube.HomeActivity"}` (activity may be null)
- **Return on no window**: `"No active window detected"`

#### `is_home`
- **Required params**: none
- **Behavior**: Checks if current foreground package is a launcher. Resolves default launcher via `PackageManager.getHomeActivities()` or checks if `getRootNode()?.packageName` matches known launchers. Simple approach: check if package has `Intent.CATEGORY_HOME` category.
- **Return**: `"Home screen: true"` or `"Home screen: false (current: com.example.app)"`

#### `is_running`
- **Required params**: `package_name`
- **Behavior**: Checks if the given package is currently the foreground app.
- **Return on match**: `"App 'com.example.app' is running in foreground"`
- **Return on no match**: `"App 'com.example.app' is not in foreground (current: com.other.app)"`
- **Return on missing param**: `"Error: 'package_name' parameter required for is_running"`

### Implementation Notes
- Uses `AccessibilityNodeInfo.getPackageName()` from root node to determine current app
- `is_home`: Resolve launcher package via `Intent(CATEGORY_HOME)` + `resolveActivity()` and compare
- `is_running`: Simple equals check on `getRootNode()?.packageName?.toString()`
- Service null check: `"Error: Accessibility service not enabled"`

---

## 3. ClipboardTool

### Basic Info
- **Interface**: `ExtendedTool`
- **Class**: `ClipboardTool`
- **File**: `android/app/src/main/kotlin/com/agent/aios/agent/tools/ClipboardTool.kt`
- **TAG**: `AIOS-Clipboard`
- **name**: `clipboard`

### Description
```
Clipboard operations. Args: {action: copy|read|paste, text: string (for copy)}
```

### Parameters JSON
```json
{
  "action": "copy|read|paste",
  "text": "string, text to copy to clipboard (required for copy)"
}
```

### Actions

#### `copy`
- **Required params**: `text`
- **Behavior**: Gets `ClipboardManager` from `toolContext.appContext`, calls `setPrimaryClip(ClipData.newPlainText("AIOS", text))`.
- **Return on success**: `"Copied to clipboard: '${text.take(50)}'"`
- **Return on missing param**: `"Error: 'text' parameter required for copy"`

#### `read`
- **Required params**: none
- **Behavior**: Gets `ClipboardManager`, reads `primaryClip?.getItemAt(0)?.text`.
- **Return on success**: `"Clipboard content: '${content}'"`
- **Return on empty**: `"Clipboard is empty"`
- **Return on SecurityException** (Android 10+): `"Error: Cannot read clipboard — Android restricts clipboard access when app is not in focus. Try 'paste' action instead."`

#### `paste`
- **Required params**: none
- **Behavior**: Reads clipboard content, then types it into the currently focused editable field using `AIOSAccessibilityService.typeText()`.
- **Return on success**: `"Pasted clipboard content into focused field"`
- **Return on empty clipboard**: `"Error: Clipboard is empty"`
- **Return on no focused field**: `"Error: No focused editable field found"`
- **Return on service null**: `"Error: Accessibility service not enabled"`

### Risk Classification
```kotlin
"clipboard" -> when (action) {
    "copy" -> ToolRisk.HIGH      // writes to system clipboard
    "read" -> ToolRisk.LOW       // reads clipboard
    "paste" -> ToolRisk.HIGH     // types clipboard content into fields
    else -> ToolRisk.HIGH
}
```

### Implementation Notes
- ClipboardManager: `toolContext.appContext.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager`
- Android 10+ restriction: Only the default input method or the app currently in focus can read clipboard. Wrap `primaryClip` access in try-catch for `SecurityException`.
- `paste` action combines clipboard read + focused field detection (reuse `findFocusedEditable` pattern from ScreenActionTool) + `service.typeText()`

---

## 4. RecentAppsTool

### Basic Info
- **Interface**: `ExtendedTool`
- **Class**: `RecentAppsTool`
- **File**: `android/app/src/main/kotlin/com/agent/aios/agent/tools/RecentAppsTool.kt`
- **TAG**: `AIOS-RecentApps`
- **name**: `recent_apps`

### Description
```
Manage recent apps. Args: {action: list|switch_to|close, package_name: string (for switch_to/close)}
```

### Parameters JSON
```json
{
  "action": "list|switch_to|close",
  "package_name": "string, app package name (required for switch_to/close)"
}
```

### Actions

#### `list`
- **Required params**: none
- **Behavior**:
  1. Calls `service.performGlobalAction("recents")` to open recent apps screen
  2. Waits 1000ms for the recents UI to appear
  3. Calls `service.getScreenText()` to read the recents list
  4. Calls `service.performGlobalAction("back")` to dismiss recents
  5. Returns the parsed screen text
- **Return on success**: The raw screen text from recents view (LLM will parse it)
- **Return on service null**: `"Error: Accessibility service not enabled"`

#### `switch_to`
- **Required params**: `package_name`
- **Behavior**:
  1. Calls `service.performGlobalAction("recents")` to open recent apps
  2. Waits 1000ms
  3. Calls `service.findNodesByText(package_name)` or searches by app name
  4. Taps on the found node
- **Return on success**: `"Switched to '$package_name'"`
- **Return on not found**: `"Error: App '$package_name' not found in recent apps"`
- **Return on missing param**: `"Error: 'package_name' parameter required for switch_to"`

#### `close`
- **Required params**: `package_name`
- **Behavior**:
  1. Calls `service.performGlobalAction("recents")` to open recent apps
  2. Waits 1000ms
  3. Finds the app card node
  4. Performs a swipe up gesture on it (dismiss/swipe away)
  5. Calls `service.performGlobalAction("back")` to dismiss recents
- **Return on success**: `"Closed '$package_name' from recent apps"`
- **Return on not found**: `"Error: App '$package_name' not found in recent apps"`
- **Return on missing param**: `"Error: 'package_name' parameter required for close"`

### Risk Classification
```kotlin
"recent_apps" -> when (action) {
    "list" -> ToolRisk.LOW        // read-only
    "switch_to" -> ToolRisk.HIGH  // changes foreground app
    "close" -> ToolRisk.HIGH      // dismisses app from recents
    else -> ToolRisk.HIGH
}
```

### Implementation Notes
- Uses `service.performGlobalAction("recents")` to trigger the recent apps overview
- After opening recents, uses `Thread.sleep(1000)` to wait for the UI to render
- Uses `service.findNodesByText()` and `service.getScreenText()` to interact
- Uses `service.performSwipe()` for swipe-away dismiss
- Always calls `performGlobalAction("back")` to dismiss recents after action (except errors)
- Service null check: `"Error: Accessibility service not enabled"`
