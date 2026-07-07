class VideoItem {
  final String id;
  final String name;
  final String videoUrl;
  final String? thumbnailUrl;
  final String? duration;

  const VideoItem({
    required this.id,
    required this.name,
    required this.videoUrl,
    this.thumbnailUrl,
    this.duration,
  });
}
