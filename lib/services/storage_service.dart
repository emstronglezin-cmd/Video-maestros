import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';

/// Service pour l'upload direct vers Firebase Storage
class StorageService {
  static const String baseUrl = 'https://video-maestros-production.up.railway.app';
  
  String? _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  /// Upload un fichier directement vers Firebase Storage
  Future<String> uploadFile(File file) async {
    try {
      // Étape 1: Obtenir une URL signée du backend
      final fileName = file.path.split('/').last;
      final contentType = _getContentType(fileName);

      final signedUrlResponse = await http.post(
        Uri.parse('$baseUrl/api/storage/signed-url'),
        headers: _getHeaders(),
        body: json.encode({
          'fileName': fileName,
          'contentType': contentType,
        }),
      );

      if (signedUrlResponse.statusCode != 200) {
        throw Exception('Failed to get signed URL: ${signedUrlResponse.body}');
      }

      final signedUrlData = json.decode(signedUrlResponse.body);
      if (signedUrlData['success'] != true) {
        throw Exception(signedUrlData['error'] ?? 'Failed to get signed URL');
      }

      final signedUrl = signedUrlData['data']['signedUrl'] as String;
      final storagePath = signedUrlData['data']['storagePath'] as String;

      // Étape 2: Upload le fichier vers l'URL signée
      final fileBytes = await file.readAsBytes();
      
      final uploadResponse = await http.put(
        Uri.parse(signedUrl),
        headers: {
          'Content-Type': contentType,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );

      if (uploadResponse.statusCode != 200 && uploadResponse.statusCode != 201) {
        throw Exception('Failed to upload file: ${uploadResponse.statusCode}');
      }

      // Retourne le storage path
      return storagePath;
    } catch (e) {
      throw Exception('Error uploading file: $e');
    }
  }

  /// Upload plusieurs fichiers en parallèle
  Future<List<String>> uploadFiles(List<File> files) async {
    final uploadFutures = files.map((file) => uploadFile(file)).toList();
    return await Future.wait(uploadFutures);
  }

  /// Obtient une URL de téléchargement signée
  Future<String> getDownloadUrl(String storagePath) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/storage/signed-download-url'),
        headers: _getHeaders(),
        body: json.encode({
          'storagePath': storagePath,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get download URL: ${response.body}');
      }

      final data = json.decode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to get download URL');
      }

      return data['data']['signedUrl'] as String;
    } catch (e) {
      throw Exception('Error getting download URL: $e');
    }
  }

  /// Détermine le content type depuis le nom de fichier
  String _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mkv':
        return 'video/x-matroska';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'flac':
        return 'audio/flac';
      default:
        return 'application/octet-stream';
    }
  }

  /// Upload avec indicateur de progression (alternative)
  Future<String> uploadFileWithProgress(
    File file,
    void Function(double progress)? onProgress,
  ) async {
    try {
      final fileName = file.path.split('/').last;
      final storageRef = FirebaseStorage.instance.ref().child('uploads/$fileName');
      
      final uploadTask = storageRef.putFile(file);
      
      // Écouter la progression
      uploadTask.snapshotEvents.listen((event) {
        final progress = event.bytesTransferred / event.totalBytes;
        onProgress?.call(progress);
      });
      
      // Attendre la fin de l'upload
      await uploadTask;
      
      // Récupérer l'URL de téléchargement
      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Error uploading file with progress: $e');
    }
  }
}
