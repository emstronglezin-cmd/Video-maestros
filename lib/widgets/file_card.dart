import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Carte pour afficher un fichier
class FileCard extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;

  const FileCard({
    super.key,
    required this.file,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(file.path);
    final fileSize = _formatFileSize(file.lengthSync());
    final fileType = _getFileType(fileName);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getIconColor(fileType),
          child: Icon(_getIcon(fileType), color: Colors.white),
        ),
        title: Text(
          fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(fileSize),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onRemove,
          color: Colors.red,
        ),
      ),
    );
  }

  String _getFileType(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    if (['.mp4', '.mov', '.avi', '.mkv'].contains(ext)) return 'video';
    if (['.jpg', '.jpeg', '.png', '.gif'].contains(ext)) return 'image';
    if (['.mp3', '.wav', '.flac'].contains(ext)) return 'audio';
    return 'file';
  }

  IconData _getIcon(String fileType) {
    switch (fileType) {
      case 'video':
        return Icons.videocam;
      case 'image':
        return Icons.image;
      case 'audio':
        return Icons.audiotrack;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getIconColor(String fileType) {
    switch (fileType) {
      case 'video':
        return Colors.red;
      case 'image':
        return Colors.blue;
      case 'audio':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
