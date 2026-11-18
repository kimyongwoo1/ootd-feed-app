# 미니 피드 앱 — 2108 MP1 (피드 화면 만들기)

서버 없이 **더미 데이터**로 동작하는 SNS형 피드 앱입니다.
게시글 목록(닉네임·작성 시각·내용), 글쓰기 화면, 게시글 상세 화면을 Flutter로 구현했습니다.

## 화면 구성

| 화면 | 하는 일 | 파일 |
|---|---|---|
| 피드 | 더미 게시글 10개를 카드(닉네임·작성 시각·내용)로 스크롤 표시. 오른쪽 아래 ✎ 버튼으로 글쓰기 | `lib/screens/feed_screen.dart` |
| 글쓰기 | 닉네임(선택, 10자)·내용(200자) 입력 → [게시] 하면 피드 최상단에 추가. 내용이 비어 있으면 [게시] 비활성 | `lib/screens/compose_screen.dart` |
| 상세 | 피드에서 게시글을 탭하면 이동. 닉네임, 상대 시간 + 정확한 작성 시각, 전체 내용 표시 | `lib/screens/detail_screen.dart` |

화면 이동 흐름

```
피드 ──(✎ 버튼)──▶ 글쓰기 ──([게시])──▶ 피드 맨 위에 새 글 추가
피드 ──(게시글 탭)──▶ 상세
```

## 더미 데이터 구조

게시글(`lib/models/post.dart`)

| 필드 | 타입 | 설명 |
|---|---|---|
| `id` | String | 게시글 구분값 (`dummy-1` … `dummy-10`, 새 글은 `post-<시간>`) |
| `nickname` | String | 가짜 닉네임 (초록고래, 새벽코더, 라떼한잔 …) |
| `content` | String | 더미 문장 |
| `createdAt` | DateTime | 작성 시각. 코드로 생성 (지금 − N분) |

- **데이터 파일 위치: `app/lib/data/dummy_posts.dart`** (`createDummyPosts()` 함수가 10개를 만듭니다)
- 작성 시각을 3분 전 ~ 4일 전으로 나눠 두어, 상대 시간 표시(분·시간·일)를 모두 확인할 수 있습니다.
- 실명, 연락처, 학번, 실제 인물 사진 등 **실제 개인정보와 민감정보는 넣지 않았습니다.** 프로필 사진 대신 닉네임 첫 글자 아이콘을 씁니다. 스크린샷에도 실제 개인정보가 없습니다.

## 상대 시간 표시

`lib/utils/relative_time.dart` — 패키지 없이 `Duration` 비교로 구현

| 지난 시간 | 표시 |
|---|---|
| 1분 미만 | 방금 전 |
| 1시간 미만 | N분 전 |
| 1일 미만 | N시간 전 |
| 7일 미만 | N일 전 |
| 7일 이상 | 2026.11.03 (날짜) |

피드 화면은 1분마다 다시 그려서, 켜 둔 동안에도 '방금 전' → '1분 전'처럼 갱신됩니다.

## 실행 절차

- 프레임워크/SDK: **Flutter 3.47.5 (stable) / Dart 3.13.4**
- 실행 기기: **Chrome 웹 브라우저** (Windows PC, `flutter run -d chrome`). Android 에뮬레이터에서도 실행 가능
- 외부 패키지 없음 (Flutter 기본 위젯만 사용), 서버·네트워크 불필요
- 잠금 파일 포함: `app/pubspec.lock`, `app/android/gradle/wrapper/gradle-wrapper.properties`

```bash
cd app
flutter pub get
flutter run -d chrome
```

테스트 (선택)

```bash
flutter test
```

## 확인 방법

### 게시글 카드·스크롤

- 조작: 앱을 실행하고 게시글 목록을 아래로 스크롤한다
- 기대 결과: 닉네임·작성 시각·내용이 담긴 게시글 카드가 목록에 표시되고, 스크롤하면 다음 카드가 보인다
- 스크린샷: 01_feed.png

### 새 글 최상단 반영·상세 이동

- 조작: 오른쪽 아래 ✎ 버튼 → 글쓰기 화면에서 내용을 입력하고 [게시]한 뒤, 피드에서 그 카드를 누른다
- 기대 결과: 방금 쓴 글이 피드 맨 위에 '방금 전'으로 추가되고, 카드를 누르면 상세 화면에 전체 내용과 작성 시각이 열린다. 내용이 비어 있으면 [게시] 버튼이 비활성화된다
- 스크린샷: 02_compose.png, 01_feed.png, 03_detail.png

### 상대 시간 표시

- 조작: 피드의 각 카드 오른쪽 위 시각과 상세 화면의 시각을 확인한다
- 기대 결과: 작성 시각이 '방금 전 / N분 전 / N시간 전 / N일 전'으로 표시되고, 상세 화면에는 '3분 전 · 2026.11.04 15:26'처럼 정확한 시각도 함께 표시된다
- 스크린샷: 01_feed.png, 03_detail.png

### 더미 데이터 개인정보 없음

- 조작: `app/lib/data/dummy_posts.dart` 와 피드 화면의 닉네임·내용을 확인한다
- 기대 결과: 가짜 닉네임(초록고래, 새벽코더 …)과 더미 문장만 있고 실명·연락처·실제 인물 사진이 없다
- 스크린샷: 01_feed.png

시험 데이터: app/lib/data/dummy_posts.dart (더미 게시글 10개, 작성 시각 3분 전 ~ 4일 전)

네트워크: 불필요

## 폴더 구조

```
app/lib/
  main.dart                 앱 시작, 테마
  models/post.dart          게시글 모델
  data/dummy_posts.dart     더미 게시글 10개 (시험 데이터)
  utils/relative_time.dart  상대 시간 변환
  widgets/post_card.dart    피드 카드
  screens/                  feed / compose / detail 화면
app/test/widget_test.dart   단위·위젯 테스트
```
