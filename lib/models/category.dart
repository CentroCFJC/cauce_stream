import 'video_item.dart';

class Category {
  final String id;
  final String name;
  final List<VideoItem> videos;
  final DateTime? modifiedTime;

  const Category({
    required this.id,
    required this.name,
    required this.videos,
    this.modifiedTime,
  });
}
