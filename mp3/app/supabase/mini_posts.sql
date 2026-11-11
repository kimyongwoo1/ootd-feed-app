-- MP3 미니 피드: Supabase SQL Editor 에 붙여넣고 [Run]
-- MP2 테이블이 이미 있어도, 없어도 그대로 실행하면 된다. (여러 번 실행해도 안전)
-- 개인정보 컬럼(이메일·전화번호 등)은 만들지 않는다. 사용자는 익명 ID(uuid)로만 구분.

------------------------------------------------------------
-- 1. 게시글 (MP2)
------------------------------------------------------------
create table if not exists public.mini_posts (
  id         uuid primary key default gen_random_uuid(),
  author_id  uuid default auth.uid() references auth.users (id) on delete set null,
  nickname   varchar(10)  not null default '익명'
             check (char_length(trim(nickname)) between 1 and 10),
  content    varchar(200) not null
             check (char_length(trim(content)) between 1 and 200),
  created_at timestamptz  not null default now()
);

-- MP3: 좋아요 수 · 댓글 수 · 신고 수 (트리거가 자동으로 맞춤, 앱은 직접 못 바꿈)
alter table public.mini_posts
  add column if not exists likes_count    int not null default 0,
  add column if not exists comments_count int not null default 0,
  add column if not exists report_count   int not null default 0;

create index if not exists mini_posts_created_at_idx
  on public.mini_posts (created_at desc);

------------------------------------------------------------
-- 2. 좋아요 — (게시글, 사용자) 한 쌍은 한 번만 → 중복 좋아요 불가
------------------------------------------------------------
create table if not exists public.mini_post_likes (
  post_id    uuid not null references public.mini_posts (id) on delete cascade,
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

------------------------------------------------------------
-- 3. 댓글
------------------------------------------------------------
create table if not exists public.mini_comments (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.mini_posts (id) on delete cascade,
  author_id  uuid default auth.uid() references auth.users (id) on delete set null,
  nickname   varchar(10)  not null default '익명'
             check (char_length(trim(nickname)) between 1 and 10),
  content    varchar(200) not null
             check (char_length(trim(content)) between 1 and 200),
  created_at timestamptz  not null default now()
);
create index if not exists mini_comments_post_idx
  on public.mini_comments (post_id, created_at);

------------------------------------------------------------
-- 4. 신고 — 사유는 정해진 5가지 중 하나, 같은 글은 한 사람이 한 번만
------------------------------------------------------------
create table if not exists public.mini_reports (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references public.mini_posts (id) on delete cascade,
  reporter_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  reason      text not null
              check (reason in ('spam', 'abuse', 'sexual', 'privacy', 'other')),
  detail      varchar(200),
  status      text not null default 'pending'
              check (status in ('pending', 'removed', 'dismissed')),
  created_at  timestamptz not null default now(),
  unique (post_id, reporter_id)
);

------------------------------------------------------------
-- 5. 개수 자동 계산 트리거 (앱이 숫자를 조작할 수 없게 서버가 계산)
------------------------------------------------------------
create or replace function public.mini_sync_counts()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  col text := case tg_table_name
                when 'mini_post_likes' then 'likes_count'
                when 'mini_comments'   then 'comments_count'
                when 'mini_reports'    then 'report_count'
              end;
begin
  if tg_op = 'INSERT' then
    execute format('update public.mini_posts set %I = %I + 1 where id = $1', col, col)
      using new.post_id;
  elsif tg_op = 'DELETE' then
    execute format('update public.mini_posts set %I = greatest(%I - 1, 0) where id = $1', col, col)
      using old.post_id;
  end if;
  return null;
end $$;

drop trigger if exists mini_likes_count    on public.mini_post_likes;
drop trigger if exists mini_comments_count on public.mini_comments;
drop trigger if exists mini_reports_count  on public.mini_reports;
create trigger mini_likes_count    after insert or delete on public.mini_post_likes
  for each row execute function public.mini_sync_counts();
create trigger mini_comments_count after insert or delete on public.mini_comments
  for each row execute function public.mini_sync_counts();
create trigger mini_reports_count  after insert or delete on public.mini_reports
  for each row execute function public.mini_sync_counts();

-- MP2 에서 이미 쌓인 데이터가 있으면 개수를 한 번 맞춰 둔다
update public.mini_posts p set
  likes_count    = (select count(*) from public.mini_post_likes l where l.post_id = p.id),
  comments_count = (select count(*) from public.mini_comments  c where c.post_id = p.id),
  report_count   = (select count(*) from public.mini_reports   r where r.post_id = p.id);

-- 앱(로그인 사용자)은 게시글의 숫자 칸을 직접 수정할 수 없다
revoke update on public.mini_posts from anon, authenticated;

------------------------------------------------------------
-- 6. 행 단위 보안(RLS) — 누가 무엇을 볼 수 있는지 (GUIDELINES.md 3장)
------------------------------------------------------------
alter table public.mini_posts      enable row level security;
alter table public.mini_post_likes enable row level security;
alter table public.mini_comments   enable row level security;
alter table public.mini_reports    enable row level security;

-- 게시글: 신고가 3건 이상 쌓이면 자동 숨김(작성자 본인에게만 보임),
--         내가 신고한 글은 내 피드에서 바로 숨김
drop policy if exists "mini_posts 읽기" on public.mini_posts;
create policy "mini_posts 읽기" on public.mini_posts
  for select to authenticated using (
    author_id = auth.uid()
    or (
      report_count < 3
      and not exists (
        select 1 from public.mini_reports r
        where r.post_id = mini_posts.id and r.reporter_id = auth.uid()
      )
    )
  );

drop policy if exists "mini_posts 본인 작성" on public.mini_posts;
create policy "mini_posts 본인 작성" on public.mini_posts
  for insert to authenticated with check (author_id = auth.uid());

-- 좋아요: 내가 누른 것만 보인다 → "누가 좋아요했는지"는 아무에게도 공개되지 않고 숫자만 공개
drop policy if exists "likes 내 것만 읽기" on public.mini_post_likes;
create policy "likes 내 것만 읽기" on public.mini_post_likes
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "likes 누르기" on public.mini_post_likes;
create policy "likes 누르기" on public.mini_post_likes
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "likes 취소" on public.mini_post_likes;
create policy "likes 취소" on public.mini_post_likes
  for delete to authenticated using (user_id = auth.uid());

-- 댓글: 로그인한 사용자 모두 읽기, 본인 ID로만 작성
drop policy if exists "comments 읽기" on public.mini_comments;
create policy "comments 읽기" on public.mini_comments
  for select to authenticated using (true);

drop policy if exists "comments 작성" on public.mini_comments;
create policy "comments 작성" on public.mini_comments
  for insert to authenticated with check (author_id = auth.uid());

-- 신고: 본인 신고만 작성·확인 가능. 다른 사람(작성자 포함)은 누가 신고했는지 볼 수 없음.
--       전체 신고 목록은 운영자만 Supabase 대시보드에서 확인
drop policy if exists "reports 내 것만 읽기" on public.mini_reports;
create policy "reports 내 것만 읽기" on public.mini_reports
  for select to authenticated using (reporter_id = auth.uid());

drop policy if exists "reports 작성" on public.mini_reports;
create policy "reports 작성" on public.mini_reports
  for insert to authenticated with check (reporter_id = auth.uid() and status = 'pending');

------------------------------------------------------------
-- 7. 예시 글 3개 (테이블이 비어 있을 때만)
------------------------------------------------------------
insert into public.mini_posts (author_id, nickname, content, created_at)
select null, v.nickname, v.content, now() - v.ago
from (values
  ('초록고래', '오늘은 흰 셔츠에 연청 데님. 가을엔 역시 기본템이 최고예요.', interval '3 hours'),
  ('라떼한잔', '베이지 트렌치코트 꺼냈어요. 안에는 스트라이프 티셔츠!',     interval '1 day'),
  ('달빛토끼', '체크 셔츠 + 와이드 슬랙스 조합 추천해요.',                 interval '3 days')
) as v(nickname, content, ago)
where not exists (select 1 from public.mini_posts);

------------------------------------------------------------
-- [운영자용] 신고 처리 예시 — 필요할 때 한 줄씩 실행
------------------------------------------------------------
-- 신고 목록 보기:
--   select r.created_at, r.reason, r.detail, r.status, p.content, p.report_count
--   from mini_reports r join mini_posts p on p.id = r.post_id order by r.created_at desc;
-- 위반 → 글 삭제:            delete from mini_posts where id = '게시글ID';
-- 위반 아님 → 숨김 해제:     update mini_reports set status = 'dismissed' where post_id = '게시글ID';
--                            update mini_posts set report_count = 0 where id = '게시글ID';
