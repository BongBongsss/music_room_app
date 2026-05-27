# 음악연습실 앱 설계 문서
> Gemini CLI 개발 + Codex 코드리뷰 기준

---

## 1. 프로젝트 개요

| 항목 | 내용 |
|-------|------|
| 서비스명 | (연습실 이름 입력) |
| 형태 | Flutter 모바일 앱 (ios / Android) |
| 백엔드 | Firebase (Firestore +Auth + Cloud Functions) |
| 결제 | 계좌이체 (추후 포트원 정기결제 추가 가능) |
| 대상 | 월 단위 임대 계약 고객 + 운영자 |

---

## 2. Firesotre DB 스키마

### 컬렉션 구조

```
/rooms/{roomID}
/users/{userId}
/visits/{visitId}
/contracts/{contractId}
/payments/{paymentId}
/notices/{noticeId}
/settings/info
```

---

### rooms (룸 정보)

```json
{
  "roomId": "room_01",
  "name": "A호실",
  "size": 10,
  "sizeUnit": "m^2",
  "price": 300000,
  "priceUnit":"원",
  "description": "방음 완비",
  "photos": ["https://...jpg", "https://...jpg"],
  "features": ["방음", "에어컨", "드럼킷 포함"],
  "status": "vacant",
  "floor": "B1",
  "adminMemo": "청소필요",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

> staus 값: `vacant` (공실) / `occupied` (계약중)
> adminMemo: 운영자만 볼 수 있는 내부 메모. 고객에게 노출 안 됨

---

### users (사용자)

```json
{
  "userId": "uid_abc123",
  "name": "홍길동",
  "phone": "010-1234-5678",
  "loginEmail": "01012345678@yourroom.com",
  "role": "customer",
  "staus": "active",
  "contractId": "contract_01",
  "isFirstLogin": true,
  "createdAt": "timestamp",
  "updateAt": "timestamp"
} 
```

> role 값: `customer` / `admin`
> status 값: `active` (활성) / `inactive` (비활성화 - 계약 종료 시)

---

## visits (방문 예약)

```json
{
  "visitId": "visit_01",
  "userId": "uid_abc123",
  "userName": "홍길동",
  "userPhone": "010-0000-0000",
  "roomId": "room_01",
  "visitDate": "2025-06-10",
  "visitTime": "14:00",
  "status": "pending",
  "memo": "드럼 연습 목적으로 문의",
  "createdAt": "timestamp"
}
```

> status 값: 'pending' (대기) / 'confirmed' (확정) / 'cancelled' (취소) / 'completed' (완료)

---

## contracts (계약 정보)

```json
{
  "contractId": "contract_01",
  "userId": "uid_abc123",
  "roomId": "room_01",
  "startDate": "2025-06-01",
  "endDate": "2026-05-31",
  "monthlyFee": 300000,
  "paymentDueDate": 5,
  "paymentMethod": "계좌이체",
  "status": "active",
  "memo": "",
  "createdAt": "timestamp"
}
```

> status 값: 'active' (계약중) / 'expired' (만료) / 'terminated' (해지)

---

## payments (납부 내역)

```json
{
  "paymentId": "pay_202506",
  "contractId": "contract_01",
  "userId": "uid_abc123",
  "roomId": "room_01",
  "amount": 300000,
  "dueDate": "2025-06-05",
  "paidDate": "2025-06-04",
  "status": "paid",
  "memo": "6월 월세"
}
```

> status 값: 'unpaid' (미납) / 'paid' (납부완료) / 'overdue' (연체)

----

## settings/info (연습실 기본 정보)

```json
{
  "name": "OO 음악연습실",
  "address": "서울시 OO구 OO동 OO번지",
  "lat": 37.1234,
  "lng": 127.1234,
  "phone": "010-0000-0000",
  "kakaoOpenChatUrl": "https://open.kakao.com/o/xxxx",
  "kakaoMapUrl": "https://kko.to/xxxxx",
  "naverMapUrl": "https://naver.me/xxxxx",
  "bankName": "국민은행",
  "bankAccount": "000-0000-0000",
  "bankHolder": "홍길동",
  "businessHours": "09:00 ~ 22:00",
  "visitAvailableDays": [1, 2, 3, 4, 5],
  "visitStartTime": "09:00",
  "visitEndTime": "21:00",
  "updatedAt": "timestamp"
}
```

> visitAvailableDays: 방문 예약 가능 요일 (0=일, 1=월, 2=화, 3=수, 4=목, 5=금, 6=토)
> visitStartTime / visitEndTime: 방문 예약 가능 시간 범위

---

## notices (공지사항)

```json
{
  "noticeId": "notice_01",
  "title": "6월 휴무 안내",
  "content": "6월 6일 현충일은 휴무입니다.",
  "isPinned": true,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

> isPinned: 상단 고정 여부

---

## 3. 인증 구조

| 기능 | 비로그인 | customer | admin |
| :--- | :---: | :---: | :---: |
| 룸 목록 조회 | O | O | O |
| 룸 상세 조회 | O | O | O |
| 룸 정보 수정 | X | X | O |
| 방문 예약 신청 | O (이름+연락처만) | O | O |
| 위치 안내 | O | O | O |
| 카카오톡 오픈채팅 | O | O | O |
| 공지사항 조회 | O | O | O |
| 공지사항 관리 | X | X | O |
| 납부 내역 조회 | X | O | O |
| 계약 정보 확인 | X | O | O |
| 납부일 알림 설정 | X | O | O |
| 비밀번호 찾기 | O | O | O |
| 운영자 기능 전체 | X | X | O |

### 계정 생성 방식
- 고객 자체 회원가입 없음
- 로그인 ID: 전화번호를 이메일 형식으로 사용 (010-1234-5678 -> 01012345678@yourroom.com)
- 운영자가 계약 등록 시 고객 이름 + 전화번호 + 임시 비밀번호 입력
- Firebase Auth 계정 자동 생성 후 임시 비밀번호 화면에 표시 + 복사 버튼
- 운영자가 카카오톡으로 고객에게 직접 전달 (전화번호 + 임시 비밀번호)
- 고객 첫 로그인 후 비밀번호 변경 화면으로 자동 이동
- 관리자 계정은 Firebase Console에서 직접 생성 (앱 내 생성 기능 없음)

### 계약 종료 시 계정 처리
- 완전 삭제 아닌 비활성화 방식 사용 (납부 내역, 계약 이력은 보존)
- 운영자가 계약 해지/만료 처리 시 자동으로 아래 항목 일괄 처리

```
contracts/{id}  status -> terminated / expired
rooms/{id}      status -> vacant
users/{uid}     status -> inactive
Firebase Auth   계정 비활성화 (로그인 차단)
```

- 재계약 시 운영자가 앱에서 계정 재활성화 + 새 계약 등록

### 관리자 계정 최초 생성 절차 (Firebase Console)

```
1. Firebase Console -> Authentication -> 사용자 추가 
   이메일: admin@yourroom.com
   비밀번호: (강력한 비밀번호 설정)

2. 생성된 uid 복사

3. Firebase Console -> Firestore -> users 컬렉션에 문서 추가
   문서 ID: (복사한 uid)
   필드: 
   - role: "admin"
   - name: "관리자"
   - status: "active"
   - isfirstlogin: false
   - createdAt: (현재 timestamp)
```

> 관리자 계정은 코드로 생성하지 않음. Firestore 보안 규칙에서 admin role 생성을 앱에서 차단할 것.

---

## 4. 화면 구조 (앱 네비게이션)

### 고객 앱

```
- 홈 (비로그인 접근 가능)
  - 룸 목록 (공실/계약중 표시)
     - 룸 상세 (사진, 크기, 가격, 특징)
       - 방문 예약 신청 (이름 + 연락처만 입력)
  - 공지사항 (운영자 등록한 공지 목록)
  - 위치 안내 (카카오맵 / 네이버맵 연동)
  - 카카오톡 오픈채팅 바로가기
  - 마이페이지
    - 비로그인 상태 → 로그인 화면으로 이동
    - 로그인 상태 -> 계약정보, 납부내역, 알림설정, 비밀번호 변경

- 로그인 화면
  - 전화번호 + 비밀번호 입력
  - 비밀번호 찾기 (Firebase 비밀번호 재설정 이메일 발송)
  - 첫 로그인 시 비밀번호 변경 화면으로 자동 이동
```

### 운영자 앱

```
- 로그인 화면 (admin 계정)
  - 대시보드
    - 룸 현황 (11개 한눈에 보기)
        - 룸 정보 수정 (사진, 가격, 설명, 특징 수정)
        - 룸 내부 메모 (adminMemo 수정)
        - 계약 이력 조회 (해당 룸의 과거 계약자 목록)
    - 납부 통계 (월별 총 수입, 미납률 차트)
    - 방문 예약 관리 (승인/취소)
    - 계약자 관리
        - 계약 등록 (고객 이름+전화번호+임시비밀번호 -> 계정 자동 생성)
        - 계약 해지/만료 (계정 비활성화 + 룸 공실 처리 일괄)
        - 재계약 (계정 재활성화 + 새 계약 등록)
    - 납부 관리
        - 납부 확인 (수동)
        - 미납 고객 알림 (납부일 경과 시)
        - 납부 문서 자동 생성 (매월 1일 자동 생성)
    - 공지사항 관리 (등록/수정/삭제)
    - 설정
        - 연습실 기본 정보 (이름, 주소, 계자, 지도 링크)
        - 방문 예약 가능 요일/시간 설정
```

---

## 5. Gemini CLI 프롬프트 - 1단계: 프로젝트 초기 세팅

아래 프롬프트를 Gemini CLI에 그대로 입력하세요.

---

### 프롬프트 1 - Flutter 프로젝트 초기 세팅

```
다음 조건으로 Flutter 프로젝트를 초기 세팅해줘.

[프로젝트 개요]
- 음악연습실 월 단위 임대 관리 앱
- 고객 + 운영자 기능을 하나의 앱에서 role로 분리
- 백엔드: Firebase (Firestore, Auth, Cloud Functions)
- 지원 플랫폼: iOS, Android

[필요한 패키지]
- firebase_core, firebase_auth, cloud_firestore
- go_router (화면 네비게이션)
- riverpod (상태관리)
- cached_network_image (이미지 캐싱)
- url_launcher (카카오톡, 지도 링크 열기)
- intl (날짜/금액 포맷)
- flutter_local_notifications (납부일 알림)

[폴더 구조]
lib/
  main.dart
  firebase_options.dart
  core/
    router.dart
    theme.dart
  models/
    room.dart
    user_model.dart
    visit.dart
    contract.dart
    payment.dart
  services/
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
    auth/
    admin/
  widgets/
    common/

위 구조로 프로젝트를 생성하고, 각 model 파일에 Firestore fromMap/toMap 메서드를 포함한 클래스를 작성해줘.
```

---

### 프롬프트 2 - 로그인 및 인증 흐름
 
```
Flutter + Firebase Auth를 사용한 로그인 화면 및 인증 흐름

[인증 구조]
  - 로그인 ID: 전화번호를 이메일 형식으로 변환 (010-1234-5678 -> 01012345678@yourroom.com)
  - 로그인 화면에서 고객은 전화번호 입력 -> 앱 내부에서 이메일 형식으로 변환 후 Firebase Auth 인증
  - 고객 자체 회원가입 없음 (운영자가 계정 직접 생성)
  - 로그인 후 Firestore `users/{uid}`의 role 값으로 화면 분기
    - customer (status: active) -> 홈 화면
    - customer (status: inactive) -> "계약이 종료된 계정입니다" 안내 후 로그인 차단
    - admin -> 운영자 대시보드

[로그인 화면 요구사항]
- 전화번호 입력 필드 (숫자만 입력, 자동으로 이메일 형식 변환)
- 비밀번호 입력 필드
- 로그인 버튼
- 로그인 실패 시 에러 메시지 표시
- 비로그인 접근: 룸 목록 등은 접근 가능
- 마이페이지 접근: 로그인 화면으로 이동

[첫 로그인 비밀번호 변경]
- users/{uid}.isFirstLogin`이 true이면 로그인 직후 비밀번호 변경 화면으로 이동
- 변경 완료 후 `isFirstLogin`을 false로 업데이트

[계약 종료 시 계정 비활성화]
- 계약 해지/만료 시 Firebase Auth 계정 비활성화 + users/{uid}.status → inactive
- Inactive 계정 로그인 시도 시 "계약이 종료된 계정입니다" 메시지 표시
- 재계약 시 계정 재활성화 (status → active)

[관리자 계정]
- 앱 내 관리자 계정 생성 기능 없음
- Firebase Console에서 수동 생성 후 Firestore users/{uid} 문서에 role: admin 으로 직접 설정
- Firestore 보안 규칙에서 앱을 통한 role: admin 설정을 차단할 것
```

---

### 프롬프트 3 - 룸 목록 화면

```
Flutter + Firestore로 룸 목록 화면을 만들어줘.

[Firestore 구조]
컬렉션: rooms
필드: roomId, name, size, sizeUnit, price, priceUnit, description, photos(List), features(List), status(vacant/occupied), floor

[화면 요구사항]
- 상단에 공실만 보기 / 전체 보기 탭
- 룸 카드: 첫 번째 사진, 호실명, 크기, 월 가격, 공실여부 뱃지
- 카드 형태: 첫 번째 사진, 호실명, 크기, 월 가격, 공실 여부 뱃지
- 공실 뱃지: 초록색, 계약중은 회색
- Riverpod StreamProvider로 실시간 데이터 연동
```

---

### 프롬프트 4 - 방문 예약 신청 화면

```
Flutter + Firestore로 방문 예약 신청 화면을 만들어줘.

[Firestore 구조]
컬렉션: visits
필드: visitId, userId, userName, userPhone, roomId, visitDate, visitTime, status(pending/confirmed/cancelled/completed), memo, createdAt

[화면 요구사항]
 - 룸 상세에서 "방문 예약하기" 버튼으로 진입
 - 입력 항목: 이름, 연락처, 희망 방문일(DatePicker), 희망 시간(09:00~21:00 중 1시간 단위 선택), 문의사항(선택)
 - 제출 시 Firestore visits 컬렉션에 저장, status는 pending으로 초기 저장
 - 제출 완료 후 "예약 신청이 완료되었습니다. 확인 후 연락드리겠습니다." 안내 화면 표시
```

---

### 프롬프트 5 - 운영자 대시보드

```
Flutter + Firestore로 운영자 대시보드 화면을 만들어줘.

[요구사항]
- 11개 룸을 그리드로 표시
- 각 룸 카드: 호실명, 상태(공실/계약중), 계약중이면 계약자 이름과 납푸일 표시
- 상단 요약: 전체 룸 수, 계약중, 공실 수 표시
- 하단 탭: 방문예약 관리 / 계약자 관리 / 납부 관리

[방문예약 관리 탭]
- pending 상태 방문예약 목록 표시
- 각 항목에 확정 / 취소 버튼
- 확정 시 status를 confirmed로 업데이트

[계약자 관리 탭]
- 계약 등록: 고객 이름 + 전화번호 + 임시 비밀번호 입력
  → Firebase Auth 계정 생성 (전화번호를 이메일 형식으로 변환: 01012345678@yourroom.com)
  → Firestore users/{uid} 생성 (role: customer, status: active, isFirstLogin: ture)
  → Firestore contracts/{id} 생성
  → 완료 후 임시 비밀번호 화면에 표시 + 복사 버튼
- 계약 해지/만료: 버튼 클릭 시 아래 항목 일괄 처리
  → contracts/{id} status → terminated/expired
  → rooms/{id} status → vacant
  → users/{uid} status → inactive
  → Firebase Auth 계정 비활성화
- 재계약: 기존 계정 재활성화 (status → active) + 새 계약 등록

[납부 관리 탭]
- 이번 달 미납(unpaid) 목록 표시
- 납부 확인 버튼 클릭 시 staus를 paid로 업데이트, paidDate 현재 날짜로 저장
```

---

### 프롬프트 6 - 룸 정보 수정 화면

```
- Flutter + Firestore로 운영자용 룸 정보 수정 화면을 만들어줘.

[Firestore 구조]
컬렉션: rooms
필드: roomId, name, size, sizeUnit, price, priceUnit, description, photos(List), features(List), status, floor

[화면 요구사항]
- 룸 현황 카드에서 수정 버튼으로 진입
- 수정 가능 항목: 호실명, 크기, 가격, 설명, 특징(태그 형식), 공실여부
- 사진은 Firebase Storage 업로드 후 URL 저장 (최대 5장)
- 저장 시 Firestore rooms/{roomId} 문서 업데이트 + updatedAt 현재 시각으로 갱신
- admin role만 접근 가능 (Firestore 보안 규칙으로 차단)
```

---

### 프롬프트 7 - 납부 관리(수동방식)

```
Firebase + Firesore로 운영자용 납부 관리 화면을 만들어줘. 
(Cloud Functions 없이 수동 버튼 방식으로 구현)

[납부 문서 수동 생성]
- 운영자 납부 관리 화면 상단에 "이번 달 납부 문서 생성" 버튼
- 버튼 탭 시 contracts 컬렉션에서 status: active 인 계약 전체 조회
  → 각 계약에 대해 payments 컬렉션에 당월 납부 문서 생성
  → 문서 구조: contractId, userId, roomId, amount, dueDate(계약의 paymentDueDate 기준), status: unpaid
- 중복 생성 방지: 해당 월 문서가 이미 존재하면 생성 건너뜀
- 완료 후 "이번 달 납부 문서가 생성됐습니다." 스낵바 표시

[미납 알림 수동 발송]
- 납부 관리 화면에서 미납(unpaid/overdue) 고객 목록 표시
- 각 항목에 "알림 발송" 버튼
- 탬 시 flutter_local_notifications 로 해당 고객 앱에 푸시 알림 발송
  → 알림 내용: "납부일이 지났습니다. 확인 부탁드립니다."
- 전체 미납 고객에게 한번에 발송하는 "전체 알림 발송" 버튼도 추가

[계약 만료 임박 표시]
- Cloud Functions 대신 운영자 대시보드에서 시각적으로 표시
- endDate가 30일 이내인 계약 룸 카드에 주황색 "만료임박" 뱃지 표시
- endDate가 7일 이내인 계약 룸 카드에 빨간색 "만료임박" 뱃지 표시
- 대시보드 상단에 만료 임박 건수 요약 표시
```

---

### 프롬프트 8 - 공지사항 기능

```
Flutter + Firestore로 공지사항 기능을 만들어줘.

[Firestore 구조]
컬렉션: notices
필드: noticeId, title, content, isPinned(bool), createdAt, updatedAt

[고객 앱 - 공지사항 목록]
- 비로그인 누구나 접근 가능
- isPinned: true 인 공지 상단 고정 표시
- 나머지는 최신순 정렬
- 공지 탭 시 상세 내용 표시

[운영자 앱 - 공지사항 관리]
- 공지 등록: 제목 + 내용 + 상단고정 여부 입력
- 공지 수정/삭제
- admin role만 등록/수정/삭제 가능 (Firestore 보안 규칙으로 차단)
```

---

### 프롬프트 9 - 비밀번호 찾기

```
Flutter + Firebase Auth로 비밀번호 찾기 기능을 구현해줘.

[요구사항]
- 로그인 화면에 "비밀번호 찾기" 버튼 추가
- 고객 계정 로그인 ID가 실제 이메일이 아닌 전화번호 형식(01012345678@yourroom.com)이므로 
  Firebase 비밀번호 재설정 이메일 사용 불가
- 버튼 탭 시: "비밀번호를 잊으셨나요? 카카오톡 오픈채팅으로 문의해주세요." 메시지와 오픈채팅 바로가기 버튼 표시
- 운영자가 Firebase Console에서 임시 비밀번호를 수동 재설정 후 카카오톡으로 전달하는 방식
```

---

### 프롬프트 10 - 룸별 메모 및 계약 이력

```
Flutter + Firestore로 룸별 내부 메모와 계약 이력 기능을 만들어줘.

[룸 내부 메모]
- 운영자 대시보드 룸 카드에서 메모 아이콘 탭 시 메모 편집 화면 진입
- 메모 내용 자유 텍스트 입력
- 저장 시 rooms/{roomId}.adminMemo 업데이트
- 메모가 있는 룸 카드는 메모 아이콘 표시 (고객에게는 노출 안 됨)
- Firestore 보안 규칙: adminMemo 필드는 admin만 읽기/쓰기 가능

[계약 이력 조회]
- 운영자 대시보드 룸 카드에서 "계약 이력" 버튼으로 진입
- contracts 컬렉션에서 해당 roomId의 전체 계약 목록 조회 (status 무관)
- 목록 표시: 계약자 이름, 계약 기간, 월세, 상태(계약중/만료/해지)
- 최신 계약 순 정렬
```

---

### 프롬프트 11 - 납부 통계

```
Flutter + Firestore로 운영자용 납부 통계 화면을 만들어줘.

[요구사항]
- 운영자 대시보드 하단 탭에 "통계" 탭 추가
- 월 선택기 (이전/다음 월 이동)
- 선택한 월의 통계 표시:
  - 총 계약 룸 수
  - 총 예상 수입 (active 계약의 monthlyFee 합계)
  - 실제 납부 완료 금액 (status paid 합계)
  - 미납 금액 (status unpaid + overdue 합계)
  - 미납률 (미납 건수 / 전체 건수 %)
- 최근 6개월 월별 수입 막대 차트 (fl_chart 패키지 사용)
- 룸별 납부 현황 목록 (이번 달 각 룸의 납부 상태)
```

---

### 프롬프트 12 - 방문 예약 가능 시간 설정

```
Flutter + Firestore로 방문 예약 가능 요일/시간 설정 기능을 만들어줘.

[Firestore 구조]
컬렉션: settings/info
필드: visitAvailableDays(List<int>), visitStartTime(String), visitEndTime(String)
설명: visitAvailableDays는 0=일, 1=월, 2=화, 3=수, 4=목, 5=금, 6=토

[운영자 설정 화면]
- 방문 가능 요일 토글 (요일별 on/off)
- 방문 시작 시간 / 종료 시간 선택 (1시간 단위)
- 저장 시 settings/info 문서 업데이트

[고객 방문 예약 화면 연동]
- 방문 예약 신청 시 settings/info 에서 visitAvailableDays, visitStartTime, visitEndTime 읽어옴
- DatePicker에서 비활성 요일 선택 불가 처리
- 시간 슬롯을 visitStartTime ~ visitEndTime 범위로 동적 생성
- 설정값 변경 시 예약 화면에 실시간 반영
```

---

## 6. Codex 코드리뷰 요청 프롬프트 템플릿

Gemini CLI로 코드 생성 후 아래 프롬프트로 Codex에 리뷰를 요청하세요.

```
아래 Flutter 코드를 리뷰해줘. 다음 세 가지 관점에서 확인해줘.

1. 보안 취약점
   - Firestore 보안 규칙과 충돌 가능성
   - 사용자 입력값 검증 누락

2. 성능 이슈
   - 불필요한 리빌드 여부
   - Firestore 쿼리 최적화 가능 여부

3. 예외 처리
   - 네트워크 오류 처리
   - null safety 위반 가능성
   - 빈 데이터 상태 처리

[리뷰할 코드]
(여기에 Gemini가 생성한 코드 붙여넣기)
```

---

## 7. 개발 순서 체크리스트

- [ ] Firebase 프로젝트 생성 (프롬프트 1)
- [ ] Firebase 프로젝트 연결 (flutterfire configure)
- [ ] Firestore 보안 규칙 설정
- [ ] Firebase Console에서 관리자 계정 수동 생성
- [ ] 로그인 및 인증 흐름 (프롬프트 2) → Codex 리뷰
- [ ] 룸 목록 화면 (프롬프트 3) → Codex 리뷰
- [ ] 룸 상세 화면
- [ ] 방문 예약 신청 (프롬프트 4) → Codex 리뷰
- [ ] 위치 안내 화면 (카카오톡/네이버맵 url_launcher)
- [ ] 카카오톡 오픈채팅 버튼
- [ ] 운영자 대시보드 (프롬프트 5) → Codex 리뷰
- [ ] 룸 정보 수정 + 메모 + 계약이력 (프롬프트 6, 10) → Codex 리뷰
- [ ] 납부 문서 자동 생성 + 미납 자동 알림 (프롬프트 7) → Codex 리뷰
- [ ] 공지사항 기능 (프롬프트 8) → Codex 리뷰
- [ ] 비밀번호 찾기 (프롬프트 9)
- [ ] 납부 통계 화면 (프롬프트 11) → Codex 리뷰
- [ ] 방문 예약 가능 시간 설정 (프롬프트 12) → Codex 리뷰
- [ ] 계약 만료 사전 알림
- [ ] 마이페이지 (납부 내역, 계약 정보, 비밀번호 변경 화면)
- [ ] 첫 로그인 비밀번호 변경 화면
- [ ] FCM 푸시 알림 설정
- [ ] iOS / Android 빌드 테스트
- [ ] 앱스토어 / 플레이스토어 배포
