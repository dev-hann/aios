# AIOS UI/UX 개선 사항

## Critical (현재 버그)

### 1. 채팅 인풋이 바텀 네비게이션에 가려짐
- **문제**: Scaffold의 bottomBar와 InputBar가 겹쳐서 입력창이 네비게이션 바 뒤에 숨겨짐
- **원인**: ChatScreen이 자체 Column 레이아웃을 사용하면서 Scaffold의 innerPadding을 무시함
- **해결**: ChatScreen을 Scaffold 내부에 넣거나, bottomBar 높이만큼 하단 패딩 추가

### 2. 상단 앱바 레이아웃 이상
- **문제**: TopBar가 Scaffold 외부에 있어서 status bar 영역과 겹침
- **원인**: ChatScreen이 직접 statusBarsPadding()을 처리하려고 함
- **해결**: Scaffold의 topBar 슬롯 사용, 또는 TopBar를 proper AppBar로 교체

### 3. 채팅 화면 전체 레이아웃 불안정
- **문제**: 메시지 리스트와 인풋바의 비율이 깨짐
- **원인**: Box(weight=1f) + 하단 InputBar 구조가 네비게이션 바 고려 못함
- **해결**: 전체를 Scaffold로 감싸고 적절한 padding 적용

---

## Design Improvements

### Top App Bar
- [ ] 로고 + 앱 이름 좌측 정렬 (현재: Row로 나란히 있으나 간격 이상)
- [ ] 상태 표시를 TopBar 하단에 작은 선/인디케이터로 표시
- [ ] Agent/Chat 토글을 더 직관적인 Pill/Segment 형태로 변경
- [ ] 모델 선택 버튼을 더 눈에 띄게 (아이콘 + 텍스트 "Model")
- [ ] 모델 로드 상태를 TopBar에 작게 표시 (모델명 등)

### Chat Input Area
- [ ] 바텀 네비게이션 위에 안전하게 배치
- [ ] 입력 필드 높이 축소 (더 컴팩트하게)
- [ ] 전송 버튼을 입력 필드 내부 우측에 배치 (인라인 스타일)
- [ ] 글자 수 / 토큰 카운터 표시 (선택적)
- [ ] 멀티라인 입력 시 자동 확장 (최대 4줄)

### Message Bubbles
- [ ] 유저 메시지: 우측 정렬, 보라색 그라디언트 배경 ✅ (현재 적용됨)
- [ ] AI 메시지: 좌측 정렬, 다크 카드 배경 + 아바타 ✅
- [ ] Agent 단계별 메시지: 더 명확한 구분 필요
  - Thought: 아이콘 + 연보라 배경
  - Action: 아이콘 + 주황 배경 + 도구명 태그
  - Observation: 접을 수 있는(collapsible) 코드 블록 스타일
- [ ] 메시지 간 간격 조정 (너무 촘촘함)
- [ ] 타임스탬프 표시 (선택적)

### Empty State (모델 미선택 시)
- [ ] 현재: 아이콘 + 텍스트만 있음
- [ ] 개선: 애니메이션 + "시작하기" 버튼 + 간단한 온보딩

### Bottom Navigation
- [ ] 현재: 기본 Row로 직접 구현
- [ ] 개선: NavigationBar 위에 살짝 떠 있는 카드 스타일 (floating)
- [ ] 또는: 채팅 화면에서는 네비게이션 숨기기 (풀스크린 모드)

### Dashboard (Control 화면)
- [ ] 권한 카드에 프로그레스 바 표시 (3개 중 2개 완료 등)
- [ ] 전체 권한 상태를 상단에 큰 인디케이터로 표시
- [ ] 빠른 액션 버튼 (오버레이 토글) 스위치 형태로 변경

### Settings
- [ ] 모델 관리를 더 풍부하게 (다운로드 진행률, 모델 정보 카드)
- [ ] 섹션 헤더 스타일링 개선

### Animation & Micro-interactions
- [ ] 메시지 등장 시 fade-in + slide-up 애니메이션
- [ ] 전송 버튼 클릭 시 리플 효과
- [ ] 모델 로딩 시 스켈레톤 UI 또는 프로그레스 애니메이션
- [ ] Agent 실행 중 typing indicator (3개 점 바운스)

### Color & Typography
- [ ] 다크 테마 기본 ✅
- [ ] 색상 대비 높이기 (일부 텍스트가 너무 흐림)
- [ ] 코드/테크니컬 텍스트에 Monospace 폰트 명확히 적용
- [ ] 폰트 크기 계층 더 명확히 (제목 20sp → 부제 16sp → 본문 14sp)

### Responsive Layout
- [ ] IME (키보드) 올라올 때 채팅 입력창이 키보드 위에 정렬
- [ ] 시스템 네비게이션 바 인셋 처리
- [ ] 상태바 인셋 처리
