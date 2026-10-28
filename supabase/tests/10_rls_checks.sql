-- 마이그레이션 적용 후 실행하는 검증 스크립트 (실패하면 에러로 중단)
\set ON_ERROR_STOP on
insert into auth.users (id) values
  ('11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222');

create function pg_temp.expect_error(sql text, label text) returns void language plpgsql as $$
begin
  execute sql;
  raise exception 'FAIL (에러가 나야 함): %', label;
exception when others then
  if sqlerrm like 'FAIL%' then raise; end if;
  raise notice 'ok  - % (%: %)', label, sqlstate, sqlerrm;
end $$;
create function pg_temp.check(cond boolean, label text) returns void language plpgsql as $$
begin
  if not cond then raise exception 'FAIL: %', label; end if;
  raise notice 'ok  - %', label;
end $$;
grant execute on all functions in schema pg_temp to authenticated;

-- ===== 사용자 A =====
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

insert into profiles (id, nickname) values (auth.uid(), '미니멀러');
select pg_temp.expect_error($$insert into profiles (id, nickname) values ('22222222-2222-2222-2222-222222222222', '남의계정')$$, 'A2 다른 UID로 프로필 생성 차단');
select pg_temp.expect_error($$update profiles set nickname = '열한글자닉네임입니다요' where id = auth.uid()$$, 'A2 닉네임 10자 초과 차단');

insert into posts (image_path, content, tags, purchase_url)
values ('11111111-1111-1111-1111-111111111111/a.jpg', '흰 셔츠 코디', array['#화이트셔츠','#캐주얼'], 'https://shop.example.com/1');
select pg_temp.expect_error($$insert into posts (author_id, image_path) values ('22222222-2222-2222-2222-222222222222', 'x.jpg')$$, 'B2 다른 사람 명의로 글 작성 차단');
select pg_temp.expect_error($$insert into posts (image_path, purchase_url) values ('a.jpg', 'javascript:alert(1)')$$, 'B5 http(s) 아닌 구매 링크 차단');
select pg_temp.expect_error($$update posts set likes_count = 999$$, 'C1 좋아요 수 직접 수정 차단');
insert into clothing_tags (post_id, name, brand, x, y) select id, '옥스포드 셔츠', '무지', 0.5, 0.3 from posts limit 1;
insert into storage.objects (bucket_id, name) values ('ootd-images', '11111111-1111-1111-1111-111111111111/a.jpg');
select pg_temp.expect_error($$insert into storage.objects (bucket_id, name) values ('ootd-images', '22222222-2222-2222-2222-222222222222/b.jpg')$$, 'Storage 남의 폴더 업로드 차단');

-- ===== 사용자 B =====
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select pg_temp.expect_error($$insert into posts (image_path) values ('a.jpg')$$, 'A2 닉네임 설정 전 글 작성 차단');
select pg_temp.expect_error($$insert into profiles (id, nickname) values (auth.uid(), '미니멀러')$$, 'A2 중복 닉네임 차단');
insert into profiles (id, nickname) values (auth.uid(), '데님장인');
select pg_temp.check(not is_nickname_available('미니멀러'), 'A2 남이 쓰는 닉네임은 사용 불가');
select pg_temp.check(is_nickname_available('데님장인'), 'A2 내 닉네임은 사용 가능으로 표시');
update profiles set nickname = '청청패션' where id = auth.uid();
select pg_temp.check((select nickname from profiles where id = auth.uid()) = '청청패션', 'A2 닉네임 변경');
update profiles set nickname = '데님장인' where id = auth.uid();

select pg_temp.check((select count(*) from post_feed) = 1, 'B1 피드 조회');
update posts set content = '해킹';
select pg_temp.check((select content from posts limit 1) = '흰 셔츠 코디', 'B2 남의 글 수정 불가');
delete from posts;
select pg_temp.check((select count(*) from posts) = 1, 'B2 남의 글 삭제 불가');
select pg_temp.expect_error($$insert into clothing_tags (post_id, name, x, y) select id, '가짜', 0.1, 0.1 from posts limit 1$$, 'C5 남의 글에 옷 태그 추가 차단');

insert into post_likes (post_id) select id from posts limit 1;
select pg_temp.check((select likes_count from posts limit 1) = 1, 'C1 좋아요 수 자동 증가');
select pg_temp.check((select liked_by_me from post_feed limit 1), 'C1 liked_by_me = true');
select pg_temp.expect_error($$insert into post_likes (post_id) select id from posts limit 1$$, 'C1 중복 좋아요 차단');
select pg_temp.check((select count(*) from post_likes l join profiles p on p.id = l.user_id where p.nickname = '데님장인') = 1, 'C3 좋아요한 사람 닉네임 조회');

insert into comments (post_id, content) select id, '셔츠 어디 거예요?' from posts limit 1;
select pg_temp.check((select comments_count from posts limit 1) = 1, 'C2 댓글 수 자동 증가');
select pg_temp.expect_error($$insert into comments (post_id, content) select id, '   ' from posts limit 1$$, 'C2 빈 댓글 차단');

insert into reports (post_id, reason) select id, 'spam' from posts limit 1;
select pg_temp.expect_error($$insert into reports (post_id, reason) select id, 'spam' from posts limit 1$$, 'C4 같은 글 중복 신고 차단');
select pg_temp.expect_error($$insert into reports (post_id, reason) select id, 'weird' from posts limit 1$$, 'C4 정해진 사유만 허용');

select pg_temp.check((select count(*) from get_popular_posts(7, 10)) = 1, 'E2 인기 게시물 조회');
select pg_temp.check((select count(*) from post_feed where tags @> array['#화이트셔츠']) = 1, 'F1 태그 검색');

delete from post_likes where post_id = (select id from posts limit 1);
select pg_temp.check((select likes_count from posts limit 1) = 0, 'C1 좋아요 취소 시 감소');

-- ===== 사용자 A : 본인 글 수정·삭제 =====
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select pg_temp.check((select count(*) from reports) = 0, 'C4 남의 신고 내역 조회 불가');
update posts set content = '수정한 내용';
select pg_temp.check((select content from posts limit 1) = '수정한 내용', 'D1 본인 글 수정');
delete from posts;
select pg_temp.check((select count(*) from comments) = 0 and (select count(*) from clothing_tags) = 0, 'D1 글 삭제 시 댓글·태그 함께 삭제');

-- ===== 로그인 안 한 사용자(anon) =====
reset role;
set role anon;
select pg_temp.expect_error($$select * from posts$$, '비로그인(anon) 접근 차단');
reset role;
\echo ALL CHECKS PASSED
