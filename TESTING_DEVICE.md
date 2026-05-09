# AIOS Device Testing

기기 테스트 시 AGENTS.md §0의 기기 명령어(설치, 실행, 스크린샷, logcat)와
아래의 테스트용 adb 패턴을 조합하여 유동적으로 수행한다.

## 1. 자동화된 통합 테스트 (기기 필요)

`flutter test integration_test/` 로 실행 (기기 연결 + GGUF 모델 필요):

| 파일 | 테스트 항목 |
|------|-----------|
| `tool_execution_test.dart` | LLM이 calculator/notepad/timer/device_info 선택·실행, 다중 tool chaining |
| `agent_integration_test.dart` | ReactStrategy 실행, cancel, clearHistory |
| `chat_pipeline_test.dart` | LlmRepository sendMessage, token stream |
| `user_flow_test.dart` | 모델 로드→채팅→정지→삭제 전체 플로우 |
| `model_test.dart` | GGUF 모델 로드/추론/해제 |
| `app_test.dart` | ChatScreen/SettingsScreen UI |
| `database_integration_test.dart` | Drift SQLite CRUD |
| `settings_persistence_test.dart` | SharedPreferences 영속성 |
| `conversation_persistence_test.dart` | 대화 저장/로드 |

## 2. 스모크 테스트 (빌드 후 필수)

빌드→설치 후 **반드시** 전부 확인:

| # | 항목 | 입력 | 통과 기준 (logcat) |
|---|------|------|-------------------|
| 1 | 앱 실행 | 설치 후 실행 | 크래시 없음, `[AIOS-ChatNotifier] Session initialized` |
| 2 | 모델 로드 | 설정 → Load | `[AIOS-RealEngine] Model loaded` |
| 3 | 기본 응답 | "hello" | `[AIOS-React]` + 응답 텍스트 |
| 4 | calculator | "calculate 15 plus 27" | `[AIOS-React]` + `calculator` + 정답 (42) |
| 5 | app_launcher | "open youtube" | `[AIOS-AppLauncher]` + 앱 실행 |

## 3. 기능 테스트 (변경 관련 시 수행)

| # | 항목 | 입력 | 검증 |
|---|------|------|------|
| 6 | 세션 생성 | 새 대화 버튼 | 빈 채팅화면 전환 |
| 7 | 세션 전환 | Drawer → 다른 세션 탭 | 이전 대화 내용 표시 |
| 8 | 세션 삭제 | 세션 스와이프/길게눌러 삭제 | 세션 목록에서 제거 |
| 9 | device_info | "내 폰 정보 알려줘" | 기기 모델/Android 버전 포함 응답 |
| 10 | timer | "30초 타이머" | 타이머 설정 응답 |
| 11 | notepad | "메모해줘 테스트" | 메모 저장 응답 |
| 12 | screen_reader | "화면에 뭐 보여" | 화면 텍스트 포함 응답 |
| 13 | 설정 진입 | 설정 버튼 | 설정 화면 표시 |
| 14 | 모델 정보 | 설정 → 모델 정보 | 모델명/컨텍스트 크기 표시 |

## 4. 심화 테스트 (필요시 수행)

| # | 항목 | 입력/시나리오 | 검증 |
|---|------|--------------|------|
| 15 | 다중 턴 대화 | 연속 질문 2-3회 | 이전 질문 컨텍스트 반영 |
| 16 | 에러 복구 | "open 없는앱이름" | 복구 응답 (크래시 없음) |
| 17 | 긴 입력 | 100자 이상 메시지 | 정상 처리 및 응답 |
| 18 | 취소 | 긴 응답 생성 중 정지 | 즉시 중단 |

## 5. adb 테스트 패턴

### UI 조작

```bash
# UI XML 덤프
adb -s {DEVICE} shell uiautomator dump /sdcard/ui.xml
adb -s {DEVICE} pull /sdcard/ui.xml /tmp/ui.xml

# 텍스트로 요소 찾아서 탭 (bounds 파싱 후 중앙 좌표 계산)
grep -oP '<node[^>]*text="TARGET"[^>]*bounds="\K[^"]+' /tmp/ui.xml
# → [x1,y1][x2,y2] → tap ((x1+x2)/2, (y1+y2)/2)
adb -s {DEVICE} shell input tap X Y

# 텍스트 입력 (스페이스 = %s)
adb -s {DEVICE} shell input text "hello"
adb -s {DEVICE} shell input text "calculate%s15%splus%s27"

# 엔터
adb -s {DEVICE} shell input keyevent 66

# 뒤로가기
adb -s {DEVICE} shell input keyevent 4
```

### 대기 패턴

```bash
# 로그 대기 (최대 N초)
adb -s {DEVICE} logcat -c  # 로그 초기화
# ... 액션 수행 ...
adb -s {DEVICE} logcat -d | grep "패턴"

# UI 텍스트 대기 (폴링)
# 2초 간격으로 uiautomator dump → grep "텍스트" 확인
```

### 권한 설정

```bash
adb -s {DEVICE} shell appops set com.agent.aios MANAGE_EXTERNAL_STORAGE allow
```

## 6. UIAutomator 제약사항

- Flutter 앱은 `resource-id` 없음 → `text`나 `bounds`로 요소 식별
- `uiautomator dump` 실행 시 앱이 1-2초 멈춤
- 다른 앱 오버레이 시 UI 덤프에 해당 앱 요소 포함 가능
- 스페이스 입력: `%s` 사용 (예: `input text "open%sfirefox"`)
- 삼성 FreecessHandler가 앱을 freeze시키면 `am force-stop` 후 재시작
