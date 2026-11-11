-- MP2 미니 피드: Supabase SQL Editor 에 붙여넣고 [Run] (여러 번 실행해도 안전)
-- 개인정보 컬럼(이메일·전화번호 등)은 만들지 않는다. 작성자는 익명 사용자 ID(uuid)로만 구분.

create table if not exists public.mini_posts (
  id         uuid primary key default gen_random_uuid(),
  author_id  uuid default auth.uid() references auth.users (id) on delete set null,
  nickname   varchar(10)  not null default '익명'
             check (char_length(trim(nickname)) between 1 and 10),
  content    varchar(200) not null
             check (char_length(trim(content)) between 1 and 200),
  created_at timestamptz  not null default now()
);

create index if not exists mini_posts_created_at_idx
  on public.mini_posts (created_at desc);

-- 행 단위 보안(RLS): 로그인(익명 포함)한 사용자만 읽고, 본인 ID로만 쓸 수 있다
alter table public.mini_posts enable row level security;

drop policy if exists "mini_posts 읽기" on public.mini_posts;
create policy "mini_posts 읽기" on public.mini_posts
  for select to authenticated using (true);

drop policy if exists "mini_posts 본인 작성" on public.mini_posts;
create policy "mini_posts 본인 작성" on public.mini_posts
  for insert to authenticated with check (author_id = auth.uid());

-- 수정·삭제 정책은 만들지 않음 → 앱에서는 수정·삭제 불가 (MP3에서 추가 예정)

-- MP1 더미 글 3개를 서버에 미리 넣어 둔다 (테이블이 비어 있을 때만)
insert into public.mini_posts (author_id, nickname, content, created_at)
select null, v.nickname, v.content, now() - v.ago
from (values
  ('초록고래', '오늘은 흰 셔츠에 연청 데님. 가을엔 역시 기본템이 최고예요.', interval '3 hours'),
  ('라떼한잔', '베이지 트렌치코트 꺼냈어요. 안에는 스트라이프 티셔츠!',     interval '1 day'),
  ('달빛토끼', '체크 셔츠 + 와이드 슬랙스 조합 추천해요.',                 interval '3 days')
) as v(nickname, content, ago)
where not exists (select 1 from public.mini_posts);
