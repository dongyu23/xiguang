import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../fragment/domain/fragment.dart';
import '../domain/local_archive_repository.dart';
import '../domain/local_export_result.dart';

class LocalArchiveExporter implements LocalArchiveRepositoryPort {
  const LocalArchiveExporter();

  @override
  Future<LocalExportResult> exportFragments(
    List<Fragment> fragments,
  ) async {
    final root = await getApplicationDocumentsDirectory();
    final exportDir = Directory(p.join(
      root.path,
      'exports',
      'xiguang-${_timestamp(DateTime.now())}',
    ));
    final mediaDir = Directory(p.join(exportDir.path, 'media'));
    await mediaDir.create(recursive: true);

    var mediaCount = 0;
    final buffer = StringBuffer()
      ..writeln('# 隙光本地导出')
      ..writeln()
      ..writeln('- 导出时间：${DateTime.now().toLocal().toIso8601String()}')
      ..writeln('- 光片数量：${fragments.length}')
      ..writeln();

    for (final fragment in fragments) {
      buffer
        ..writeln('## ${fragment.dateLabel} ${fragment.time}')
        ..writeln()
        ..writeln('- 情绪：${fragment.emotion}')
        ..writeln('- 状态：${fragment.status}')
        ..writeln(
            '- 标签：${fragment.tags.isEmpty ? '无' : fragment.tags.join('、')}')
        ..writeln()
        ..writeln(
            fragment.contentText.isEmpty ? '（空白光片）' : fragment.contentText)
        ..writeln();

      for (var i = 0; i < fragment.mediaUrls.length; i++) {
        final exported = await _exportMedia(
          fragment.mediaUrls[i],
          mediaDir,
          fragment.id,
          i,
        );
        if (exported == null) continue;
        mediaCount++;
        buffer.writeln('- 媒体：media/${p.basename(exported.path)}');
      }
      buffer.writeln('\n---\n');
    }

    final markdown = File(p.join(exportDir.path, 'records.md'));
    await markdown.writeAsString(buffer.toString(), encoding: utf8);

    return LocalExportResult(
      directoryPath: exportDir.path,
      markdownPath: markdown.path,
      fragmentCount: fragments.length,
      mediaCount: mediaCount,
    );
  }

  Future<File?> _exportMedia(
    String source,
    Directory mediaDir,
    int fragmentId,
    int index,
  ) async {
    final value = source.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('data:')) {
      return _writeDataUrl(value, mediaDir, fragmentId, index);
    }
    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('/media/') ||
        value.startsWith('users/')) {
      return null;
    }

    final path = value.startsWith('file:')
        ? Uri.tryParse(value)?.toFilePath() ?? value
        : value;
    final file = File(path);
    if (!await file.exists()) return null;
    final extension = p.extension(path).isEmpty ? '.bin' : p.extension(path);
    final target =
        File(p.join(mediaDir.path, 'fragment_${fragmentId}_$index$extension'));
    return file.copy(target.path);
  }

  Future<File?> _writeDataUrl(
    String dataUrl,
    Directory mediaDir,
    int fragmentId,
    int index,
  ) async {
    final comma = dataUrl.indexOf(',');
    if (comma == -1 || !dataUrl.substring(0, comma).contains(';base64')) {
      return null;
    }
    final header = dataUrl.substring(0, comma);
    final body = dataUrl.substring(comma + 1);
    late final List<int> bytes;
    try {
      bytes = base64Decode(body);
    } on FormatException {
      return null;
    }
    final extension = _extensionForDataUrlHeader(header);
    final target =
        File(p.join(mediaDir.path, 'fragment_${fragmentId}_$index$extension'));
    await target.writeAsBytes(bytes, flush: true);
    return target;
  }

  String _extensionForDataUrlHeader(String header) {
    if (header.contains('image/jpeg')) return '.jpg';
    if (header.contains('image/png')) return '.png';
    if (header.contains('image/webp')) return '.webp';
    if (header.contains('image/heic')) return '.heic';
    if (header.contains('audio/mpeg')) return '.mp3';
    if (header.contains('audio/wav')) return '.wav';
    if (header.contains('audio/aac')) return '.aac';
    if (header.contains('audio/ogg')) return '.ogg';
    if (header.contains('audio/opus')) return '.opus';
    if (header.contains('audio/')) return '.m4a';
    return '.bin';
  }

  String _timestamp(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}${two(local.month)}${two(local.day)}-'
        '${two(local.hour)}${two(local.minute)}${two(local.second)}';
  }
}
