#!/usr/bin/env bash
# =====================================================================
# GitHub 라벨·마일스톤·이슈를 한 번에 만드는 스크립트 (저장소 관리자 1명만 실행)
#   준비: GitHub CLI 설치(https://cli.github.com) → `gh auth login`
#   실행: 저장소 폴더에서 Git Bash 로  `bash scripts/create_issues.sh`
# =====================================================================
set -e

echo "▶ 라벨 만들기"
gh label create frontend --color 0E8A16 --description "화면(UI)"            --force
gh label create backend  --color 1D76DB --description "Supabase·데이터 계층" --force
gh label create ai       --color 5319E7 --description "온디바이스 AI"        --force
gh label create test     --color FBCA04 --description "테스트"              --force
gh label create setup    --color BFD4F2 --description "환경 설정"           --force
gh label create "우선순위:상" --color B60205 --force
gh label create "우선순위:중" --color D93F0B --force
gh label create "우선순위:하" --color C5DEF5 --force

echo "▶ 마일스톤 만들기 (마감일은 GitHub 화면에서 직접 설정)"
for m in "M1 뼈대 연결" "M2 핵심 기능" "M3 AI·부가 기능" "M4 테스트·발표 준비"; do
  gh api "repos/{owner}/{repo}/milestones" -f title="$m" >/dev/null 2>&1 || echo "  (이미 있음: $m)"
done

issue() {  # issue "제목" "라벨" "마일스톤" "본문"
  gh issue create --title "$1" --label "$2" --milestone "$3" --body "$4" >/dev/null
  echo "  + $1"
}

echo "▶ 이슈 만들기"
# ---------------- M1 뼈대 연결 ----------------
issue "[SETUP] Flutter 프로젝트와 저장소 초기 설정" "setup" "M1 뼈대 연결" "## 할 일
- [ ] \`flutter create --org com.team ootd_feed\` 로 만든 프로젝트를 저장소에 올리기
- [ ] pubspec.yaml 에 supabase_flutter, flutter_dotenv, image_picker 추가
- [ ] 팀원 전원 clone 후 실행 확인
## 완료 조건
모든 팀원이 main 을 받아 앱을 실행할 수 있다."

issue "[SETUP] Supabase 프로젝트 생성·스키마 적용" "setup,backend" "M1 뼈대 연결" "## 할 일
- [ ] Supabase 프로젝트 생성 (Region: Seoul)
- [ ] Authentication 에서 Anonymous sign-ins 켜기
- [ ] SQL Editor 에서 supabase/migrations/20261026000000_init_schema.sql 실행
- [ ] URL·anon key 를 팀 채팅으로 공유 (.env, Git 에는 올리지 않음)
## 완료 조건
앱에서 익명 로그인과 테이블 조회가 된다."

issue "[SETUP] 테스트용 Key·Semantics 이름 규칙 정하기" "setup,test" "M1 뼈대 연결" "## 할 일
- [ ] 주요 버튼·입력창 이름 목록 정하기 (예: nickname_field, write_button, like_button_0)
- [ ] README 에 정리
## 완료 조건
화면 담당이 같은 이름으로 Key 와 Semantics(identifier) 를 붙인다."

issue "[A1] 익명으로 시작" "frontend,backend,우선순위:상" "M1 뼈대 연결" "## 할 일
- [ ] 앱 시작 시 SupabaseConfig.init() → AuthRepository().ensureSignedIn()
- [ ] 로그인 중 로딩 표시, 실패 시 다시 시도 버튼
## 완료 조건
테스트 케이스 T1 통과"

issue "[A2] 닉네임 설정" "frontend,우선순위:중" "M1 뼈대 연결" "## 할 일
- [ ] getMyProfile() 이 null 이면 닉네임 화면 표시
- [ ] isNicknameAvailable(), setNickname() 연결, 1~10자 검사
## 완료 조건
테스트 케이스 T2 통과"

issue "[B1] 피드 목록 조회" "frontend,우선순위:상" "M1 뼈대 연결" "## 할 일
- [ ] fetchFeed() 로 최신순 20개 표시
- [ ] 당겨서 새로고침, 무한 스크롤 fetchFeed(before: ...)
- [ ] 빈 목록 안내
## 완료 조건
테스트 케이스 T3, NT2 통과"

issue "[B2] 게시글 작성 (사진 선택·촬영)" "frontend,우선순위:상" "M1 뼈대 연결" "## 할 일
- [ ] image_picker 로 갤러리·카메라 (maxWidth 1080)
- [ ] createPost() 호출 후 피드 최상단에 즉시 추가
- [ ] 권한 거부·네트워크 오류 안내
## 완료 조건
테스트 케이스 T4, NT6 통과"

# ---------------- M2 핵심 기능 ----------------
issue "[B3] 게시글 상세 조회" "frontend,우선순위:중" "M2 핵심 기능" "## 할 일
- [ ] getPost(), fetchComments(), fetchTags() 로 상세 화면 구성
## 완료 조건
테스트 케이스 T5 통과"

issue "[B4] 상대 시간 표시" "frontend,우선순위:중" "M2 핵심 기능" "## 할 일
- [ ] relativeTime(post.createdAt) 적용
## 완료 조건
테스트 케이스 T6 통과"

issue "[C1] 좋아요 (낙관적 업데이트)" "frontend,우선순위:상" "M2 핵심 기능" "## 할 일
- [ ] 하트 탭 시 화면 먼저 변경 → setLiked() → 실패 시 되돌리기
## 완료 조건
테스트 케이스 T8, NT1 통과"

issue "[C2] 댓글 (실시간)" "frontend,우선순위:상" "M2 핵심 기능" "## 할 일
- [ ] watchComments() 로 실시간 목록, addComment(), deleteComment()
## 완료 조건
테스트 케이스 T9 통과"

issue "[C4] 게시글 신고" "frontend,우선순위:중" "M2 핵심 기능" "## 할 일
- [ ] 신고 사유 선택 팝업, reportPost(), hasReported()
## 완료 조건
테스트 케이스 T11 통과"

issue "[D1] 서버 저장·실시간 동기화" "frontend,backend,우선순위:상" "M2 핵심 기능" "## 할 일
- [ ] 피드 화면에서 watchFeed() 구독 (추가·수정·삭제 반영), dispose 에서 cancel
- [ ] 두 기기로 동기화 확인
## 완료 조건
테스트 케이스 T13 통과"

issue "[D2] 오류 처리" "frontend,우선순위:중" "M2 핵심 기능" "## 할 일
- [ ] 모든 백엔드 호출을 try / on AppException 으로 감싸 e.message 표시
## 완료 조건
테스트 케이스 T14 통과, 비행기 모드에서 앱이 종료되지 않음"

issue "[F1-a] MobileNetV3 의류 분류 모델 학습·변환" "ai,우선순위:상" "M2 핵심 기능" "## 할 일
- [ ] 의류 클래스 5~6개 정하기, 공개 데이터셋 준비 (라이선스 확인)
- [ ] 전이 학습 → clothes_mobilenetv3.tflite, clothes_labels.txt 생성
- [ ] 정확도 기록
## 완료 조건
assets 폴더에 모델 파일이 올라가 있다. (학습 데이터는 Git 에 올리지 않음)"

# ---------------- M3 AI·부가 기능 ----------------
issue "[F1-b] AI 태그 추천 앱 연결" "ai,frontend,우선순위:상" "M3 AI·부가 기능" "## 할 일
- [ ] 모델 준비 전에는 가짜 태그를 돌려주는 함수로 화면 먼저 완성
- [ ] tflite_flutter 로 ClothesTagger 연결, 추천 태그를 Chip 으로 표시
- [ ] 고른 태그만 createPost(tags: ...) 로 저장, fetchByTag() 검색
## 완료 조건
테스트 케이스 T17, NT3 통과"

issue "[B5] 구매 링크 첨부" "frontend,우선순위:하" "M3 AI·부가 기능" "## 할 일
- [ ] 작성 화면 링크 입력, 상세 화면에서 url_launcher 로 열기
## 완료 조건
테스트 케이스 T7 통과"

issue "[C3] 좋아요한 사람 확인" "frontend,우선순위:하" "M3 AI·부가 기능" "## 할 일
- [ ] fetchLikers() 결과를 바텀시트로 표시
## 완료 조건
테스트 케이스 T10 통과"

issue "[C5] 옷 태그" "frontend,우선순위:하" "M3 AI·부가 기능" "## 할 일
- [ ] 사진 위 위치 지정(x, y 0~1) → createPost(clothingTags: ...)
- [ ] 상세 화면 Stack + Positioned 로 표시
## 완료 조건
테스트 케이스 T12 통과"

issue "[E2] 인기 게시물 랭킹" "frontend,우선순위:하" "M3 AI·부가 기능" "## 할 일
- [ ] fetchPopular(days: 7) 결과를 순위와 함께 표시
## 완료 조건
테스트 케이스 T16 통과"

issue "[E1] 날씨별 OOTD 추천 (여유 있을 때)" "frontend,backend,우선순위:하" "M3 AI·부가 기능" "## 할 일
- [ ] 날씨 API 선정, Edge Function 또는 앱에서 호출
- [ ] 기온별 태그 규칙 정하고 fetchByTag() 활용
## 완료 조건
테스트 케이스 T15 통과"

# ---------------- M4 테스트·발표 ----------------
issue "[TEST] 단위·위젯 테스트 작성" "test" "M4 테스트·발표 준비" "## 할 일
- [ ] test/ 에 relativeTime, normalizeTags, 입력값 검사 테스트
## 완료 조건
CI 의 flutter test 통과"

issue "[TEST] 통합 테스트 (integration_test + Patrol)" "test" "M4 테스트·발표 준비" "## 할 일
- [ ] T2 닉네임, T8 좋아요 흐름 integration_test
- [ ] T4 권한 거부 Patrol 테스트
## 완료 조건
에뮬레이터에서 통과"

issue "[TEST] 테스트 케이스 전체 수동 점검" "test" "M4 테스트·발표 준비" "## 할 일
- [ ] T1~T17, NT1~NT6 결과를 표에 기록 (통과/실패)
- [ ] 실패 항목은 버그 이슈로 등록"

issue "[RELEASE] 시연 준비" "setup" "M4 테스트·발표 준비" "## 할 일
- [ ] 더미 게시글 준비 (실제 개인 사진 사용 금지)
- [ ] 시연 전날 Supabase 프로젝트 일시정지 여부 확인
- [ ] 시연용 APK 빌드 (flutter build apk)"

echo "✔ 완료: GitHub 저장소의 Issues 탭에서 확인하세요."
