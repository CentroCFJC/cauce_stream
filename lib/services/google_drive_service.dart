import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/category.dart';
import '../models/video_item.dart';

class GoogleDriveService {
  final http.Client _client;

  GoogleDriveService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Category>> fetchCatalog() async {
    final folderNames = await _listFolderNames();
    final categories = <Category>[];

    for (final folder in folderNames) {
      final videos = await _listVideosInFolder(folder);
      if (videos.isNotEmpty) {
        DateTime? modifiedTime;
        if (folder['modifiedTime'] != null && folder['modifiedTime']!.isNotEmpty) {
          modifiedTime = DateTime.tryParse(folder['modifiedTime']!);
        }
        categories.add(Category(
          id: folder['id']!,
          name: folder['name']!,
          videos: videos,
          modifiedTime: modifiedTime,
        ));
      }
    }

    return categories;
  }

  Future<List<Map<String, String>>> _listFolderNames() async {
    final url = '${AppConfig.driveBaseUrl}/files'
        '?q=%27${AppConfig.driveFolderId}%27+in+parents'
        '+and+mimeType=%27application/vnd.google-apps.folder%27'
        '+and+trashed=false'
        '&key=${AppConfig.driveApiKey}'
        '&fields=files(id,name,modifiedTime)'
        '&orderBy=modifiedTime+desc';

    try {
      final response = await _client.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final files = data['files'] as List<dynamic>? ?? [];
        return files.map((f) => {
          'id': f['id'] as String,
          'name': f['name'] as String,
          'modifiedTime': f['modifiedTime'] as String? ?? '',
        }).toList();
      }
    } catch (_) {}

    return [];
  }

  Future<List<VideoItem>> _listVideosInFolder(Map<String, String> folder) async {
    final url = '${AppConfig.driveBaseUrl}/files'
        '?q=%27${folder['id']}%27+in+parents'
        '+and+mimeType+contains+%27video%27'
        '+and+trashed=false'
        '&key=${AppConfig.driveApiKey}'
        '&fields=files(id,name,videoMediaMetadata)';

    try {
      final response = await _client.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final files = data['files'] as List<dynamic>? ?? [];
        final videos = <VideoItem>[];

        for (final f in files) {
          final fileId = f['id'] as String;
          final fileName = f['name'] as String;

          if (!fileName.endsWith('.mp4')) continue;

          final thumbnailUrl = await _resolveThumbnail(fileId, fileName, folder['id']!);
          final videoUrl = '${AppConfig.driveDownloadUrl}/$fileId?alt=media&key=${AppConfig.driveApiKey}';

          final metadata = f['videoMediaMetadata'] as Map<String, dynamic>?;
          String? duration;
          if (metadata != null && metadata.containsKey('durationMillis')) {
            final millis = int.tryParse(metadata['durationMillis'].toString());
            if (millis != null) {
              duration = _formatDuration(millis);
            }
          }

          videos.add(VideoItem(
            id: fileId,
            name: fileName.replaceAll('.mp4', ''),
            videoUrl: videoUrl,
            thumbnailUrl: thumbnailUrl,
            duration: duration,
          ));
        }

        return videos;
      }
    } catch (_) {}

    return [];
  }

  Future<String?> _resolveThumbnail(String fileId, String fileName, String folderId) async {
    final baseName = fileName.replaceAll('.mp4', '');

    for (final ext in ['jpg', 'png']) {
      final imageName = '$baseName.$ext';
      final searchUrl = '${AppConfig.driveBaseUrl}/files'
          '?q=name=%27$imageName%27'
          '+and+%27$folderId%27+in+parents'
          '+and+trashed=false'
          '&key=${AppConfig.driveApiKey}'
          '&fields=files(id)';
      try {
        final response = await _client.get(Uri.parse(searchUrl));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final files = data['files'] as List<dynamic>? ?? [];
          if (files.isNotEmpty) {
            final imageId = files[0]['id'] as String;
            return '${AppConfig.driveDownloadUrl}/$imageId?alt=media&key=${AppConfig.driveApiKey}';
          }
        }
      } catch (_) {}
    }

    final detailUrl = '${AppConfig.driveBaseUrl}/files/$fileId'
        '?key=${AppConfig.driveApiKey}'
        '&fields=thumbnailLink';

    try {
      final detailResponse = await _client.get(Uri.parse(detailUrl));
      if (detailResponse.statusCode == 200) {
        final detailData = jsonDecode(detailResponse.body) as Map<String, dynamic>;
        if (detailData.containsKey('thumbnailLink') && detailData['thumbnailLink'] != null) {
          return detailData['thumbnailLink'] as String;
        }
      }
    } catch (_) {}

    return null;
  }

  String _formatDuration(int millis) {
    final totalSeconds = millis ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void dispose() {
    _client.close();
  }
}
