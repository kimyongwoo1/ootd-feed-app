# 협업 규칙

## 1. 작업 흐름

```bash
git switch main && git pull                 # 1) 최신 main 받기
git switch -c feature/C1-like               # 2) 이슈 하나당 브랜치 하나
# ... 작업 ...
git add . && git commit -m "C1 좋아요 낙관적 업데이트 추가"   # 3) 자주 커밋
git push -u origin feature/C1-like          # 4) 올리기
```

5. GitHub 에서 **Pull Request** 생성 → 양식 채우기 → 리뷰어 1명 지정
6. CI(자동 검사) 통과 + 리뷰어 승인 → **Squash and merge** → 브랜치 삭제
7. 다음 작업은 다시 1)부터

작업 중 main 이 바뀌었으면 내 브랜치에서 `git merge main` 으로 반영한다.

## 2. 브랜치 이름

| 종류 | 형식 | 예 |
|---|---|---|
| 기능 | `feature/<요구사항ID>-<설명>` | `feature/B2-write-post` |
| 버그 수정 | `fix/<설명>` | `fix/feed-refresh` |
| 백엔드 | `backend/<설명>` | `backend/report-policy` |
| AI | `ai/<설명>` | `ai/mobilenet-model` |
| 테스트 | `test/<설명>` | `test/like-integration` |

## 3. 커밋 메시지

`<요구사항ID 또는 종류> 무엇을 했는지` 한 줄

```
A2 닉네임 중복 확인 추가
fix 피드 새로고침 시 중복 게시글 제거
test T8 좋아요 통합 테스트 추가
```

## 4. 지켜야 할 것

- `main` 에 직접 push 하지 않는다 (PR 로만 합치기)
- `.env`, Supabase 키, 학습 데이터, 실제 개인 사진은 올리지 않는다
- PR 전에 `flutter analyze` 로 오류 확인
- PR 설명에 `Closes #이슈번호` 를 쓰면 합칠 때 이슈가 자동으로 닫힌다
- `git push --force`, `git reset --hard` 는 쓰지 않는다
- 백엔드 함수 이름·모델을 바꿀 때는 미리 팀에 알린다
