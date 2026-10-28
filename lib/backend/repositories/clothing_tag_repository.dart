import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_exception.dart';
import '../core/supabase_config.dart';
import '../models/clothing_tag.dart';

/// [C5] 사진 위 옷 태그 (게시글 작성자만 추가·삭제 가능 — RLS 가 보장)
class ClothingTagRepository {
  final SupabaseClient _db;
  ClothingTagRepository([SupabaseClient? client]) : _db = client ?? SupabaseConfig.client;

  /// 게시글의 옷 태그 목록 (상세 화면에서 사진 위에 표시)
  Future<List<ClothingTag>> fetchTags(int postId) => guard(() async {
        final rows = await _db.from('clothing_tags').select().eq('post_id', postId).order('id');
        return rows.map(ClothingTag.fromJson).toList();
      });

  /// 게시글의 옷 태그를 [tags] 로 통째로 교체 (수정 화면용)
  Future<List<ClothingTag>> replaceTags(int postId, List<ClothingTag> tags) => guard(() async {
        await _db.from('clothing_tags').delete().eq('post_id', postId);
        if (tags.isEmpty) return <ClothingTag>[];
        final rows = await _db.from('clothing_tags').insert(tags.map((t) => t.toInsert(postId)).toList()).select();
        return rows.map(ClothingTag.fromJson).toList();
      });
}
