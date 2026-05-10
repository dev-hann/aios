# Build Guide

AIOS 빌드 및 실행 가이드 (Gyo Framework 기반).

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Node.js | 18.0+ | 권장: 24.x |
| npm | 9.0+ | Node.js에 포함 |
| Android Studio | Hedgehog+ | Android 빌드 시 |
| Android SDK | API 24+ | Android 빌드 시 |
| JDK | 11+ | Android 빌드 시 |
| Gyo CLI | latest | `npm install -g @gyo-framework/cli` |

## Development

### 브라우저에서 개발

```bash
cd lib
npm install
npm run dev
# http://localhost:3000 에서 실행
```

### 기기에서 개발

```bash
# 기기 연결 확인
adb devices

# Gyo 개발 모드 (Vite 서버 + APK 설치 + 실행)
gyo run
```

## Build

```bash
# 웹 에셋 빌드
cd lib && npm run build

# Android APK 빌드
gyo build android

# APK 위치: android/app/build/outputs/apk/
```

## Commands

| 명령어 | 설명 |
|--------|------|
| `npm run dev` | Vite 개발 서버 시작 |
| `npm run build` | 프로덕션 빌드 |
| `npm run type-check` | TypeScript 타입 체크 |
| `npm run test` | Vitest 테스트 실행 |
| `npm run verify` | 타입체크 + 테스트 + 빌드 |
| `npm run lint` | ESLint 실행 |

## Configuration

`gyo.config.json`에서 프로젝트 설정:

```json
{
  "profiles": {
    "development": { "serverUrl": "http://localhost:3000" },
    "production": { "serverUrl": "https://your-url.com" }
  },
  "platforms": {
    "android": { "enabled": true, "packageName": "com.agent.aios" }
  }
}
```

## Troubleshooting

### Gyo CLI not found

```bash
cd /path/to/gyo/cli && npm install -g .
```

### Vite 서버 접근 불가

- `0.0.0.0` 바인딩 확인 (vite.config.ts의 server.host)
- 방화벽에서 포트 3000 허용
- 기기와 같은 네트워크 연결 확인
