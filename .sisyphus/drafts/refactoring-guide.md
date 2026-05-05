# Tool Refactoring Guide

## Per-Tool Refactoring Checklist

각 기존 Tool에 공통으로 적용할 항목:

### 1. TAG + 로깅 추가
```kotlin
private val TAG = "AIOS-{ToolName}"
```
- catch 블록에 `Log.e(TAG, "Error: ${e.message}", e)` 추가
- 정상 동작에는 `Log.i` 불필요 (에러만 로깅)

### 2. description 개선
LLM이 이해하기 쉬운 명확한 설명으로 개선. `name`은 절대 변경 금지.

### 3. 필수 파라미터 검증
```kotlin
val param = json.optString("param", "")
if (param.isBlank()) return "Error: 'param' parameter required for X action"
```

### 4. action 비교 lowercase
```kotlin
val action = json.optString("action", "").lowercase()
```

### 5. unknown action 안내
```kotlin
else -> "Error: Unknown action '$action'. Use action1, action2, or action3."
```

### 6. 서비스 null 체크 (ExtendedTool만)
```kotlin
val service = toolContext.accessibilityService()
    ?: return "Error: Accessibility service not enabled"
```
catch 블록 이전에 체크.

---

## Tool별 리팩토링 범위

### CalculatorTool (AgentTool)
- [ ] TAG 추가: `AIOS-Calculator`
- [ ] catch 블록에 `Log.e` 추가
- [ ] description: 수식 예시 포함하여 명확화
- [ ] empty expression 에러 메시지 명확화
- **변경 금지**: expression evaluator 자체, name = "calculator"

### TimerTool (AgentTool)
- [ ] TAG 추가: `AIOS-Timer`
- [ ] catch 블록에 `Log.e` 추가
- **변경 금지**: Thread.sleep → coroutine 변경 금지, interrupt 메커니즘 유지

### DeviceInfoTool (AgentTool)
- [ ] TAG 추가: `AIOS-DeviceInfo`
- [ ] 현재 try-catch 없음 → try-catch + Log.e 추가

### NotePadTool (AgentTool)
- [ ] TAG 추가: `AIOS-NotePad`
- [ ] catch 블록에 `Log.e` 추가
- [ ] unknown action 메시지 개선: `"Error: Unknown action '$action'. Use save, get, list, or delete."`

### ScreenReaderTool (ExtendedTool)
- [ ] TAG 추가: `AIOS-ScreenReader`
- [ ] catch 블록에 이미 Log.e 있음 — 확인만
- [ ] **ScreenFindTool을 별도 파일로 분리**

### ScreenFindTool (ExtendedTool)
- [ ] **ScreenReaderTool.kt에서 분리 → `ScreenFindTool.kt` 신규 파일**
- [ ] TAG 추가: `AIOS-ScreenFind`
- [ ] catch 블록에 `Log.e` 추가

### ScreenActionTool (ExtendedTool)
- [ ] 이미 TAG 있음 (`AIOS-ScreenAction`) — 확인만
- [ ] 이미 Log.e 있음 — 확인만
- [ ] unknown action 메시지에 모든 action 나열 확인

### AppLauncherTool (ExtendedTool)
- [ ] TAG 추가: `AIOS-AppLauncher`
- [ ] catch 블록에 `Log.e` 추가
- [ ] unknown action 메시지 개선

### NotificationTool (ExtendedTool)
- [ ] TAG 추가: `AIOS-Notification`
- [ ] catch 블록에 `Log.e` 추가
- [ ] static 패턴 (NotificationListener.getRecentNotifications) — 구조 변경 최소, TAG/로깅만 추가
- [ ] 테스트: `mockkStatic(NotificationListener::class)` 활용

### ContactSearchTool (ExtendedTool)
- [ ] TAG 추가: `AIOS-ContactSearch`
- [ ] catch 블록에 `Log.e` 추가

### SmsSenderTool (ExtendedTool)
- [ ] TAG 추가: `AIOS-SmsSender`
- [ ] catch 블록에 `Log.e` 추가
- [ ] unknown action 메시지 개선: `"Error: Unknown action '$action'. Use send or read."`

### PhoneCallerTool (ExtendedTool)
- [ ] TAG 추가: `AIOS-PhoneCaller`
- [ ] catch 블록에 `Log.e` 추가
- [ ] unknown action 메시지 개선: `"Error: Unknown action '$action'. Use call or dial."`

---

## Canonical Pattern (ScreenActionTool 기준)

```kotlin
class ExampleTool : ExtendedTool {
    private val TAG = "AIOS-Example"

    override val name = "example"
    override val description = "Description for LLM. Args: {action: do_thing, param: string}"
    override val parameters = """{"action": "do_thing", "param": "string"}"""

    override fun execute(args: String, toolContext: ToolContext): String {
        return try {
            val json = JSONObject(args)
            val action = json.optString("action", "").lowercase()

            val service = toolContext.accessibilityService()
                ?: return "Error: Accessibility service not enabled"

            when (action) {
                "do_thing" -> handleDoThing(service, json)
                else -> "Error: Unknown action '$action'. Use do_thing."
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error: ${e.message}", e)
            "Error: ${e.message}"
        }
    }
}
```
