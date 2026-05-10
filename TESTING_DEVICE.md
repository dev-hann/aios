# AIOS Device Testing

기기 테스트 시 AGENTS.md §0의 기기 명령어와 아래 테스트를 조합하여 수행한다.

## 1. Widget Test 스모크 (기기 불필요)

`flutter test test/presentation/smoke/` 로 실행. 모든 주요 화면의 SemanticsLabel을 검증:

| 파일 | 테스트 수 | 항목 |
|------|----------|------|
| `chat_smoke_test.dart` | 5 | drawer, new_conversation, settings 버튼, text input, drawer 열기 |
| `settings_smoke_test.dart` | 3 | add_model, inference_tile, permissions_tile, check_updates 버튼 |
| `add_model_smoke_test.dart` | 3 | scan_button, import_section, title |

각 테스트는 `find.bySemanticsLabel()` 또는 `find.byWidgetPredicate((w) => w is Semantics && w.properties.label == ...)` 로
접근성 라벨이 올바르게 노출되는지 확인한다.

### SemanticsLabel 목록

| 화면 | Label | 위젯 |
|------|-------|------|
| Chat | `drawer_open_menu` | 햄버거 아이콘 |
| Chat | `new_conversation_button` | 새 대화 아이콘 |
| Chat | `settings_button` | 설정 아이콘 |
| Chat | `chat_input_textfield` | 텍스트 입력 |
| Chat | `chat_send_button` | 전송 버튼 |
| Chat | `chat_stop_button` | 정지 버튼 |
| Chat | `clear_chat_cancel_button` | 채팅 삭제 취소 |
| Chat | `clear_chat_confirm_button` | 채팅 삭제 확인 |
| Chat | `tool_confirm_deny_button` | Tool 승인 거부 |
| Chat | `tool_confirm_approve_button` | Tool 승인 승인 |
| Chat | `loading_indicator_{phase}` | 로딩 상태 |
| Drawer | `drawer_new_chat_button` | 새 대화 버튼 |
| Drawer | `drawer_settings_tile` | 설정 타일 |
| Drawer | `conversation_item_{id}` | 대화 항목 |
| Drawer | `conversation_delete_button` | 대화 삭제 |
| Drawer | `delete_conversation_cancel_button` | 삭제 취소 |
| Drawer | `delete_conversation_confirm_button` | 삭제 확인 |
| Settings | `add_model_button` | 모델 추가 버튼 |
| Settings | `settings_inference_tile` | 추론 설정 타일 |
| Settings | `settings_permissions_tile` | 권한 관리 타일 |
| Settings | `check_for_updates_button` | 업데이트 확인 버튼 |
| AddModel | `model_scan_button` | 스캔 버튼 |
| AddModel | `model_tile_{name}` | 모델 항목 |
| AddModel | `model_import_button_{name}` | 모델 가져오기 버튼 |
| Inference | `inference_reset_defaults_button` | 기본값 복원 버튼 |
| Permissions | `permission_grant_{title}` | 권한 부여 버튼 |

## 2. 자동화된 통합 테스트 (기기 필요)

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
| `smoke/semantics_smoke_test.dart` | SemanticsLabel 기기 검증 |

## 3. adb 수동 스모크 (빌드 후 필수)

빌드→설치 후 **반드시** 전부 확인:

| # | 항목 | 입력 | 통과 기준 (logcat) |
|---|------|------|-------------------|
| 1 | 앱 실행 | 설치 후 실행 | 크래시 없음, `[AIOS-ChatNotifier] Session initialized` |
| 2 | 모델 로드 | 설정 → Load | `[AIOS-RealEngine] Model loaded` |
| 3 | 기본 응답 | "hello" | `[AIOS-React]` + 응답 텍스트 |
| 4 | calculator | "calculate 15 plus 27" | `[AIOS-React]` + `calculator` + 정답 (42) |
| 5 | app_launcher | "open youtube" | `[AIOS-AppLauncher]` + 앱 실행 |

### adb 패턴 (디버깅용)

```bash
# UI XML 덤프
adb -s {DEVICE} shell uiautomator dump /sdcard/ui.xml
adb -s {DEVICE} pull /sdcard/ui.xml /tmp/ui.xml

# content-desc 기반 탭 (SemanticsLabel이 content-desc로 노출됨)
grep -oP '<node[^>]*content-desc="drawer_open_menu"[^>]*bounds="\K[^"]+' /tmp/ui.xml
# → [x1,y1][x2,y2] → tap ((x1+x2)/2, (y1+y2)/2)
adb -s {DEVICE} shell input tap X Y

# 텍스트 입력
adb -s {DEVICE} shell input text "hello"

# 엔터 / 뒤로가기
adb -s {DEVICE} shell input keyevent 66
adb -s {DEVICE} shell input keyevent 4
```

## 4. 기능 테스트 (변경 관련 시 수행)

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

## 5. 심화 테스트 (필요시 수행)

| # | 항목 | 입력/시나리오 | 검증 |
|---|------|--------------|------|
| 15 | 다중 턴 대화 | 연속 질문 2-3회 | 이전 질문 컨텍스트 반영 |
| 16 | 에러 복구 | "open 없는앱이름" | 복구 응답 (크래시 없음) |
| 17 | 긴 입력 | 100자 이상 메시지 | 정상 처리 및 응답 |
| 18 | 취소 | 긴 응답 생성 중 정지 | 즉시 중단 |

## 6. UIAutomator 제약사항

- Flutter 앱은 `resource-id` 없음 → `content-desc` (SemanticsLabel) 또는 `text`/`bounds`로 요소 식별
- SemanticsLabel이 설정된 요소는 `content-desc` 속성으로 노출됨
- `uiautomator dump` 실행 시 앱이 1-2초 멈춤
- 다른 앱 오버레이 시 UI 덤프에 해당 앱 요소 포함 가능
- 스페이스 입력: `%s` 사용 (예: `input text "open%sfirefox"`)
- 삼성 FreecessHandler가 앱을 freeze시키면 `am force-stop` 후 재시작
