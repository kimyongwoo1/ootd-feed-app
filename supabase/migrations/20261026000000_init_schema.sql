-- =====================================================================
-- OOTD 피드 앱 - Supabase 백엔드 스키마
--   요구사항: A1~A2, B1~B5, C1~C5, D1~D2, E2, F1  (E1 날씨 추천은 제외)
--   적용 방법: Supabase 대시보드 > SQL Editor 에 붙여넣고 실행
--             또는 Supabase CLI 사용 시 `supabase db push`
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. 테이블
-- ---------------------------------------------------------------------

-- [A2] 사용자 프로필 : 익명 UID(auth.users.id)와 닉네임을 연결
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  nickname    varchar(10) not null,
  created_at  timestamptz not null default now(),
  constraint nickname_length check (char_length(nickname) between 1 and 10),
  constraint nickname_trimmed check (nickname = btrim(nickname))
);
-- 닉네임 중복 금지 (대소문자 구분 없이)
create unique index profiles_nickname_unique on public.profiles (lower(nickname));


-- [B1~B5, F1] 게시글
create table public.posts (
  id              bigint generated always as identity primary key,
  author_id       uuid not null default auth.uid()
                  references public.profiles (id) on delete cascade,
  image_path      text not null,                 -- Storage 버킷 안의 경로 ({uid}/{파일명})
  content         text not null default '',
  purchase_url    text,                          -- [B5] 구매 링크
  tags            text[] not null default '{}',  -- [F1] AI 추천 태그 중 사용자가 고른 것
  likes_count     integer not null default 0,    -- [C1] 트리거가 자동 관리
  comments_count  integer not null default 0,    -- [C2] 트리거가 자동 관리
  created_at      timestamptz not null default now(),   -- [B4] 서버 시간
  updated_at      timestamptz not null default now(),
  constraint content_length    check (char_length(content) <= 200),
  constraint purchase_url_http check (purchase_url is null or purchase_url ~* '^https?://'),
  constraint tags_max          check (cardinality(tags) <= 10),
  constraint counts_positive   check (likes_count >= 0 and comments_count >= 0)
);
create index posts_created_at_idx on public.posts (created_at desc, id desc);   -- 최신순 피드
create index posts_likes_idx      on public.posts (likes_count desc, created_at desc); -- 인기 랭킹
create index posts_tags_idx       on public.posts using gin (tags);             -- 태그 검색
create index posts_author_idx     on public.posts (author_id);


-- [C1] 좋아요 : (post_id, user_id) 복합 PK 로 중복 좋아요 차단
create table public.post_likes (
  post_id     bigint not null references public.posts (id) on delete cascade,
  user_id     uuid   not null default auth.uid()
              references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index post_likes_user_idx on public.post_likes (user_id);


-- [C2] 댓글
create table public.comments (
  id          bigint generated always as identity primary key,
  post_id     bigint not null references public.posts (id) on delete cascade,
  author_id   uuid   not null default auth.uid()
              references public.profiles (id) on delete cascade,
  content     text   not null,
  created_at  timestamptz not null default now(),
  constraint comment_length check (char_length(btrim(content)) between 1 and 300)
);
create index comments_post_idx on public.comments (post_id, created_at);


-- [C4] 게시글 신고 : 한 사용자가 같은 글을 한 번만 신고
create table public.reports (
  id           bigint generated always as identity primary key,
  post_id      bigint not null references public.posts (id) on delete cascade,
  reporter_id  uuid   not null default auth.uid()
               references public.profiles (id) on delete cascade,
  reason       text   not null,
  detail       text,
  created_at   timestamptz not null default now(),
  constraint report_reason check (reason in ('sexual', 'violence', 'spam', 'privacy', 'hate', 'other')),
  constraint report_detail_length check (detail is null or char_length(detail) <= 300),
  unique (post_id, reporter_id)
);


-- [C5] 옷 태그 : 사진 위 위치(x, y 는 0~1 비율)와 옷 정보
create table public.clothing_tags (
  id          bigint generated always as identity primary key,
  post_id     bigint not null references public.posts (id) on delete cascade,
  name        text   not null,
  brand       text,
  link_url    text,
  x           real   not null,
  y           real   not null,
  created_at  timestamptz not null default now(),
  constraint tag_name_length check (char_length(name) between 1 and 30),
  constraint tag_position    check (x between 0 and 1 and y between 0 and 1),
  constraint tag_link_http   check (link_url is null or link_url ~* '^https?://')
);
create index clothing_tags_post_idx on public.clothing_tags (post_id);


-- ---------------------------------------------------------------------
-- 2. 트리거 : 카운터 자동 관리, 수정 시간
-- ---------------------------------------------------------------------

-- [C1] 좋아요 추가/취소 시 posts.likes_count 증감
create function public.sync_likes_count() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update posts set likes_count = likes_count + 1 where id = new.post_id;
  else
    update posts set likes_count = greatest(likes_count - 1, 0) where id = old.post_id;
  end if;
  return null;
end $$;

create trigger on_like_change
after insert or delete on public.post_likes
for each row execute function public.sync_likes_count();


-- [C2] 댓글 추가/삭제 시 posts.comments_count 증감
create function public.sync_comments_count() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update posts set comments_count = comments_count + 1 where id = new.post_id;
  else
    update posts set comments_count = greatest(comments_count - 1, 0) where id = old.post_id;
  end if;
  return null;
end $$;

create trigger on_comment_change
after insert or delete on public.comments
for each row execute function public.sync_comments_count();


-- 게시글 내용을 수정했을 때만 updated_at 갱신 (좋아요·댓글 수 변화는 제외)
create function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  if (new.content, new.purchase_url, new.tags)
     is distinct from (old.content, old.purchase_url, old.tags) then
    new.updated_at = now();
  end if;
  return new;
end $$;

create trigger posts_touch_updated_at
before update on public.posts
for each row execute function public.touch_updated_at();


-- ---------------------------------------------------------------------
-- 3. 조회용 뷰 / 함수
-- ---------------------------------------------------------------------

-- [B1, B3] 피드용 뷰 : 게시글 + 작성자 닉네임 + 내가 좋아요 눌렀는지
--   security_invoker = on → 호출한 사용자의 RLS 가 그대로 적용됨
create view public.post_feed with (security_invoker = on) as
select
  p.id,
  p.author_id,
  pr.nickname,
  p.image_path,
  p.content,
  p.purchase_url,
  p.tags,
  p.likes_count,
  p.comments_count,
  p.created_at,
  p.updated_at,
  exists (
    select 1 from public.post_likes l
    where l.post_id = p.id and l.user_id = auth.uid()
  ) as liked_by_me,
  (p.author_id = auth.uid()) as is_mine
from public.posts p
join public.profiles pr on pr.id = p.author_id;


-- [A2] 닉네임 사용 가능 여부 (대소문자 구분 없이, 내 현재 닉네임은 사용 가능으로 처리)
create function public.is_nickname_available(p_nickname text)
returns boolean
language sql stable security definer set search_path = public as $$
  select not exists (
    select 1 from profiles
    where lower(nickname) = lower(btrim(p_nickname))
      and id is distinct from auth.uid()
  );
$$;


-- [E2] 인기 게시물 랭킹 : 최근 p_days 일 동안 작성된 글을 좋아요 순으로
create function public.get_popular_posts(p_days integer default 7, p_limit integer default 20)
returns setof public.post_feed
language sql stable security invoker set search_path = public as $$
  select *
  from post_feed
  where created_at >= now() - make_interval(days => greatest(p_days, 1))
  order by likes_count desc, created_at desc
  limit least(greatest(p_limit, 1), 50);
$$;


-- ---------------------------------------------------------------------
-- 4. 권한 : 카운터·작성자는 앱에서 직접 수정할 수 없도록 컬럼 단위 제한
-- ---------------------------------------------------------------------
revoke update on public.posts from anon, authenticated;
grant  update (content, purchase_url, tags) on public.posts to authenticated;

revoke update on public.profiles from anon, authenticated;
grant  update (nickname) on public.profiles to authenticated;

revoke update on public.post_likes, public.comments, public.reports from anon, authenticated;

revoke all on public.posts, public.profiles, public.post_likes, public.comments,
              public.reports, public.clothing_tags from anon;
revoke all on public.post_feed from anon;
revoke execute on function public.get_popular_posts(integer, integer) from anon, public;
grant  execute on function public.get_popular_posts(integer, integer) to authenticated;
revoke execute on function public.is_nickname_available(text) from anon, public;
grant  execute on function public.is_nickname_available(text) to authenticated;
revoke execute on function public.sync_likes_count(), public.sync_comments_count() from anon, authenticated, public;


-- ---------------------------------------------------------------------
-- 5. Row Level Security (모든 테이블 필수)
--   'authenticated' 역할에는 익명 로그인 사용자도 포함된다.
-- ---------------------------------------------------------------------
alter table public.profiles      enable row level security;
alter table public.posts         enable row level security;
alter table public.post_likes    enable row level security;
alter table public.comments      enable row level security;
alter table public.reports       enable row level security;
alter table public.clothing_tags enable row level security;

-- profiles
create policy profiles_select on public.profiles
  for select to authenticated using (true);
create policy profiles_insert_own on public.profiles
  for insert to authenticated with check (id = (select auth.uid()));
create policy profiles_update_own on public.profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- posts
create policy posts_select on public.posts
  for select to authenticated using (true);
create policy posts_insert_own on public.posts
  for insert to authenticated with check (author_id = (select auth.uid()));
create policy posts_update_own on public.posts
  for update to authenticated using (author_id = (select auth.uid())) with check (author_id = (select auth.uid()));
create policy posts_delete_own on public.posts
  for delete to authenticated using (author_id = (select auth.uid()));

-- post_likes
create policy likes_select on public.post_likes
  for select to authenticated using (true);
create policy likes_insert_own on public.post_likes
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy likes_delete_own on public.post_likes
  for delete to authenticated using (user_id = (select auth.uid()));

-- comments
create policy comments_select on public.comments
  for select to authenticated using (true);
create policy comments_insert_own on public.comments
  for insert to authenticated with check (author_id = (select auth.uid()));
create policy comments_delete_own on public.comments
  for delete to authenticated using (author_id = (select auth.uid()));

-- reports : 본인이 한 신고만 조회 가능 (신고 내역은 운영자가 대시보드에서 확인)
create policy reports_select_own on public.reports
  for select to authenticated using (reporter_id = (select auth.uid()));
create policy reports_insert_own on public.reports
  for insert to authenticated with check (reporter_id = (select auth.uid()));

-- clothing_tags : 누구나 조회, 게시글 작성자만 추가·수정·삭제
create policy clothing_tags_select on public.clothing_tags
  for select to authenticated using (true);
create policy clothing_tags_write_own on public.clothing_tags
  for all to authenticated
  using (exists (select 1 from public.posts p where p.id = post_id and p.author_id = (select auth.uid())))
  with check (exists (select 1 from public.posts p where p.id = post_id and p.author_id = (select auth.uid())));


-- ---------------------------------------------------------------------
-- 6. Storage : 게시글 사진 버킷
--   - 공개 읽기 (피드에서 URL 로 바로 표시)
--   - 업로드·삭제는 로그인 사용자가 자기 UID 폴더({uid}/...)에만 가능
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('ootd-images', 'ootd-images', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy ootd_images_insert_own on storage.objects
  for insert to authenticated
  with check (bucket_id = 'ootd-images' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy ootd_images_delete_own on storage.objects
  for delete to authenticated
  using (bucket_id = 'ootd-images' and (storage.foldername(name))[1] = (select auth.uid())::text);


-- ---------------------------------------------------------------------
-- 7. Realtime [C2, D1] : 게시글·댓글 변경을 다른 기기에 실시간 전달
--   (좋아요 수 변화는 트리거가 posts 를 UPDATE 하므로 posts 구독으로 전달됨)
-- ---------------------------------------------------------------------
alter publication supabase_realtime add table public.posts, public.comments;
