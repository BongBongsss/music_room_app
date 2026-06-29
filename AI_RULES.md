# AI Rules

## 최우선 제한
1. 이 프로젝트에서 CODEX는 코드를 직접 수정하지 않는다.
2. CODEX는 항상 Gemini CLI에 전달할 수정 프롬프트만 작성한다.
3. 파일 편집, 패치 적용, 리팩터링, 테스트 코드 수정은 직접 수행하지 않는다.
4. 리뷰, 원인 분석, 수정안 정리, 검증 절차 안내까지만 수행한다.

## 상태관리 규칙
1. `flutter_riverpod`를 사용한다.
2. 기존 Provider 구조를 깨지 않는다.
3. `ref.watch` 사용을 최소화한다.
4. 불필요한 rebuild를 만들지 않는다.
5. async 상태는 `AsyncValue` 패턴을 유지한다.
6. Provider 타입을 용도에 맞게 구분한다 (`Provider`, `StateNotifierProvider`, `FutureProvider` 등).
7. 이벤트 핸들러에서는 `ref.read`, UI 반응이 필요한 곳에서만 `ref.watch`를 사용한다.
8. 파생 상태 구독 시 전체 상태 대신 `select`를 우선 사용한다.
9. 비동기 상태 UI는 `AsyncValue.when`으로 loading/error/data를 모두 처리한다.
10. Provider별 `autoDispose` 사용 여부를 생명주기에 맞춰 명확히 유지한다.

## 리뷰 작업 규칙
1. CODEX는 리뷰 진행 시 자체적으로 코드를 수정하지 않는다.
2. CODEX는 Gemini CLI에게 요청할 상세 프롬프트를 작성한다.
3. 프롬프트에는 코드 변경 내용(수정 파일, 변경 전후 핵심 코드, 검증 방법)을 반드시 포함한다.

## 방문 예약 HTML 작업 규칙
1. 모바일 한글 입력 문제 때문에 방문 예약 입력 폼은 Flutter `TextFormField`가 아닌 `web/visit_request.html` 독립 HTML 폼을 우선 유지한다.
2. 방문 예약 HTML 진입 URL은 `visit_request.html?roomId=...` 형태를 유지하고, `returnUrl` 쿼리는 재도입하지 않는다.
3. 방 상세 복귀는 `roomId` 기반으로 처리한다. Flutter 해시 라우팅(`#/rooms/...`) 전체를 쿼리로 넘기지 않는다.
4. HTML에서 Flutter로 돌아가는 속도 평가는 `flutter run` 개발 서버가 아니라 release build 기준으로 판단한다.
5. Chrome에서 메인 화면만 흰 화면이고 HTML 직접 주소는 열리면, 코드 문제보다 Chrome 사이트 데이터/Flutter Web 캐시/개발 서버 상태를 먼저 의심한다.
6. 방문 예약 완료/날짜 선택 같은 팝업은 브라우저 기본 `alert()`나 native date picker에 의존하지 말고, 브라우저별 UI 차이를 줄이기 위해 자체 HTML 모달을 사용한다.
