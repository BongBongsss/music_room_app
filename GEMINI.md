# GEMINI.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Reference:** 
- The project's technical architecture rules are defined in:
  - Server: `server/ARCHITECTURE.md`
  - Client: `client/ARCHITECTURE.md`
- The project's testing and quality assurance policies are defined in:
  - Server: `server/TESTING_POLICY.md`
  - Client: `client/TESTING_POLICY.md`
- The project's data integrity rules are defined in:
  - Server: `server/DATA_INTEGRITY.md`
  - Client: `client/DATA_INTEGRITY.md`
- The project's error handling policies are defined in:
  - Server: `server/ERROR_HANDLING.md`
  - Client: `client/ERROR_HANDLING.md`

Gemini must adhere to these principles in all code changes.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## 5. Platform Compatibility & Environment Integrity

**Technically mitigate the gap between development (Windows) and deployment (Linux) environments.**

- **OS Differences**: Adhere to case-sensitivity in file systems (Linux) and consistently use lowercase/kebab-case for file and directory paths.
- **Dependency Integrity**: When specific platform binaries (e.g., `esbuild`, `rollup`, `prisma`) are required for deployment (Vercel, Render), explicitly include them in `package.json` or pin versions to prevent environment mismatches.
- **Pre-build Validation**: Always run `npx tsc --noEmit` before every `git push` to pre-verify type-level compatibility and prevent build failures.

## 6. Documentation Integrity

**Maintain project knowledge and traceability through rigorous documentation.**

- **Mandatory Revision History**: When modifying any `.md` files (guidelines, design docs, etc.), always update or add a "개정 이력 (Revision History)" section at the end of the file.
- **Content of History**: Each entry must include the **date of modification** and a detailed **reasoning/background** for the change.
- **Language Policy**: While the main content of guidelines should be in **English** for technical consistency, the Revision History must be written in **Korean** for better accessibility and clarity for the developer.

---

## 7. Interactive Safety & Accountability

**Always explain, then wait for explicit approval.**

- **No Unauthorized Edits**: Never modify any code files until the user has provided explicit confirmation (e.g., "Yes", "Proceed") for a specific proposed plan.
- **Beginner-Friendly Explanations**: Before any change, explain the root cause of the issue and the proposed solution in simple terms that a non-technical user can understand.
- **Strict Verification**: When adding or modifying functions, rigorously verify that existing methods in the same file are preserved and not accidentally overwritten.

---

## 개정 이력 (Revision History)

- **2026-05-29**: "7. Interactive Safety & Accountability" 섹션 추가.
  - **사유**: AI가 사용자의 승인 없이 독단적으로 코드를 수정하거나 기존 기능을 실수로 삭제하는 것을 방지하기 위해 '설명 후 승인 대기' 원칙을 명문화함.

- **2026-05-14**: "6. Documentation Integrity" 섹션 추가.
  - **사유**: 프로젝트의 지속적인 유지보수와 지식 보존을 위해 모든 문서 수정 시 개정 이력을 의무적으로 남기는 원칙을 수립함. 언어 정책(본문 영문, 이력 국문)을 명문화함.
- **2026-05-14**: "5. Platform Compatibility & Environment Integrity" 섹션 추가.
  - **사유**: Windows 개발 환경에서 정상 동작하던 코드가 Render/Vercel(Linux) 배포 시 Prisma 버전 불일치 및 플랫폼별 빌드 바이너리(`rollup`, `esbuild`) 누락으로 인해 반복적인 배포 실패를 겪음. 이를 시스템적으로 방지하기 위해 환경 통합 및 사전 검증 원칙을 명문화함.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.


# 프로젝트 개요
음악연습실 월 단위 임대 관리 앱.
고객은 공실 룸을 조회하고 방문 예약을 신청한다.
운영자는 룸 현황, 방문 예약, 계약, 납부를 관리한다.
시간 단위 예약 없음. 월 단위 계약만 존재.

---

# 기술 스택
- **프레임워크**: Flutter (iOS / Android)
- **백엔드**: Firebase (Firestore, Auth) Cloud Functions 미사용(무료 플랜)
- **상태관리**: Riverpod
- **라우팅**: go_router
- **이미지**: cached_network_image
- **외부 링크**: url_launcher (카카오맵, 네이버맵, 카카오톡 오픈채팅)
- **알림**: flutter_local_notifications (로컬 푸쉬, 수동 발송)
- **날짜/금액 포맷**: intl
- **차트**: fl_chart (납부 통계)

---

# 사용자 역할

- `customer` - 고객. 룸 조회, 방문 예약, 납부 내역 확인
- `admin` - 운영자. 전체 관리 기능

Firebase Auth 로그인 후 Firestore users/{uid}.role 값으로 역할 분기.

# 인증 구조

## 비로그인 접근 가능 (누구나)
- 룸 목록 조회
- 룸 상세 조회
- 방문 예약 신청 (이름 + 연락처만 입력, 계정 불필요)
- 위치 안내
- 카카오톡 오픈채팅 바로가기

## 로그인 필요 (customer)
- 납부 내역 조회
- 계약 정보 확인
- 납부일 알림 설정

## 로그인 필요 (admin)
- 운영자 기능 전체

# 계정 생성 방식
- 고객 계정은 운영자가 계약 시 직접 생성 (Firebase Auth 이메일 + 임시 비밀번호)
- 고객은 첫 로그인 후 비밀번호 변경
- 관리자 계정은 Firebase Console에서 직접 생성 (앱 내 생성 기능 없음)
- 소셜 로그인 없음 (추후 카카오 로그인 추가 가능)
- 고객 자체 회원가입하는 기능 없음

---

# 폴더 구조

```
lib/
  main.dart
  firebase_options.dart
  core/
     router.dart        # go_router 라우트 정의
     theme.dart         # 앱 테마
  models/
     room.dart          # Firestore 데이터 모델 (fromMap/toMap 포함)
     user_model.dart
     visit.dart
     contract.dart
     payment.dart
  services/            # Firestore CRUD (화면에서 직접 Firestore 호출 금지)
     auth_service.dart
     room_service.dart
     visit_service.dart
     contract_service.dart
     payment_service.dart
  screens/
     home/
     rooms/
     visit/
     mypage/
     auth/              # 로그인/비밀번호 변경
     admin/
  widgets/
     common/
```

---

# Firestore 컬렉션 요약

| 컬렉션 | 설명 |
|--------|------|
| `rooms` | 룸 정보 (크기, 가격, 사진, 상태) |
| `users` | 사용자 정보 및 역할 |
| `visits` | 방문 예약 신청 |
| `contracts` | 월 단위 임대 계약 |
| `payments` | 월 납부 내역 |
| `notices` | 공지사항 |
| `settings/info` | 연습실 정보 (주소, 계좌, 지도 링크 등) |

상세 스키마는 'music_room_app_design.md' 참조.

---

# 코딩 규칙

1. **Firestore 호출은 services/에서만** - 화면(screen)에서 직접 Firestore 접근 금지
2. **Riverpod Provider 사용** - setState 사용 금지, 상태는 모두 Provider로 관리
3. **null safety 철저히 준수** - '!' 강제 언래핑 사용 금지, 항상 null 체크 또는 기본값 처리
4. **에러 처리 항상 포함** - 모든 async 함수에 try/catch 작성
5. **빈 상태 처리** - 리스트가 비었을 때 빈 화면 대신 안내 메시지 표시
6. **네트워크 오류 처리** - 로딩 중, 오류, 데이터 없음 세 가지 상태 항상 처리
7. **한국어 UI** - 모든 텍스트는 한국어로 작성
8. **금액 포맷** - intl 패키지로 `300,000원` 형식으로 표시
9. **날짜 포맷** - `yyyy년 MM월 dd일` 형식 사용

---

# 주요 status 값

**rooms.status**
- `vacant` - 공실
- `occupied` - 계약중

**users.status**
- `active` - 활성
- `inactive` - 비활성 (계약 종료 시 로그인 차단)

**visits.status**
- `pending` - 신청 대기
- `confirmed` - 확정
- `cancelled` - 취소
- `completed` - 방문 완료

**contracts.status**
- `active` - 계약중
- `expired` - 만료
- `terminated` - 해지

**payments.status**
- `unpaid` - 미납
- `paid` - 납부완료
- `overdue` - 연체

---

# 참조 문서
- 상세 DB 스키마 및 화면 구조 -> `@music_room_app_design.md`
