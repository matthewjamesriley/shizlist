import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../core/constants/supabase_config.dart';

/// Result of image upload containing both thumbnail and main image URLs
class ImageUploadResult {
  final String thumbnailUrl;
  final String mainImageUrl;

  ImageUploadResult({
    required this.thumbnailUrl,
    required this.mainImageUrl,
  });
}

/// Service for handling image picking, compression, and upload
class ImageUploadService {
  final SupabaseClient _client = SupabaseService.client;
  final ImagePicker _picker = ImagePicker();
  final _uuid = const Uuid();

  /// Pick image from gallery
  Future<File?> pickFromGallery() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Pick image from camera
  Future<File?> pickFromCamera() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (picked == null) return null;
    return File(picked.path);
  }


  /// Compress and create square thumbnail (200x200)
  /// Crops from center to create a square before resizing
  Future<Uint8List?> createThumbnail(File imageFile) async {
    // Read the image
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    // Calculate square crop from center
    final size = image.width < image.height ? image.width : image.height;
    final x = (image.width - size) ~/ 2;
    final y = (image.height - size) ~/ 2;

    // Crop to square
    final cropped = img.copyCrop(image, x: x, y: y, width: size, height: size);

    // Resize to 200x200
    final resized = img.copyResize(cropped, width: 200, height: 200);

    // Encode as JPEG
    final jpegBytes = img.encodeJpg(resized, quality: 80);

    return Uint8List.fromList(jpegBytes);
  }

  /// Compress main image (max 900px, good quality)
  Future<Uint8List?> compressMainImage(File imageFile) async {
    final result = await FlutterImageCompress.compressWithFile(
      imageFile.absolute.path,
      minWidth: 900,
      minHeight: 900,
      quality: 85,
      format: CompressFormat.jpeg,
    );
    return result;
  }

  /// Process and upload image, returns URLs for thumbnail and main image
  /// [onProgress] callback receives values from 0.0 to 1.0
  Future<ImageUploadResult?> processAndUpload(
    File imageFile, {
    void Function(double progress, String status)? onProgress,
  }) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final imageId = _uuid.v4();
      
      // Step 1: Create thumbnail (0-30%)
      onProgress?.call(0.1, 'Creating thumbnail...');
      final thumbnailData = await createThumbnail(imageFile);
      if (thumbnailData == null) throw Exception('Failed to create thumbnail');
      onProgress?.call(0.3, 'Thumbnail created');

      // Step 2: Compress main image (30-60%)
      onProgress?.call(0.35, 'Compressing image...');
      final mainImageData = await compressMainImage(imageFile);
      if (mainImageData == null) throw Exception('Failed to compress image');
      onProgress?.call(0.6, 'Image compressed');

      // Step 3: Upload thumbnail (60-80%)
      onProgress?.call(0.65, 'Uploading thumbnail...');
      final thumbnailPath = '$userId/$imageId-thumb.jpg';
      await _client.storage
          .from(SupabaseConfig.itemImagesBucket)
          .uploadBinary(thumbnailPath, thumbnailData,
              fileOptions: const FileOptions(contentType: 'image/jpeg'));
      onProgress?.call(0.8, 'Thumbnail uploaded');

      // Step 4: Upload main image (80-100%)
      onProgress?.call(0.85, 'Uploading image...');
      final mainImagePath = '$userId/$imageId-main.jpg';
      await _client.storage
          .from(SupabaseConfig.itemImagesBucket)
          .uploadBinary(mainImagePath, mainImageData,
              fileOptions: const FileOptions(contentType: 'image/jpeg'));
      onProgress?.call(1.0, 'Complete');

      // Get public URLs
      final thumbnailUrl = _client.storage
          .from(SupabaseConfig.itemImagesBucket)
          .getPublicUrl(thumbnailPath);
      final mainImageUrl = _client.storage
          .from(SupabaseConfig.itemImagesBucket)
          .getPublicUrl(mainImagePath);

      return ImageUploadResult(
        thumbnailUrl: thumbnailUrl,
        mainImageUrl: mainImageUrl,
      );
    } catch (e) {
      onProgress?.call(0, 'Error: $e');
      rethrow;
    }
  }

  /// Delete images from storage
  Future<void> deleteImages(String thumbnailUrl, String mainImageUrl) async {
    try {
      // Extract paths from URLs
      final thumbnailPath = _extractPath(thumbnailUrl);
      final mainImagePath = _extractPath(mainImageUrl);

      if (thumbnailPath != null) {
        await _client.storage
            .from(SupabaseConfig.itemImagesBucket)
            .remove([thumbnailPath]);
      }
      if (mainImagePath != null) {
        await _client.storage
            .from(SupabaseConfig.itemImagesBucket)
            .remove([mainImagePath]);
      }
    } catch (e) {
      // Silently fail - images might already be deleted
    }
  }

  String? _extractPath(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      // Find index of bucket name and get everything after
      final bucketIndex = pathSegments.indexOf(SupabaseConfig.itemImagesBucket);
      if (bucketIndex >= 0 && bucketIndex < pathSegments.length - 1) {
        return pathSegments.sublist(bucketIndex + 1).join('/');
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

