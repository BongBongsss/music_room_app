# Music Room App

음악 연습실 방 목록, 방문 예약, 계약자/결제 관리를 위한 Flutter 기반 웹/앱 프로젝트입니다.

## 운영 메모

상세 변경 이력과 검증 기록은 `README_OPERATIONS.md`에 정리합니다.

## 모바일 웹 한글 입력 이슈

2026-06-10 기준 Android Chrome 모바일 웹에서 Flutter `TextFormField`에 한글을 입력할 때 조합 중 글자 깨짐, 재포커스 후 백스페이스가 동작하지 않는 문제가 확인됐습니다.

- 신규 계약자 등록과 방문 예약 모두 기본 `TextFormField`에서도 동일하게 재현됩니다.
- `HtmlElementView`/HTML input 방식은 한글 입력과 삭제가 안정적이지만, Flutter 화면 내부에 삽입하면 Android Chrome 다크모드 영향으로 입력 배경이 검게 보이는 문제가 있었습니다.
- 현재 실험 방향은 입력 폼 화면만 Flutter 내부가 아닌 독립 HTML 문서로 분리하는 방식입니다.

### 현재 실험 대상

- `web/visit_request.html`: 독립 HTML 방문 예약 신청 페이지
- 방 상세 화면의 방문 예약 버튼은 `visit_request.html?roomId=...`로 이동합니다.
- 기존 Flutter 방문 예약 화면(`lib/screens/visit/visit_request_screen.dart`)은 비교와 롤백을 위해 유지합니다.

### 2026-06-12 확인 결과

- Samsung Internet에서도 방 상세의 방문 예약 버튼으로 독립 HTML 페이지 진입이 정상 확인됐습니다.
- Chrome에서 Flutter 메인 앱만 흰 화면이 보이는 경우가 있었고, `10.101.66.43` 사이트 데이터 삭제와 Flutter 개발 서버 재시작 후 정상 복구됐습니다.
- Chrome에서 HTML 직접 주소(`/visit_request.html?roomId=...`)는 열리는데 메인(`/`)만 흰 화면이면 네트워크 문제가 아니라 Flutter Web 캐시/개발 서버 상태 문제로 먼저 봅니다.
- `returnUrl` 쿼리를 다시 붙이지 않고, HTML 페이지는 `roomId`만 받아 처리합니다.
- HTML 상단 뒤로가기 버튼은 `roomId`가 있으면 해당 방 상세(`/#/rooms/{roomId}`)로 복귀하도록 처리했습니다.
- 단, 방 상세에서 바로 진입한 경우에는 먼저 `history.back()`을 시도해 가능한 빠르게 복귀하고, 실패 가능성이 있는 경우에만 방 상세 URL로 직접 이동합니다.
- `flutter run -d web-server` 개발 서버에서는 HTML에서 Flutter로 돌아갈 때 느릴 수 있습니다. `flutter build web --release` 후 정적 서버로 확인했을 때 복귀 속도가 더 빠르게 확인됐습니다.
- 따라서 속도 평가는 개발 서버보다 release build 기준으로 확인하는 것이 맞습니다.

### 2026-06-12 방문 예약 UI 정리

- 방 상세 화면과 방문 예약 HTML 화면 모두 우측 상단 홈 버튼을 추가했습니다.
- 방문 예약 HTML 화면의 홈 버튼과 방 상세 홈 버튼은 같은 홈 아이콘 모양으로 맞췄습니다.
- 방 상세에서 방문 예약 HTML로 이동할 때 상대 경로 대신 현재 접속 중인 IP/포트 기반 절대 URL(`/visit_request.html?roomId=...`)을 사용하도록 보완했습니다.
- 방문 예약 HTML 폼은 성함/연락처/방문 희망일/방문 희망 시간 안내 문구를 보강했습니다.
- 연락처는 입력 전 `연락처를 입력하세요`로 표시하고, 입력 중에는 `010-1234-5678` 형태로 자동 하이픈 표시합니다. 저장 값은 기존처럼 숫자만 사용합니다.
- 방문 희망일은 브라우저 기본 날짜 선택창 대신 자체 달력 모달을 사용합니다. 달력 상단에 `취소`, `설정` 버튼만 두고 `삭제` 버튼은 사용하지 않습니다.
- 예약 신청 완료 후 브라우저 기본 `alert()` 대신 자체 완료 모달을 표시합니다. 확인을 누르면 메인 방 목록으로 이동합니다.

### 로그인 ID 메모

- 현재 로그인 로직은 숫자 입력은 전화번호 계정으로, 문자 입력은 `admin@yourroom.com` 같은 관리자 ID 계정으로 처리할 수 있습니다.
- 다만 로그인 화면 UI는 아직 전화번호 중심이라 관리자 ID 입력 UX는 더 고민이 필요합니다.
- 고객 편의를 위해 휴대폰 뒤 8자리 입력은 유지하고, 관리자 ID 입력을 어떻게 노출할지는 추후 결정합니다.

## 로컬 모바일 웹 실행

```powershell
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8081
```

폰에서는 PC의 Wi-Fi IPv4 주소로 접속합니다.

```text
http://10.207.59.43:8081
```

PC의 Wi-Fi IPv4 주소는 네트워크가 바뀌면 달라집니다. 2026-06-12 확인 당시 주소는 아래였습니다.

```text
http://10.101.66.43:8081
```

release build 속도 확인용 예시:

```powershell
flutter build web --release
cd build\web
python -m http.server 8082 --bind 0.0.0.0
```

폰에서는 현재 PC IPv4 주소와 포트 `8082`로 접속합니다.

## 2026-06-10 중단 시점 메모

> 아래는 당시 중단 시점 기록입니다. 2026-06-12 기준으로는 Samsung Internet 진입이 정상 확인됐고, `returnUrl` 없이 `roomId` 기반 복귀 방식으로 보완했습니다.

방문 예약을 독립 HTML(`web/visit_request.html`)로 분리하는 실험을 진행했습니다.

현재 확인된 상태:

- 직접 접속은 동작합니다.
  - 예: `http://10.207.59.43:8081/visit_request.html?roomId=test`
- PC Chrome에서는 방 상세의 방문 예약 버튼으로 HTML 페이지 진입이 됩니다.
- 모바일 Chrome에서도 방문 예약 신청 페이지까지 이동되는 것으로 확인됐습니다.
- Samsung Internet에서는 방 상세의 방문 예약 버튼을 눌렀을 때 HTML 페이지로 진입하지 못하고 튕기는 현상이 남아 있습니다.
- 뒤로가기 버튼을 방 상세로 보내려고 `returnUrl`을 붙이는 시도를 했고, 그 시점 이후 Samsung Internet 진입 문제가 발생했습니다.
- 이후 `returnUrl` 관련 변경은 제거하고, 버튼 URL은 다시 단순한 `visit_request.html?roomId=...` 형태로 되돌렸지만 Samsung Internet 문제는 아직 남아 있습니다.

내일 이어서 볼 우선순위:

1. Samsung Internet에서 버튼 클릭 시 실제 주소창 URL 또는 콘솔 에러 확인.
2. `url_launcher(webOnlyWindowName: '_self')` 대신 실제 `<a href>` 링크 형태로 방문 예약 버튼을 렌더링하는 방식 검토.
3. 방 상세에서 HTML 페이지 이동은 먼저 안정화하고, 뒤로가기 방 상세 복귀는 그 다음 단계로 분리해서 처리.
4. HTML 폼 자체의 한글 입력/백스페이스 안정성은 직접 URL 기준으로 먼저 검증.
