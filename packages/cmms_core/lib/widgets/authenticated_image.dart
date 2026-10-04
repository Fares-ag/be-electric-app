import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_auth_service.dart';
import '../config/locator.dart';

/// Widget that loads images from Firebase Storage or Supabase Storage with
/// authentication when needed. Handles expired Supabase signed URLs by
/// fetching a fresh signed URL so technicians can see work order images.
class AuthenticatedImage extends StatefulWidget {
  const AuthenticatedImage({
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.height,
    this.width,
    this.errorWidget,
    this.placeholder,
    super.key,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? height;
  final double? width;
  final Widget? errorWidget;
  final Widget? placeholder;

  @override
  State<AuthenticatedImage> createState() => _AuthenticatedImageState();
}

class _AuthenticatedImageState extends State<AuthenticatedImage> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(AuthenticatedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _imageBytes = null;
    });

    try {
      final isFirebaseStorageUrl = widget.imageUrl.contains('firebasestorage.googleapis.com') ||
          widget.imageUrl.contains('storage.googleapis.com');
      final isSupabaseStorageUrl = widget.imageUrl.contains('supabase.co/storage');

      if (isFirebaseStorageUrl) {
        await _loadWithAuth();
      } else if (isSupabaseStorageUrl) {
        await _loadSupabaseStorage();
      } else {
        await _loadWithoutAuth();
      }
    } catch (e, st) {
      debugPrint('Error loading image: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  /// Parses Supabase Storage URL to (bucket, path) or null.
  /// Handles: .../object/public/BUCKET/PATH and .../object/sign/BUCKET/PATH?token=...
  static ({String bucket, String path})? _parseSupabaseStorageUrl(String url) {
    const publicPrefix = '/object/public/';
    const signPrefix = '/object/sign/';
    final uri = Uri.parse(url);
    final pathSegment = uri.path;
    String? suffix;
    if (pathSegment.contains(publicPrefix)) {
      final i = pathSegment.indexOf(publicPrefix);
      suffix = pathSegment.substring(i + publicPrefix.length);
    } else if (pathSegment.contains(signPrefix)) {
      final i = pathSegment.indexOf(signPrefix);
      suffix = pathSegment.substring(i + signPrefix.length);
    }
    if (suffix == null || suffix.isEmpty) return null;
    final parts = suffix.split('/');
    if (parts.length < 2) return null;
    final bucket = parts.first;
    final path = parts.sublist(1).join('/');
    return (bucket: bucket, path: path);
  }

  Future<void> _loadSupabaseStorage() async {
    // Try stored URL first (works for public bucket or still-valid signed URL)
    final response = await http.get(Uri.parse(widget.imageUrl));
    if (response.statusCode == 200 && mounted) {
      setState(() {
        _imageBytes = response.bodyBytes;
        _isLoading = false;
        _hasError = false;
      });
      return;
    }
    // 403/404 or other: try fresh signed URL (for private bucket or expired signed URL)
    final parsed = _parseSupabaseStorageUrl(widget.imageUrl);
    if (parsed == null || !mounted) {
      if (mounted) setState(() { _hasError = true; _isLoading = false; });
      return;
    }
    try {
      final signedUrl = await Supabase.instance.client.storage
          .from(parsed.bucket)
          .createSignedUrl(parsed.path, 3600);
      if (!mounted) return;
      final signedResponse = await http.get(Uri.parse(signedUrl));
      if (signedResponse.statusCode == 200 && mounted) {
        setState(() {
          _imageBytes = signedResponse.bodyBytes;
          _isLoading = false;
          _hasError = false;
        });
      } else if (mounted) {
        setState(() { _hasError = true; _isLoading = false; });
      }
    } catch (e, st) {
      debugPrint('Error loading Supabase image (signed URL): $e');
      if (mounted) setState(() { _hasError = true; _isLoading = false; });
    }
  }

  Future<void> _loadWithAuth() async {
    try {
      final authService = sl<SupabaseAuthService>();
      final token = await authService.getIdToken();

      final headers = <String, String>{};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse(widget.imageUrl),
        headers: headers,
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _imageBytes = response.bodyBytes;
          _isLoading = false;
          _hasError = false;
        });
      } else {
        // If auth fails, try without auth (in case token is in URL)
        await _loadWithoutAuth();
      }
    } catch (e, st) {
      debugPrint('Error loading image with auth: $e');
      // Fallback to loading without auth
      await _loadWithoutAuth();
    }
  }

  Future<void> _loadWithoutAuth() async {
    try {
      final response = await http.get(Uri.parse(widget.imageUrl));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _imageBytes = response.bodyBytes;
          _isLoading = false;
          _hasError = false;
        });
      } else if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('Error loading image without auth: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder ??
          Container(
            height: widget.height,
            width: widget.width,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
    }

    if (_hasError || _imageBytes == null) {
      return widget.errorWidget ??
          Container(
            height: widget.height,
            width: widget.width,
            color: Colors.grey[200],
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(height: 8),
                  Text('Failed to load image'),
                ],
              ),
            ),
          );
    }

    return Image.memory(
      _imageBytes!,
      fit: widget.fit,
      height: widget.height,
      width: widget.width,
    );
  }
}

