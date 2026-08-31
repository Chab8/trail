import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Se encarga de conectar la cuenta de Spotify del usuario, guardar sus
/// tokens de forma segura (tabla spotify_connections) y consultar qué
/// está escuchando en este momento.
class SpotifyService {
  SpotifyService._internal();
  static final SpotifyService instance = SpotifyService._internal();

  static const _scopes = 'user-read-currently-playing user-read-playback-state';

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  String? _pendingCodeVerifier;
  String? _pendingState;
  Completer<bool>? _pendingCompleter;

  String get _clientId => dotenv.env['SPOTIFY_CLIENT_ID'] ?? '';
  String get _redirectUri =>
      dotenv.env['SPOTIFY_REDIRECT_URI'] ?? 'trail://spotify-auth-callback';

  SupabaseClient get _client => Supabase.instance.client;

  /// Hay que llamarlo UNA sola vez, apenas arranca la app (en main.dart).
  void init() {
    _linkSubscription ??= _appLinks.uriLinkStream.listen(
      _handleIncomingLink,
      onError: (_) {},
    );
  }

  /// Abre el navegador para que el usuario apruebe la conexión.
  /// Devuelve true si quedó conectado, false si falló o se canceló.
  Future<bool> connect() async {
    if (_clientId.isEmpty) {
      throw Exception('Falta configurar SPOTIFY_CLIENT_ID en el archivo .env');
    }

    final verifier = _generateRandomString(64);
    final challenge = _codeChallengeFromVerifier(verifier);
    final state = _generateRandomString(16);

    _pendingCodeVerifier = verifier;
    _pendingState = state;
    _pendingCompleter = Completer<bool>();

    final authUri = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': _clientId,
      'response_type': 'code',
      'redirect_uri': _redirectUri,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      'scope': _scopes,
      'state': state,
    });

    final opened = await launchUrl(authUri, mode: LaunchMode.externalApplication);
    if (!opened) {
      _pendingCompleter = null;
      return false;
    }

    return _pendingCompleter!.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () => false,
    );
  }

  Future<void> _handleIncomingLink(Uri uri) async {
    final expectedScheme = Uri.parse(_redirectUri).scheme;
    if (uri.scheme != expectedScheme) return;
    if (_pendingCompleter == null || _pendingCompleter!.isCompleted) return;

    final returnedState = uri.queryParameters['state'];
    final code = uri.queryParameters['code'];
    final error = uri.queryParameters['error'];

    if (error != null || code == null || returnedState != _pendingState) {
      _pendingCompleter!.complete(false);
      return;
    }

    try {
      await _exchangeCodeForTokens(code);
      _pendingCompleter!.complete(true);
    } catch (_) {
      _pendingCompleter!.complete(false);
    } finally {
      _pendingCodeVerifier = null;
      _pendingState = null;
    }
  }

  Future<void> _exchangeCodeForTokens(String code) async {
    final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': _redirectUri,
        'client_id': _clientId,
        'code_verifier': _pendingCodeVerifier ?? '',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Spotify token exchange failed: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    await _saveTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
      expiresIn: data['expires_in'] as int,
    );
  }

  Future<void> _saveTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    String? spotifyId;
    try {
      final me = await http.get(
        Uri.parse('https://api.spotify.com/v1/me'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (me.statusCode == 200) {
        spotifyId = (jsonDecode(me.body) as Map<String, dynamic>)['id'] as String?;
      }
    } catch (_) {
      // No es grave si esto falla, igual guardamos los tokens.
    }

    final expiresAt = DateTime.now().toUtc().add(Duration(seconds: expiresIn));

    await _client.from('spotify_connections').upsert({
      'user_id': userId,
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_expires_at': expiresAt.toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    if (spotifyId != null) {
      await _client.from('profiles').update({'spotify_id': spotifyId}).eq('id', userId);
    }
  }

  /// Desconecta la cuenta de Spotify.
  Future<void> disconnect() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('spotify_connections').delete().eq('user_id', userId);
    await _client.from('profiles').update({'spotify_id': null}).eq('id', userId);
  }

  /// True si el usuario actual tiene Spotify conectado.
  Future<bool> isConnected() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final row = await _client
        .from('spotify_connections')
        .select('user_id')
        .eq('user_id', userId)
        .maybeSingle();
    return row != null;
  }

  Future<String?> _getValidAccessToken() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _client
        .from('spotify_connections')
        .select('access_token, refresh_token, token_expires_at')
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return null;

    final expiresAt = DateTime.parse(row['token_expires_at'] as String);
    final stillValid =
        expiresAt.isAfter(DateTime.now().toUtc().add(const Duration(seconds: 30)));

    if (stillValid) {
      return row['access_token'] as String;
    }

    return _refreshAccessToken(row['refresh_token'] as String, userId);
  }

  Future<String?> _refreshAccessToken(String refreshToken, String userId) async {
    final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': _clientId,
      },
    );

    if (response.statusCode != 200) {
      // Puede que el usuario haya revocado el acceso desde Spotify.
      await disconnect();
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final newAccessToken = data['access_token'] as String;
    final newRefreshToken = data['refresh_token'] as String? ?? refreshToken;
    final expiresIn = data['expires_in'] as int;
    final expiresAt = DateTime.now().toUtc().add(Duration(seconds: expiresIn));

    await _client.from('spotify_connections').update({
      'access_token': newAccessToken,
      'refresh_token': newRefreshToken,
      'token_expires_at': expiresAt.toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', userId);

    return newAccessToken;
  }

  /// Qué se está escuchando ahora mismo. Null si no hay Spotify conectado
  /// o si no se está reproduciendo nada.
  Future<SpotifyNowPlaying?> getCurrentlyPlaying() async {
    final token = await _getValidAccessToken();
    if (token == null) return null;

    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/me/player/currently-playing'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 204 || response.body.isEmpty) return null;
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final isPlaying = data['is_playing'] as bool? ?? false;
    final item = data['item'] as Map<String, dynamic>?;
    if (!isPlaying || item == null) return null;

    final artists = (item['artists'] as List<dynamic>? ?? [])
        .map((a) => a['name'] as String)
        .join(', ');
    final images = (item['album']?['images'] as List<dynamic>?) ?? [];
    final albumArt = images.isNotEmpty ? images.first['url'] as String? : null;

    return SpotifyNowPlaying(
      trackName: item['name'] as String? ?? '',
      artistName: artists,
      albumArtUrl: albumArt,
    );
  }

  String _generateRandomString(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String _codeChallengeFromVerifier(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
}

class SpotifyNowPlaying {
  final String trackName;
  final String artistName;
  final String? albumArtUrl;

  SpotifyNowPlaying({
    required this.trackName,
    required this.artistName,
    this.albumArtUrl,
  });
}