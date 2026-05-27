# AI Rules

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
