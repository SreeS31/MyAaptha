import 'package:http_parser/http_parser.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static Future<int?> Function(Map<String, dynamic> level)? retentionChooser;
  ApiClient({required this.baseUrl, http.Client? httpClient, this.accessTokenProvider})
      : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;
  final Future<String> Function()? accessTokenProvider;

  Future<ApiResponse> get(String path, {String? bearerToken}) async {
    _validatePath(path);
    final uri = Uri.parse('$baseUrl$path');
    // Authenticated data must never be persisted in SharedPreferences or
    // replayed after permissions change. Remove legacy plaintext caches.
    await _purgeLegacyCache();
    final response = await _httpClient
        .get(uri, headers: await _headers(bearerToken: bearerToken))
        .timeout(const Duration(seconds: 15));
    return ApiResponse.fromHttp(response);
  }

  Future<void>? _cacheCleanup;
  Future<void> _purgeLegacyCache() => _cacheCleanup ??= () async {
        final prefs = await SharedPreferences.getInstance();
        for (final key in prefs
            .getKeys()
            .where((key) => key.startsWith('api_cache_'))
            .toList()) {
          await prefs.remove(key);
        }
      }();
  Future<ApiResponse> post(
    String path,
    Map<String, dynamic> body, {
    String? bearerToken,
  }) async {
    _validatePath(path);
    _validatePayload(body);
    final uri = Uri.parse('$baseUrl$path');
    final response = await _httpClient.post(
      uri,
      headers: await _headers(bearerToken: bearerToken),
      body: jsonEncode(body),
    );
    return ApiResponse.fromHttp(response);
  }

  Future<ApiResponse> put(
    String path,
    Map<String, dynamic> body, {
    String? bearerToken,
  }) async {
    _validatePath(path);
    _validatePayload(body);
    final response = await _httpClient.put(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(bearerToken: bearerToken),
      body: jsonEncode(body),
    );
    return ApiResponse.fromHttp(response);
  }

  Future<ApiResponse> delete(String path, {String? bearerToken}) async {
    _validatePath(path);
    final response = await _httpClient.delete(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(bearerToken: bearerToken),
    );
    return ApiResponse.fromHttp(response);
  }

  Future<ApiResponse> postMultipart(
    String path,
    Map<String, String> fields, {
    String? bearerToken,
    Uint8List? fileBytes,
    String? fileName,
    String? fileContentType,
    bool requestRetention = true,
    void Function(double progress)? onProgress,
  }) async {
    _validatePath(path);
    _validatePayload(fields);
    if (fileBytes != null && fileBytes.length > 25 * 1024 * 1024) {
      throw const FormatException('Attachment must be 25 MB or smaller.');
    }
    if (fileBytes != null && fileBytes.isEmpty) {
      throw const FormatException('Attachment must not be empty.');
    }
    if (fileName != null) {
      _validateString('fileName', fileName);
      _validateUploadFile(fileName, fileBytes);
    }
    final uploadFields = Map<String, String>.from(fields);
    if (fileBytes != null && requestRetention && retentionChooser != null) {
      final response = await get('/api/uploads/policy', bearerToken: bearerToken);
      if (response.statusCode != 200) throw const FormatException('Could not load upload limits. Please retry.');
      final policy = jsonDecode(response.body) as Map<String, dynamic>;
      final level = policy['level'] as Map<String, dynamic>;
      if (fileBytes.length > (level['uploadBytes'] as num)) throw const FormatException('File exceeds your user level upload limit.');
      if ((policy['usedBytes'] as num) + fileBytes.length > (level['storageBytes'] as num)) throw const FormatException('Storage is full. Remove files or contact your administrator.');
      if (path.endsWith('/stories')) {
        uploadFields['retentionDays'] = '1';
      } else if (!uploadFields.containsKey('retentionDays')) {
        final days = await retentionChooser!(level);
        if (days == null) throw const FormatException('Upload cancelled.');
        uploadFields['retentionDays'] = days.toString();
      }
    }
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'))
      ..fields.addAll(uploadFields);
    if (fileBytes != null && fileName != null) {
      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName, contentType: fileContentType==null?null:MediaType.parse(fileContentType)),
      );
    }
    if (bearerToken != null && bearerToken.isNotEmpty) {
      bearerToken = await accessTokenProvider?.call() ?? bearerToken;
      request.headers['Authorization'] = 'Bearer $bearerToken';
    }
    final streamed = onProgress == null
        ? await _httpClient.send(request)
        : await _httpClient.send(_ProgressRequest(request, onProgress));
    return ApiResponse.fromHttp(await http.Response.fromStream(streamed));
  }

  void _validateUploadFile(String fileName, Uint8List? bytes) {
    const blocked = {
      'exe',
      'dll',
      'com',
      'scr',
      'msi',
      'bat',
      'cmd',
      'ps1',
      'vbs',
      'js',
      'jar',
      'war',
      'class',
      'sh',
      'php',
      'html',
      'htm',
      'svg',
      'apk',
      'ipa',
      'dmg',
      'iso',
      'lnk',
      'doc',
      'xls',
      'ppt',
      'docm',
      'xlsm',
      'pptm'
    };
    const allowed = {
      'jpg',
      'jpeg',
      'jfif',
      'png',
      'webp',
      'gif',
      'bmp',
      'tif',
      'tiff',
      'avif',
      'heic',
      'heif',
      'ico',
      'psd',
      'dng',
      'cr2',
      'nef',
      'arw',
      'mp3',
      'm4a',
      'aac',
      'wav',
      'flac',
      'ogg',
      'oga',
      'opus',
      'amr',
      'aif',
      'aiff',
      'mid',
      'midi',
      'mp4',
      'm4v',
      'mov',
      'avi',
      'mkv',
      'webm',
      'mpeg',
      'mpg',
      'ogv',
      '3gp',
      '3g2',
      'flv',
      'pdf',
      'txt',
      'csv',
      'vcf',
      'docx',
      'xlsx',
      'pptx',
      'glb',
      'gltf',
      'obj',
      'stl',
      'fbx',
      '3mf',
      'dae',
      'ply',
      'usdz',
      'blend'
    };
    if (fileName.length > 255 || fileName.contains(':') || fileName.runes.any((c) => c < 32 || c == 127 || (c >= 0x202a && c <= 0x202e))) { throw const FormatException('Invalid attachment filename.'); }
    if (bytes != null && (_starts(bytes, [77, 90]) || _starts(bytes, [127, 69, 76, 70]) || String.fromCharCodes(bytes.take(8192)).contains('EICAR-STANDARD-ANTIVIRUS-TEST-FILE'))) { throw const FormatException('Unsafe attachment detected.'); }
    final parts = fileName.toLowerCase().split('.');
    if (parts.length < 2 ||
        parts.skip(1).any(blocked.contains) ||
        !allowed.contains(parts.last)) {
      throw const FormatException(
          'This file type is blocked for security reasons.');
    }
    if (bytes != null && {'docx','xlsx','pptx'}.contains(parts.last) && !_starts(bytes,[80,75,3,4])) { throw const FormatException('File contents do not match the document extension.'); }
    if (bytes != null &&
        parts.last == 'pdf' &&
        !_starts(bytes, [0x25, 0x50, 0x44, 0x46, 0x2d])) {
      throw const FormatException(
          'File contents do not match the PDF extension.');
    }
    if (bytes != null &&
        {'jpg', 'jpeg', 'jfif'}.contains(parts.last) &&
        !_starts(bytes, [0xff, 0xd8, 0xff])) {
      throw const FormatException(
          'File contents do not match the image extension.');
    }
    if (bytes != null &&
        parts.last == 'png' &&
        !_starts(bytes, [0x89, 0x50, 0x4e, 0x47])) {
      throw const FormatException(
          'File contents do not match the image extension.');
    }
  }

  bool _starts(Uint8List bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  }

  Future<Map<String, String>> _headers({String? bearerToken}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (bearerToken != null && bearerToken.isNotEmpty) {
      bearerToken = await accessTokenProvider?.call() ?? bearerToken;
      headers['Authorization'] = 'Bearer $bearerToken';
    }
    return headers;
  }

  void _validatePath(String path) {
    if (path.length > 8192 || !path.startsWith('/api/')) {
      throw const FormatException('Invalid API request path.');
    }
    if (_controlCharacters.hasMatch(path)) {
      throw const FormatException(
        'Request path contains unsupported characters.',
      );
    }
    final uri = Uri.tryParse(path);
    if (uri == null) {
      throw const FormatException('Invalid API request path.');
    }
    for (final entry in uri.queryParametersAll.entries) {
      _validateString(entry.key, entry.key);
      for (final value in entry.value) {
        _validateString(entry.key, value);
      }
    }
  }

  void _validatePayload(
    Object? value, [
    String field = 'request',
    int depth = 0,
  ]) {
    if (depth > 12) {
      throw const FormatException('Request structure is too deeply nested.');
    }
    if (value == null || value is num || value is bool) return;
    if (value is String) {
      _validateString(field, value);
      return;
    }
    if (value is List) {
      if (value.length > 1000) {
        throw FormatException('$field has too many items.');
      }
      for (var index = 0; index < value.length; index++) {
        _validatePayload(value[index], '$field[$index]', depth + 1);
      }
      return;
    }
    if (value is Map) {
      if (value.length > 1000) {
        throw FormatException('$field has too many entries.');
      }
      for (final entry in value.entries) {
        final key = entry.key.toString();
        _validateString('fieldName', key);
        _validatePayload(entry.value, key, depth + 1);
      }
      return;
    }
    throw FormatException('$field contains an unsupported value.');
  }

  void _validateString(String field, String value) {
    final normalized = field.toLowerCase();
    var limit = 10000;
    if (normalized.contains('password')) {
      limit = 128;
    } else if (normalized.contains('email')) {
      limit = 254;
    } else if (normalized.contains('phone')) {
      limit = 32;
    } else if (normalized == 'q' ||
        normalized.contains('query') ||
        normalized.contains('search')) {
      limit = 200;
    } else if (normalized.contains('token') ||
        normalized == 'code' ||
        normalized == 'state') {
      limit = 16384;
    } else if (normalized.contains('sdp')) {
      limit = 131072;
    } else if (normalized.contains('url')) {
      limit = 2048;
    } else if (normalized.contains('name') ||
        normalized.contains('title') ||
        normalized.contains('type') ||
        normalized.contains('status') ||
        normalized.contains('kind') ||
        normalized.contains('category')) {
      limit = 255;
    } else if (normalized.contains('message') ||
        normalized.contains('caption') ||
        normalized.contains('description') ||
        normalized.contains('notes') ||
        normalized.contains('reason') ||
        normalized.contains('details') ||
        normalized.contains('body') ||
        normalized.contains('bio')) {
      limit = 4000;
    }
    if (value.length > limit) {
      throw FormatException('$field must be $limit characters or fewer.');
    }
    if (_controlCharacters.hasMatch(value)) {
      throw FormatException('$field contains unsupported control characters.');
    }
  }

  static final RegExp _controlCharacters = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]',
  );
}

class _ProgressRequest extends http.BaseRequest {
  _ProgressRequest(this.request, this.onProgress)
      : super(request.method, request.url) {
    headers.addAll(request.headers);
    contentLength = request.contentLength;
  }

  final http.MultipartRequest request;
  final void Function(double progress) onProgress;

  @override
  http.ByteStream finalize() {
    super.finalize();
    final total = contentLength ?? 0;
    var sent = 0;
    final stream = request.finalize().transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (chunk, sink) {
          sent += chunk.length;
          onProgress(total == 0 ? 1 : sent / total);
          sink.add(chunk);
        },
      ),
    );
    return http.ByteStream(stream);
  }
}

class ApiResponse {
  ApiResponse({
    required this.statusCode,
    required this.body,
    required this.bodyBytes,
    this.fromCache = false,
    this.cachedAt,
  });

  final int statusCode;
  final String body;
  final Uint8List bodyBytes;
  final bool fromCache;
  final DateTime? cachedAt;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  dynamic decodeJson() {
    if (body.isEmpty) {
      return null;
    }
    return jsonDecode(body);
  }

  static ApiResponse fromHttp(http.Response response) {
    return ApiResponse(
      statusCode: response.statusCode,
      body: response.body,
      bodyBytes: response.bodyBytes,
    );
  }
}
