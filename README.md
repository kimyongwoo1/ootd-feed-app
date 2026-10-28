# OOTD 피드 앱

회원가입 없이 익명으로 오늘의 착장(OOTD)을 공유하는 SNS형 모바일 앱

- **앱:** Flutter (Android / iOS)
- **백엔드:** Supabase (익명 인증, PostgreSQL, Storage, Realtime)
- **온디바이스 AI:** LiteRT + MobileNetV3 (의류 종류·색상 태그 추천)
- **팀:** 구동근, 김용우, 설주현, 김지원

## 폴더 구조

```
lib/
  main.dart
  backend/      ← 백엔드 담당: Supabase 데이터 계층 (함수만 호출하면 됨)
  screens/      ← 화면 담당: 화면(UI)
  ai/           ← AI 담당: 태그 추천 (LiteRT)
assets/         ← AI 모델(.tflite), 라벨 파일
supabase/
  migrations/   ← DB 스키마 SQL
  tests/        ← DB 보안·제약조건 테스트
test/           ← 단위·위젯 테스트
integration_test/ ← 통합 테스트
.github/        ← PR·이슈 양식, 자동 검사(CI)
```

> 각자 맡은 폴더 위주로 작업하면 충돌이 거의 생기지 않는다.

## 처음 실행하기

```bash
git clone https://github.com/<팀계정>/ootd-feed-app.git
cd ootd-feed-app
cp .env.example .env        # 팀 채팅에서 받은 Supabase URL·키 입력
flutter pub get
flutter run
```

## 백엔드 함수 사용법

`import 'backend/backend.dart';` 후 아래 함수를 호출한다. 실패하면 `AppException` 이 던져지고 `e.message` 를 그대로 화면에 보여주면 된다.

| ID | 기능 | 함수 |
|---|---|---|
| A1 | 익명으로 시작 | `AuthRepository().ensureSignedIn()` |
| A2 | 닉네임 | `ProfileRepository().getMyProfile()` / `isNicknameAvailable()` / `setNickname()` |
| B1 | 피드 | `PostRepository().fetchFeed()` / `fetchFeed(before: posts.last.createdAt)` |
| B2 | 게시글 작성 | `PostRepository().createPost(imageBytes:, content:, tags:, purchaseUrl:, clothingTags:)` |
| B3 | 상세 | `getPost(id)`, `CommentRepository().fetchComments(id)`, `ClothingTagRepository().fetchTags(id)` |
| B4 | 상대 시간 | `relativeTime(post.createdAt)` |
| C1 | 좋아요 | `LikeRepository().setLiked(postId, true/false)` |
| C2 | 댓글 | `CommentRepository().watchComments(postId)` / `addComment()` / `deleteComment()` |
| C3 | 좋아요한 사람 | `LikeRepository().fetchLikers(postId)` |
| C4 | 신고 | `ReportRepository().reportPost(postId, ReportReason.spam)` |
| D1 | 실시간 | `PostRepository().watchFeed()` |
| E2 | 인기 랭킹 | `PostRepository().fetchPopular(days: 7)` |
| F1 | 태그 검색 | `PostRepository().fetchByTag('#화이트셔츠')` |

## 테스트용 이름 규칙

자동화 테스트(integration_test, Patrol, Maestro)가 화면 요소를 찾을 수 있도록 주요 위젯에 같은 이름의 `Key` 와 `Semantics(identifier:)` 를 붙인다.

| 화면 | 이름 |
|---|---|
| 닉네임 | `nickname_field`, `nickname_submit` |
| 피드 | `feed_list`, `write_button`, `like_button_{index}` |
| 게시글 작성 | `pick_gallery`, `pick_camera`, `content_field`, `submit_post` |
| 상세 | `comment_field`, `comment_submit`, `report_button` |

## 협업 규칙

[CONTRIBUTING.md](CONTRIBUTING.md) 참고
