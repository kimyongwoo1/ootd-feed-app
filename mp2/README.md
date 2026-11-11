# 미니 피드 앱 — 2108 MP2 (서버 동기화)

MP1의 미니 피드 앱에 **Supabase**를 연결해, 기기 A에서 쓴 글이 서버에 저장되고 기기 B에서 새로고침하면 그 글이 보이도록 만들었습니다.
사용자는 **익명 인증**으로만 구분하며, 이메일·전화번호 등 개인정보는 받지 않습니다.

## 1. 선택한 BaaS와 이유 — Supabase

| 비교 | Firebase (Firestore) | Supabase | 선택 이유 |
|---|---|---|---|
| 데이터 구조 | 문서(JSON) DB | **PostgreSQL** (표 + SQL) | 게시글처럼 정해진 칸이 있는 데이터는 표가 자연스럽고, 길이 제한(1~200자)을 DB가 직접 검사할 수 있음 |
| 접근 제어 | Security Rules (전용 문법) | **RLS 정책 (SQL)** | "본인 ID로만 작성" 같은 규칙을 SQL 한 줄로 작성 |
| 익명 인증 | 지원 | 지원 | 둘 다 가능 |
| 팀 프로젝트 | — | OOTD 피드 앱 백엔드로 이미 사용 중 | 같은 프로젝트에서 이어서 확장 가능 |

## 2. 익명 인증 방식

1. 앱이 켜지면 `auth.signInAnonymously()` 로 **익명 로그인**합니다. 회원가입·이메일·전화번호 입력이 없습니다.
2. Supabase가 기기마다 다른 **익명 사용자 ID(uuid)** 를 발급하고, 세션은 기기에 저장되어 앱을 다시 켜도 같은 ID가 유지됩니다.
3. 글을 쓰면 서버가 `author_id` 칸에 그 ID를 **자동으로** 넣습니다(`default auth.uid()`). 앱은 ID를 직접 보내지 않습니다.
4. RLS 정책으로 **로그인한 사용자만 읽기**, **본인 ID로만 쓰기**가 가능합니다. 수정·삭제 정책은 없으므로 앱에서 수정·삭제할 수 없습니다.
5. 피드 상단에 `익명 ID 1a2b3c4d` (앞 8자리)를 표시해, 두 기기가 서로 다른 사용자임을 스크린샷에서 확인할 수 있습니다. 내가 쓴 글에는 `내 글` 표시가 붙습니다.

## 3. 백엔드 설정 절차 (Supabase)

1. [supabase.com](https://supabase.com) 로그인 → **New project** 생성 (이미 있는 프로젝트를 써도 됩니다)
2. **익명 로그인 켜기**: Authentication → Sign In / Providers → **Allow anonymous sign-ins** 켜기 → Save
3. **테이블 만들기**: SQL Editor → `app/supabase/mini_posts.sql` 내용을 붙여넣고 **Run**
   - `mini_posts` 테이블, RLS 정책, 예시 글 3개가 만들어집니다. 여러 번 실행해도 안전합니다.
4. **설정 키 복사**: Project Settings → API (또는 상단 **Connect**) 에서
   - Project URL (`https://xxxx.supabase.co` — 뒤에 `/rest/v1/` 은 빼기)
   - Publishable key (`sb_publishable_...`)
5. **.env 만들기**: 제출 폴더의 `.env.example` 을 `app/.env` 로 복사하고 값을 채웁니다.
   ```bash
   # Windows
   copy .env.example app\.env
   # macOS / Linux
   cp .env.example app/.env
   ```
   ```
   SUPABASE_URL=https://xxxx.supabase.co
   SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxxx
   ```
   - `.env` 는 `.gitignore` 에 들어 있고 **ZIP에도 넣지 않습니다.**
   - Publishable key는 앱에 들어가도 되는 공개용 키이고, 데이터는 RLS 정책으로 보호됩니다. `service_role`/secret 키는 절대 앱에 넣지 않습니다.

### 테이블 구조 — `mini_posts`

| 칸 | 타입 | 설명 |
|---|---|---|
| `id` | uuid | 게시글 ID (서버가 자동 생성) |
| `author_id` | uuid | 작성자 익명 ID (서버가 `auth.uid()` 로 자동 입력) |
| `nickname` | varchar(10) | 닉네임 1~10자, 비우면 '익명' |
| `content` | varchar(200) | 내용 1~200자 (공백만 있는 글은 DB가 거부) |
| `created_at` | timestamptz | 작성 시각 (서버 시간) |

## 4. 실행 절차

```bash
# 0) 위 3번의 백엔드 설정과 app/.env 만들기를 먼저 합니다
cd app
flutter pub get
flutter run -d chrome        # 또는 에뮬레이터: flutter run -d emulator-5554
flutter test                 # 선택: 가짜 서버로 화면 동작 테스트
```

### 두 기기 동기화 확인 방법

| 방법 | 기기 A | 기기 B |
|---|---|---|
| 에뮬레이터 2개 | `flutter run -d emulator-5554` | `flutter run -d emulator-5556` |
| PC 하나로 | `flutter run -d chrome` 로 열린 창 | 같은 주소를 **시크릿 창**(또는 Edge)에서 열기 → 다른 익명 ID |

1. 기기 A에서 ✎ → 글 작성 → [게시] → A 피드 맨 위에 `내 글` 로 표시
2. 기기 B에서 피드를 **아래로 당기거나** 오른쪽 위 ↻ 버튼 → A의 글이 나타남
3. Supabase → Table Editor → `mini_posts` 에서 같은 글이 저장된 것을 확인

### 작성 실패(네트워크 오류) 처리

| 상황 | 앱 동작 |
|---|---|
| 처음 불러오기 실패 | 오류 안내 + **[다시 시도]** 버튼 |
| 새로고침 실패 | 지금 보이던 목록은 그대로 두고 하단에 안내 |
| 글 게시 실패 | "게시하지 못했어요. 인터넷 연결을 확인해 주세요." + **[다시 시도]**, 입력한 글은 지워지지 않음 |
| 응답이 10초 넘게 없음 | 시간 초과로 처리하고 같은 안내 |
| 게시 중 | 버튼 대신 로딩 표시 → 중복 게시 방지 |

확인 방법: Chrome 개발자 도구(F12) → Network → **Offline** 으로 바꾼 뒤 게시해 봅니다.

## 5. 평가 기준 확인

- [x] 두 기기 간 게시글 동기화가 스크린샷으로 확인된다. → `screenshots/`
- [x] 익명 인증만 사용하며 이메일·전화번호 등 개인정보 수집 코드가 없다.
- [x] 설정 키가 `.env` 로 분리되어 있고(`.env.example` 만 제출), 작성 실패 안내가 처리되어 있다.

## 6. MP1에서 바뀐 점

| 파일 | 변경 |
|---|---|
| `lib/main.dart` | `.env` 읽기 → Supabase 연결. 설정이 없으면 안내 화면 |
| `lib/services/post_repository.dart` | **새 파일.** 익명 로그인, 목록 불러오기, 글 저장, 오류 → 한국어 안내 변환 |
| `lib/services/app_exception.dart` | **새 파일.** 화면에 보여 줄 오류 메시지 |
| `lib/models/post.dart` | 서버 JSON → Post 변환(`fromJson`), `내 글` 여부 |
| `lib/screens/feed_screen.dart` | 서버에서 불러오기, 당겨서 새로고침, 오류 화면, 익명 ID 표시 |
| `lib/screens/compose_screen.dart` | 서버에 저장 후 돌아가기, 실패 안내 + 다시 시도, 게시 중 로딩 |
| `lib/widgets/post_card.dart` | `내 글` 표시 |
| `lib/data/dummy_posts.dart` | 삭제 (예시 글은 SQL로 서버에 넣음) |
| `app/supabase/mini_posts.sql` | **새 파일.** 테이블 + RLS + 예시 글 |
| `test/` | 가짜 서버(`fake_post_repository.dart`)로 화면 테스트 |

## 폴더 구조

```
제출.zip
├─ app/
│   ├─ lib/
│   │   ├─ main.dart
│   │   ├─ models/post.dart
│   │   ├─ services/post_repository.dart, app_exception.dart
│   │   ├─ screens/feed / compose / detail
│   │   ├─ widgets/post_card.dart
│   │   └─ utils/relative_time.dart
│   ├─ supabase/mini_posts.sql
│   ├─ test/
│   └─ pubspec.yaml
├─ README.md
├─ .env.example
├─ screenshots/
└─ prompts_log.md
```
