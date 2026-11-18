# 미니 피드 앱 — 2108 MP3 (상호작용과 안전장치)

MP2(Supabase 서버 동기화) 앱에 **좋아요·댓글**을 더해 사용자끼리 반응을 주고받을 수 있게 했습니다.
SNS가 꼭 갖춰야 할 안전장치인 **게시글 신고**와 **커뮤니티 가이드라인**(`GUIDELINES.md`)도 함께 만들었습니다.

## 전체 기능 목록

| 단계 | 기능 | 설명 |
|---|---|---|
| MP1 | 피드 | 글을 카드(닉네임·작성 시각·내용)로 스크롤 표시 |
| MP1 | 글쓰기 | 닉네임(선택)·내용(1~200자). 내용이 비면 [게시] 비활성 |
| MP1 | 상세 | 카드를 누르면 전체 내용과 정확한 작성 시각 표시 |
| MP1 | 상대 시간 | 방금 전 / N분 전 / N시간 전 / N일 전 / 날짜 |
| MP2 | 익명 인증 | 앱 시작 시 자동 익명 로그인. 이메일·전화번호 수집 없음 |
| MP2 | 서버 저장·동기화 | Supabase에 저장 → 다른 기기에서 새로고침하면 보임 |
| MP2 | 당겨서 새로고침 | 피드·상세 모두 아래로 당기기 또는 ↻ 버튼 |
| MP2 | 실패 안내 | 오프라인·시간 초과 시 안내 + [다시 시도], 입력 내용 유지 |
| **MP3** | **좋아요** | 하트를 누르면 켜짐/꺼짐(토글). **한 사람은 한 글에 한 번만**. 숫자만 공개 |
| **MP3** | **댓글** | 상세 화면에서 목록(오래된 순) 보기 + 작성(닉네임 선택, 1~200자). 피드 카드에 댓글 수 |
| **MP3** | **신고** | 상세 화면 🚩 → 사유 5가지 중 선택(필수) + 설명(선택) → 서버에 기록. 같은 글은 한 번만 |
| **MP3** | **신고 후 숨김** | 신고한 글은 내 피드에서 바로 숨김. 서로 다른 3명이 신고하면 모두에게 임시 숨김 |
| **MP3** | **가이드라인** | 금지 콘텐츠, 신고 처리 원칙, 데이터 노출 범위 → `GUIDELINES.md` |

## 상호작용 데이터 구조

```
mini_posts (게시글) ─┬─< mini_post_likes (좋아요)   한 사람 × 한 글 = 1개
                     ├─< mini_comments   (댓글)
                     └─< mini_reports    (신고)     한 사람 × 한 글 = 1개
```

### `mini_posts` — 게시글 (MP2 + MP3에서 칸 추가)

| 칸 | 타입 | 설명 |
|---|---|---|
| `id` | uuid | 게시글 ID |
| `author_id` | uuid | 작성자 익명 ID (서버가 `auth.uid()` 로 자동 입력) |
| `nickname` | varchar(10) | 닉네임 |
| `content` | varchar(200) | 내용 |
| `created_at` | timestamptz | 작성 시각 |
| `likes_count` | int | **MP3.** 좋아요 수 — 트리거가 자동 계산 |
| `comments_count` | int | **MP3.** 댓글 수 — 트리거가 자동 계산 |
| `report_count` | int | **MP3.** 신고 수 — 3 이상이면 자동 숨김. 앱은 읽지 않음 |

### `mini_post_likes` — 좋아요

| 칸 | 타입 | 설명 |
|---|---|---|
| `post_id` | uuid | 게시글 (삭제되면 같이 삭제) |
| `user_id` | uuid | 누른 사람 익명 ID (서버가 자동 입력) |
| `created_at` | timestamptz | 누른 시각 |

- **기본키 `(post_id, user_id)`** 라서 같은 사람이 같은 글에 좋아요를 두 번 저장할 수 없습니다. **중복 방지를 서버가 보장**합니다.
- 앱에서도 요청 중에는 버튼을 막고, 이미 눌러져 있다는 오류(23505)는 성공으로 처리합니다.
- 좋아요 취소 = 내 줄 삭제. RLS로 **내 좋아요만** 읽고 지울 수 있습니다.

### `mini_comments` — 댓글

| 칸 | 타입 | 설명 |
|---|---|---|
| `id` | uuid | 댓글 ID |
| `post_id` | uuid | 게시글 |
| `author_id` | uuid | 작성자 익명 ID (서버가 자동 입력) |
| `nickname` | varchar(10) | 닉네임 (비우면 '익명') |
| `content` | varchar(200) | 내용 1~200자 |
| `created_at` | timestamptz | 작성 시각 |

### `mini_reports` — 신고

| 칸 | 타입 | 설명 |
|---|---|---|
| `id` | uuid | 신고 ID |
| `post_id` | uuid | 신고한 게시글 |
| `reporter_id` | uuid | 신고자 익명 ID (서버가 자동 입력, 다른 사람에게 비공개) |
| `reason` | text | `spam` · `abuse` · `sexual` · `privacy` · `other` 중 하나 (그 외 값은 서버가 거부) |
| `detail` | varchar(200) | 자세한 설명 (선택) |
| `status` | text | `pending`(접수) → `removed`(삭제) / `dismissed`(위반 아님) — 운영자가 변경 |
| `created_at` | timestamptz | 신고 시각 |

- **`unique(post_id, reporter_id)`** 로 같은 글을 한 사람이 두 번 신고할 수 없습니다.

### 접근 규칙 요약 (RLS)

| 테이블 | 읽기 | 쓰기 |
|---|---|---|
| `mini_posts` | 로그인 사용자 (단, 신고 3건 이상인 글과 내가 신고한 글은 제외, 내 글은 항상 보임) | 본인 ID로만 작성. 수정 불가 (숫자 조작 방지) |
| `mini_post_likes` | **내 좋아요만** | 본인 것만 추가·삭제 |
| `mini_comments` | 로그인 사용자 모두 | 본인 ID로만 작성 |
| `mini_reports` | **내 신고만** | 본인 ID로, `pending` 상태로만 작성 |

노출 범위를 이렇게 정한 이유는 `GUIDELINES.md` 3장에 있습니다.

## 백엔드 설정 (Supabase)

1. Supabase 프로젝트 → Authentication → Sign In / Providers → **Allow anonymous sign-ins** 켜기
2. SQL Editor → `app/supabase/mini_posts.sql` 전체를 붙여넣고 **Run**
   - MP2 테이블이 이미 있어도 그대로 실행하면 됩니다. 기존 글은 유지되고 MP3 칸·테이블·규칙만 추가됩니다. 여러 번 실행해도 안전합니다.
   - "destructive operation" 경고가 뜨면 **Run this query** (정책을 지웠다가 다시 만드는 줄 때문)
3. Table Editor에 `mini_posts`, `mini_post_likes`, `mini_comments`, `mini_reports` 4개가 보이면 성공

### 설정 키

`.env` 는 제출물에 없습니다. `app/.env.example` 을 복사해 `app/.env` 를 만들고 MP2와 같은 값을 넣습니다.

```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxxx
```

(MP2 폴더의 `app/.env` 를 그대로 복사해 와도 됩니다. `service_role`/secret 키는 절대 넣지 않습니다.)

## 실행 절차

- 프레임워크/SDK: **Flutter 3.47.5 (stable) / Dart 3.13.4**
- 패키지: `supabase_flutter`, `flutter_dotenv` (버전은 `app/pubspec.lock` 에 고정)
- 실행 기기: **Chrome 웹 브라우저 2개 창** (Windows PC). 기기 A = 일반 창, 기기 B = 시크릿 창 → 서로 다른 익명 사용자. Android 에뮬레이터 2대로도 실행 가능
- 잠금 파일 포함: `app/pubspec.lock`, `app/android/gradle/wrapper/gradle-wrapper.properties`
- 먼저 위 "백엔드 설정"으로 SQL 실행과 `app/.env` 만들기를 합니다.

```bash
cd app
flutter pub get
flutter run -d web-server --web-port 8080
# 기기 A: Chrome 일반 창에서 http://localhost:8080
# 기기 B: Chrome 시크릿 창에서 http://localhost:8080
```

테스트 (선택, 가짜 서버 사용 — 네트워크 불필요)

```bash
flutter test
```

## 확인 방법

### 좋아요 토글·중복 방지·동기화

- 조작: 기기 A에서 게시글의 ♥ 를 누르고, 한 번 더 누른 뒤 다시 누른다. 기기 B에서 피드를 아래로 당긴다
- 기대 결과: 기기 A의 숫자가 0 → 1 → 0 → 1 로만 바뀌고 2 이상이 되지 않는다(중복 방지). 기기 B에서 새로고침하면 같은 글의 숫자가 1로 보이고, B의 하트는 빈 하트다
- 스크린샷: 01_deviceA_like.png, 02_deviceB_like_synced.png

### 댓글 작성·목록

- 조작: 기기 A에서 게시글 상세 → 아래 입력창에 닉네임·댓글을 쓰고 ➤ 를 누른다. 기기 B에서 같은 글 상세를 열고 아래로 당긴다
- 기대 결과: 기기 A의 댓글 목록 끝에 댓글이 추가되고 '댓글 N' 과 피드 카드의 댓글 수가 늘어난다. 기기 B에서도 같은 댓글이 목록에 보인다
- 스크린샷: 03_deviceA_comment.png, 04_deviceB_comment_synced.png

### 신고 사유 서버 기록

- 조작: 다른 사람이 쓴 글의 상세 → 오른쪽 위 🚩 → 사유 하나 선택(필요하면 설명 입력) → [신고하기]. Supabase Table Editor에서 `mini_reports` 를 연다
- 기대 결과: 사유를 고르기 전에는 [신고하기]가 비활성이고, 신고하면 "신고가 접수됐어요" 안내 후 그 글이 내 피드에서 사라진다. `mini_reports` 에 게시글 ID·사유·설명·시각이 저장된다. 같은 글을 다시 신고할 수 없다
- 스크린샷: 05_report_reason.png, 06_report_done.png, 07_server_reports.png

### 커뮤니티 가이드라인·민감정보 없음

- 조작: 제출물의 `GUIDELINES.md` 와 소스·설정 파일을 확인한다
- 기대 결과: `GUIDELINES.md` 에 금지 콘텐츠·신고 처리 원칙·상호작용 데이터 노출 범위와 이유가 있다. API 키·비밀번호가 소스에 없고 `app/.env.example`(플레이스홀더)만 있다
- 스크린샷: (없음 — 파일로 확인)

### 입력 데이터·스크린샷 개인정보 없음

- 조작: 스크린샷과 확인 중 입력한 닉네임·글·댓글을 확인한다
- 기대 결과: 가짜 닉네임과 코디 문장만 있고 실명·연락처·실제 인물 사진이 없다. 스크린샷의 브라우저 주소창·북마크 영역은 가렸다
- 스크린샷: 01_deviceA_like.png ~ 07_server_reports.png

시험 데이터: app/supabase/mini_posts.sql (실행하면 예시 글 3개가 들어감) + 확인 중 직접 작성한 글·댓글

네트워크: 온라인 필요

## 평가 기준 확인

- [x] 좋아요 토글이 중복 없이 동작하고 기기 간 동기화된다. → `screenshots/`
- [x] 신고 기능이 사유와 함께 서버에 기록된다. → `mini_reports`, `screenshots/`
- [x] 댓글 작성·목록이 동작하고 기기 간 동기화된다.
- [x] `GUIDELINES.md` 에 금지 콘텐츠·신고 처리 원칙·상호작용 데이터 노출 범위가 기술되어 있고, 민감정보가 없다.
- [x] 입력 데이터와 스크린샷에 실제 개인정보가 없다.
- [x] README에 실행 절차·확인 방법 절이 있다.

## MP2에서 바뀐 점

| 파일 | 변경 |
|---|---|
| `app/supabase/mini_posts.sql` | 좋아요·댓글·신고 테이블, 개수 트리거, RLS, 자동 숨김 추가 |
| `lib/models/post.dart` | 좋아요 수·댓글 수·내 좋아요 여부, `copyWith` |
| `lib/models/comment.dart` | **새 파일.** 댓글 |
| `lib/models/report_reason.dart` | **새 파일.** 신고 사유 5가지 (서버 값과 동일) |
| `lib/services/post_repository.dart` | `getPost`, `setLiked`, `fetchComments`, `addComment`, `reportPost` 추가 |
| `lib/widgets/like_button.dart` | **새 파일.** 하트 + 숫자 |
| `lib/widgets/report_sheet.dart` | **새 파일.** 신고 사유 선택 시트 |
| `lib/widgets/post_card.dart` | 좋아요 버튼, 댓글 수 |
| `lib/screens/feed_screen.dart` | 카드에서 좋아요 토글, 상세 변경 반영, 신고 글 제거 |
| `lib/screens/detail_screen.dart` | 좋아요, 댓글 목록·작성, 신고, 당겨서 새로고침 |
| `test/` | 좋아요 토글·댓글·신고 테스트 추가 |

## 폴더 구조

```
제출.zip
├─ app/
│   ├─ lib/
│   │   ├─ main.dart
│   │   ├─ models/      post, comment, report_reason
│   │   ├─ services/    post_repository, app_exception
│   │   ├─ screens/     feed, compose, detail
│   │   ├─ widgets/     post_card, like_button, report_sheet
│   │   └─ utils/       relative_time
│   ├─ supabase/mini_posts.sql
│   ├─ test/
│   ├─ .env.example     설정 키 목록 (실제 값 없음)
│   └─ pubspec.yaml
├─ README.md
├─ GUIDELINES.md
├─ screenshots/
└─ prompts_log.md
```
