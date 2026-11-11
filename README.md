# 미니 피드 앱 — 2108 MP1 ~ MP3

익명 SNS형 피드 앱을 Flutter로 3단계에 걸쳐 만든 저장소입니다.
각 폴더는 그 단계의 제출물과 같은 구조(`app/`, `README.md`, `screenshots/`, `prompts_log.md` …)입니다.

| 폴더 | 단계 | 내용 | 백엔드 |
|---|---|---|---|
| [`mp1/`](mp1/) | MP1 피드 화면 | 피드 · 글쓰기 · 상세 화면, 상대 시간 표시 | 없음 (더미 데이터) |
| [`mp2/`](mp2/) | MP2 서버 동기화 | 익명 인증, 글 서버 저장, 두 기기 동기화, 당겨서 새로고침, 작성 실패 안내 | Supabase |
| [`mp3/`](mp3/) | MP3 상호작용과 안전장치 | 좋아요(중복 방지), 댓글, 게시글 신고, 커뮤니티 가이드라인 | Supabase |

## 실행

각 단계 폴더의 `README.md` 에 자세한 절차가 있습니다. 공통 순서는 아래와 같습니다.

```bash
cd mp3/app            # 실행할 단계 폴더
flutter pub get
flutter run -d chrome
```

- **MP2·MP3**는 Supabase 설정이 필요합니다.
  1. Supabase SQL Editor에서 `app/supabase/mini_posts.sql` 실행
  2. `app/.env.example` 을 복사해 `app/.env` 를 만들고 URL·Publishable key 입력
- `.env` 는 `.gitignore` 에 들어 있어 저장소에 올라가지 않습니다. **실제 키는 절대 커밋하지 마세요.**

## 기술 스택

Flutter (Dart 3) · Supabase (PostgreSQL, 익명 인증, RLS) · flutter_dotenv
