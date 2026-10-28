/// [C5] 사진 위 옷 태그. x, y 는 사진 크기 대비 0~1 비율 위치
class ClothingTag {
  final int? id;
  final String name;
  final String? brand;
  final String? linkUrl;
  final double x;
  final double y;

  const ClothingTag({this.id, required this.name, this.brand, this.linkUrl, required this.x, required this.y});

  factory ClothingTag.fromJson(Map<String, dynamic> j) => ClothingTag(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        brand: j['brand'] as String?,
        linkUrl: j['link_url'] as String?,
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
      );

  Map<String, dynamic> toInsert(int postId) => {
        'post_id': postId,
        'name': name,
        'brand': brand,
        'link_url': linkUrl,
        'x': x,
        'y': y,
      };
}
