# AIOS Device Testing

기기 테스트 시 AGENTS.md §0의 기기 명령어와 아래 테스트를 조합하여 수행한다.

## 1. adb 수동 스모크 (빌드 후 필수)

빌드→설치 후 **반드시** 전부 확인:

| # | 항목 | 입력 | 통과 기준 (logcat) |
|---|------|------|-------------------|
| 1 | 앱 실행 | 설치 후 실행 | 크래시 없음, `[vite] connected.` 또는 `[AIOS]` 로그 |
| 2 | 기본 응답 | "hello" | `[AIOS-React]` + 응답 텍스트 |
| 3 | calculator | "calculate 15 plus 27" | `[AIOS-React]` + `calculator` + 정답 (42) |
| 4 | notepad | "메모해줘 테스트" | `[AIOS-React]` + `notepad` + 저장 응답 |
| 5 | timer | "30초 타이머" | `[AIOS-React]` + `timer` + 설정 응답 |

### 기본 adb 테스트 절차

```bash
# 0. Vite 개발 서버 시작 (기기에서 접근 가능해야 함)
cd lib
nohup npx vite --host 0.0.0.0 --port 3000 --strictPort > /tmp/vite-server.log 2>&1 &

# 1. APK 빌드
bash /tmp/gyo build android

# 2. 설치
adb -s {DEVICE} uninstall com.agent.aios
adb -s {DEVICE} install android/app/build/outputs/apk/debug/app-debug.apk

# 3. 실행
adb -s {DEVICE} shell am start -n com.agent.aios/.MainActivity

# 4. 로그 확인 (WebView 콘솔)
adb -s {DEVICE} logcat -d | grep "WebView-Console"

# 5. AIOS 전용 로그
adb -s {DEVICE} logcat -d | grep "\[AIOS-"

# 6. 스크린샷으로 UI 확인
adb -s {DEVICE} shell screencap -p /sdcard/screen.png
adb -s {DEVICE} pull /sdcard/screen.png /tmp/screen.png
```

## 2. 기능 테스트 (변경 관련 시 수행)

| # | 항목 | 입력 | 검증 |
|---|------|------|------|
| 6 | 세션 생성 | 새 대화 버튼 | 빈 채팅화면 전환 |
| 7 | 세션 전환 | Drawer → 다른 세션 탭 | 이전 대화 내용 표시 |
| 8 | 세션 삭제 | 세션 삭제 버튼 | 세션 목록에서 제거 |
| 9 | SSE 스트리밍 | 긴 질문 | 토큰 단위 스트리밍 응답 |
| 10 | 에러 복구 | "open 없는앱이름" | 복구 응답 (크래시 없음) |
| 11 | 긴 입력 | 100자 이상 메시지 | 정상 처리 및 응답 |
| 12 | 취소 | 긴 응답 생성 중 정지 | 즉시 중단 |

## 3. 심화 테스트 (필요시 수행)

| # | 항목 | 입력/시나리오 | 검증 |
|---|------|--------------|------|
| 13 | 다중 턴 대화 | 연속 질문 2-3회 | 이전 질문 컨텍스트 반영 |
| 14 | multi-tool | "계산하고 메모해줘" | calculator → notepad 순차 실행 |
| 15 | 세션 영속성 | 앱 재시작 | 이전 대화 내용 보존 |
| 16 | 네트워크 오류 | 비행기 모드 | 에러 메시지 표시 (크래시 없음) |

## 4. Gyo WebView 디버깅

```bash
# Chrome DevTools로 WebView 디버깅
chrome://inspect/#devices

# 콘솔 로그 확인 (WebView Console)
adb -s {DEVICE} logcat -d | grep "WebView-Console"

# AIOS 앱 로그
adb -s {DEVICE} logcat -d | grep "\[AIOS-"

# Vite HMR 연결 확인
adb -s {DEVICE} logcat -d | grep "vite"

# Gyo Bridge / 네이티브 로그
adb -s {DEVICE} logcat -d | grep "AIOS-Main"

# UI XML 덤프 (네이티브 레벨)
adb -s {DEVICE} shell uiautomator dump /sdcard/ui.xml
adb -s {DEVICE} pull /sdcard/ui.xml /tmp/ui.xml
```

## 5. UIAutomator 제약사항

- WebView 기반 앱은 `uiautomator`로 내부 DOM 접근 불가
- Chrome DevTools 원격 디버깅으로 WebView 내부 요소 검사
- `uiautomator dump`는 WebView 컨테이너만 표시
- 스크린샷 + 시각 검증이 주된 UI 테스트 방법

## 6. Chrome DevTools Protocol (CDP) 화면 검증

> **참고**: CDP 원시 접근은 Playwright로 대체되었습니다. 아래 §8 참조.

## 7. 주요 로그 태그

| 태그 | 소스 | 의미 |
|------|------|------|
| `[AIOS-React]` | react-strategy.ts | 에이전트 실행 로그 |
| `[AIOS-Chat]` | chat-store.ts | 상태 관리, 세션 초기화 |
| `[AIOS-OpenAiClient]` | openai-client.ts | LLM API 통신 |
| `[AIOS-LlmSession]` | session.ts | 세션 관리, tool call |
| `[AIOS-Main]` | MainActivity.kt | 네이티브 앱 로그 |
| `[vite]` | Vite HMR client | HMR 연결 상태 |
| `WebView-Console` | WebView | 브라우저 콘솔 출력 |

## 8. Playwright E2E 기기 테스트

Playwright를 통해 Android WebView에 CDP로 연결하여 E2E 테스트를 실행한다.

```bash
# 전제조건: 앱 실행 + Vite dev server 실행 중

# 전체 E2E 실행 (기기 연결 시)
cd lib && npm run test:e2e

# 단일 스펙만 실행
npx playwright test e2e/chat.spec.ts

# 헤드ed 모드 (디버깅용)
npx playwright test --headed
```

### 테스트 구성

| 파일 | 테스트 수 | 내용 |
|------|----------|------|
| `e2e/chat.spec.ts` | 4 | 채팅 렌더링, 메시지 전송, calculator/notepad tool |
| `e2e/settings.spec.ts` | 10 | 설정 렌더링, NavTile 라우팅, 동적 subtitle |
| `e2e/inference.spec.ts` | 7 | 슬라이더, 기본값 복원, 값 입력 다이얼로그 |
| `e2e/permissions.spec.ts` | 4 | 6개 권한 카드, banner, grant 버튼 |
| `e2e/provider.spec.ts` | 6 | 5개 Provider, 라디오 선택, Base URL 토글 |

### 아키텍처

```
Playwright → connectOverCDP(localhost:9222)
  → adb forward tcp:9222 → webview_devtools_remote_{PID}
    → Android WebView → Vite HMR (192.168.0.7:3000)
```

- `e2e/global-setup.ts`: adb forward + 앱 PID 확인
- `e2e/global-teardown.ts`: adb forward 제거
- `e2e/device.fixture.ts`: Playwright 커스텀 fixture (connectOverCDP, storeAction)
- `window.__aios` store bridge로 Zustand 상태 직접 조작 가능
