import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../core/network/api_client.dart';

enum CallStatus {
  idle,
  outgoingRinging,
  incomingRinging,
  connected,
  ended,
  rejected,
}

class CommunicationService extends ChangeNotifier {
  final ApiClient _apiClient;

  CommunicationService(this._apiClient);

  // Call states
  CallStatus _callStatus = CallStatus.idle;
  int? _activeBookingId;
  String? _counterpartName;
  String? _counterpartRole;
  String? _myRole;
  String? _myClientId;
  int _callDurationSeconds = 0;
  Timer? _durationTimer;
  Timer? _pollTimer;
  Timer? _incomingCheckTimer;
  final Set<String> _seenSignals = {};
  bool _remoteDescSet = false;

  bool _isMuted = false;
  bool _isSpeakerOn = true;

  // WebRTC
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  CallStatus get callStatus => _callStatus;
  int? get activeBookingId => _activeBookingId;
  String get counterpartName => _counterpartName ?? 'Đối phương';
  String get counterpartRole => _counterpartRole ?? '';
  int get callDurationSeconds => _callDurationSeconds;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;

  String get formattedDuration {
    final minutes = (_callDurationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_callDurationSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // --- 1. CHAT MESSAGING ---

  Future<Map<String, dynamic>?> getChatHistory(int bookingId) async {
    try {
      final res = await _apiClient.get('/communication/$bookingId/messages');
      if (res.statusCode == 200 && res.data is Map) {
        return Map<String, dynamic>.from(res.data);
      }
      return null;
    } catch (e) {
      debugPrint('Error getChatHistory: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> sendMessage({
    required int bookingId,
    required String message,
    required String senderRole,
    required String senderName,
    String messageType = 'TEXT',
  }) async {
    try {
      final res = await _apiClient.post(
        '/communication/$bookingId/send',
        data: {
          'message': message,
          'sender_role': senderRole,
          'sender_name': senderName,
          'message_type': messageType,
        },
      );
      if (res.statusCode == 200 && res.data is Map) {
        return Map<String, dynamic>.from(res.data);
      }
      return null;
    } catch (e) {
      debugPrint('Error sendMessage: $e');
      return null;
    }
  }

  // --- 2. IN-APP VOIP AUDIO CALLING ---

  /// Bắt đầu lắng nghe cuộc gọi đến chạy nền trên toàn ứng dụng
  void startIncomingCallMonitoring({
    required String role,
    int? userId,
    String? phone,
    int? tripId,
  }) {
    _incomingCheckTimer?.cancel();
    _incomingCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      // Chỉ kiểm tra khi không trong cuộc gọi
      if (_callStatus != CallStatus.idle) return;

      try {
        final query = <String, dynamic>{'role': role};
        if (userId != null) query['user_id'] = userId;
        if (phone != null && phone.isNotEmpty) query['phone'] = phone;
        if (tripId != null) query['trip_id'] = tripId;
        if (_activeBookingId != null) query['booking_id'] = _activeBookingId;

        final res = await _apiClient.get(
          '/communication/check-incoming',
          queryParameters: query,
        );

        if (res.statusCode == 200 && res.data is Map) {
          final data = res.data;
          if (data['has_incoming'] == true && data['call'] is Map) {
            final call = Map<String, dynamic>.from(data['call']);
            _onIncomingCallDetected(call);
          }
        }
      } catch (_) {}
    });
  }

  void _onIncomingCallDetected(Map<String, dynamic> call) {
    if (_callStatus != CallStatus.idle) return;

    _seenSignals.clear();
    _remoteDescSet = false;
    _activeBookingId = call['booking_id'];
    _counterpartName = call['caller_name'] ?? 'Đối phương';
    _counterpartRole = call['caller_role'] == 'PASSENGER'
        ? 'Hành khách'
        : 'Tài xế / Nhà xe';
    _myRole = call['caller_role'] == 'PASSENGER' ? 'OPERATOR' : 'PASSENGER';
    _myClientId = '${_myRole}_${DateTime.now().microsecondsSinceEpoch}';
    _callStatus = CallStatus.incomingRinging;
    _callDurationSeconds = 0;
    _isMuted = false;
    _isSpeakerOn = true;
    notifyListeners();

    // Phát chuông gọi đến
    try {
      FlutterRingtonePlayer().play(
        fromAsset: null,
        android: AndroidSounds.ringtone,
        ios: IosSounds.glass,
        looping: true,
        volume: 1.0,
      );
    } catch (_) {}

    // Lắng nghe xem người gọi có dập máy giữa chừng không
    _startCallStatusPolling(_activeBookingId!, _myRole!);
  }

  /// Khởi tạo cuộc gọi đi từ thiết bị hiện tại
  Future<bool> initiateCall({
    required int bookingId,
    required String callerRole,
    required String callerName,
    required String receiverName,
  }) async {
    _seenSignals.clear();
    _remoteDescSet = false;
    _activeBookingId = bookingId;
    _counterpartName = receiverName;
    _counterpartRole = callerRole == 'PASSENGER'
        ? 'Tài xế / Nhà xe'
        : 'Hành khách';
    _myRole = callerRole;
    _myClientId = '${callerRole}_${DateTime.now().microsecondsSinceEpoch}';
    _callStatus = CallStatus.outgoingRinging;
    _callDurationSeconds = 0;
    _isMuted = false;
    _isSpeakerOn = true;
    notifyListeners();

    // 1. Khởi tạo cuộc gọi trên Backend
    try {
      await _apiClient.post(
        '/communication/call/start',
        data: {
          'booking_id': bookingId,
          'caller_role': callerRole,
          'caller_name': callerName,
        },
      );
    } catch (e) {
      debugPrint('Error calling start: $e');
    }

    // 2. Phát âm thanh chuông gọi đi
    try {
      FlutterRingtonePlayer().play(
        fromAsset: null,
        android: AndroidSounds.ringtone,
        ios: IosSounds.glass,
        looping: true,
        volume: 0.8,
      );
    } catch (_) {}

    // 3. Khởi tạo WebRTC Audio
    await _initWebRTC();

    // 4. Tạo SDP Offer
    await _createOffer(bookingId, callerRole);

    // 5. Bắt đầu lắng nghe phản hồi cuộc gọi
    _startCallStatusPolling(bookingId, callerRole);

    return true;
  }

  /// Chấp nhận nghe máy khi có cuộc gọi đến
  Future<void> answerCall({required int bookingId, required String role}) async {
    FlutterRingtonePlayer().stop();
    _callStatus = CallStatus.connected;
    _activeBookingId = bookingId;
    _myRole = role;
    _myClientId ??= '${role}_${DateTime.now().microsecondsSinceEpoch}';
    _seenSignals.clear();
    _remoteDescSet = false;
    notifyListeners();

    try {
      await _apiClient.post(
        '/communication/call/action',
        data: {'booking_id': bookingId, 'action': 'ACCEPT'},
      );
    } catch (_) {}

    await _initWebRTC();
    _startDurationTimer();

    // Lấy SDP Offer từ người gọi và tạo SDP Answer
    try {
      final res = await _apiClient.get(
        '/communication/$bookingId/call-status',
        queryParameters: {'role': role, 'client_id': _myClientId},
      );
      if (res.statusCode == 200 && res.data is Map) {
        final signals = res.data['signals'] as List?;
        if (signals != null) {
          for (final s in signals) {
            if (s['signal_type'] == 'offer' && _peerConnection != null) {
              _seenSignals.add('${s['timestamp']}|offer');
              final payload = s['payload'];
              final desc = RTCSessionDescription(
                payload['sdp'],
                payload['type'],
              );
              await _peerConnection!.setRemoteDescription(desc);
              _remoteDescSet = true;

              final answer = await _peerConnection!.createAnswer({
                'offerToReceiveAudio': 1,
                'offerToReceiveVideo': 0,
              });
              await _peerConnection!.setLocalDescription(answer);

              await _sendSignal(
                bookingId,
                'answer',
                answer.toMap(),
                senderRole: role,
                clientId: _myClientId,
              );
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error answering offer: $e');
    }

    _startCallStatusPolling(bookingId, role);
  }

  Future<void> rejectCall({required int bookingId}) async {
    FlutterRingtonePlayer().stop();
    _callStatus = CallStatus.rejected;
    notifyListeners();

    try {
      await _apiClient.post(
        '/communication/call/action',
        data: {'booking_id': bookingId, 'action': 'REJECT'},
      );
    } catch (_) {}

    _cleanUpCall();
  }

  Future<void> endCall({int? bookingId}) async {
    final bId = bookingId ?? _activeBookingId;
    FlutterRingtonePlayer().stop();

    if (bId != null) {
      try {
        await _apiClient.post(
          '/communication/call/action',
          data: {
            'booking_id': bId,
            'action': 'END',
            'duration_seconds': _callDurationSeconds,
          },
        );
      } catch (_) {}
    }

    _callStatus = CallStatus.ended;
    notifyListeners();
    _cleanUpCall();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    final audioTrack = _localStream?.getAudioTracks().firstOrNull;
    if (audioTrack != null) {
      audioTrack.enabled = !_isMuted;
    }
    notifyListeners();
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    try {
      Helper.setSpeakerphoneOn(_isSpeakerOn);
    } catch (_) {}
    notifyListeners();
  }

  // --- 3. WebRTC INTERNAL HELPERS ---

  Future<void> _initWebRTC() async {
    try {
      final configuration = <String, dynamic>{
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
          {'urls': 'stun:stun2.l.google.com:19302'},
          {'urls': 'stun:stun.cloudflare.com:3478'},
          {'urls': 'stun:global.stun.twilio.com:3478'},
        ],
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(configuration);

      final mediaConstraints = <String, dynamic>{
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );
      for (final track in _localStream!.getTracks()) {
        track.enabled = true;
        await _peerConnection!.addTrack(track, _localStream!);
      }

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'audio') {
          event.track.enabled = true;
        }
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          for (final track in _remoteStream!.getAudioTracks()) {
            track.enabled = true;
          }
          notifyListeners();
        }
      };

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (_activeBookingId != null &&
            candidate.candidate != null &&
            candidate.candidate!.isNotEmpty) {
          _sendSignal(
            _activeBookingId!,
            'candidate',
            candidate.toMap(),
            senderRole: _myRole,
            clientId: _myClientId,
          );
        }
      };

      // Đặt mặc định ra loa ngoài để nghe rõ ràng
      try {
        Helper.setSpeakerphoneOn(_isSpeakerOn);
      } catch (_) {}
    } catch (e) {
      debugPrint('Error initWebRTC: $e');
    }
  }

  Future<void> _createOffer(int bookingId, String role) async {
    if (_peerConnection == null) return;
    try {
      final description = await _peerConnection!.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 0,
      });
      await _peerConnection!.setLocalDescription(description);
      await _sendSignal(
        bookingId,
        'offer',
        description.toMap(),
        senderRole: role,
        clientId: _myClientId,
      );
    } catch (e) {
      debugPrint('Error createOffer: $e');
    }
  }

  Future<void> _sendSignal(
    int bookingId,
    String type,
    Map<String, dynamic> payload, {
    String? senderRole,
    String? clientId,
  }) async {
    try {
      await _apiClient.post(
        '/communication/call/signal',
        data: {
          'booking_id': bookingId,
          'signal_type': type,
          'payload': payload,
          'sender_role': senderRole ?? _myRole ?? 'CALLER',
          'client_id': clientId ?? _myClientId ?? 'client_${DateTime.now().microsecondsSinceEpoch}',
        },
      );
    } catch (_) {}
  }

  void _startCallStatusPolling(int bookingId, String role) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_callStatus == CallStatus.ended ||
          _callStatus == CallStatus.rejected ||
          _callStatus == CallStatus.idle) {
        timer.cancel();
        return;
      }

      try {
        final res = await _apiClient.get(
          '/communication/$bookingId/call-status',
          queryParameters: {
            'role': role,
            if (_myClientId != null) 'client_id': _myClientId,
          },
        );

        if (res.statusCode == 200 && res.data is Map) {
          final data = res.data;
          final status = data['status'];

          if (status == 'CONNECTED' && _callStatus != CallStatus.connected) {
            FlutterRingtonePlayer().stop();
            _callStatus = CallStatus.connected;
            _startDurationTimer();
            // Đảm bảo bật loa ngoài khi kết nối
            try {
              Helper.setSpeakerphoneOn(_isSpeakerOn);
            } catch (_) {}
            notifyListeners();
          } else if (status == 'REJECTED' || status == 'ENDED') {
            timer.cancel();
            FlutterRingtonePlayer().stop();
            _callStatus = (status == 'REJECTED')
                ? CallStatus.rejected
                : CallStatus.ended;
            notifyListeners();
            _cleanUpCall();
            return;
          }

          // Process signals (offer / answer / candidate), skipping already-handled ones
          final signals = data['signals'] as List?;
          if (signals != null) {
            for (final s in signals) {
              final type = s['signal_type'];
              final payload = s['payload'];
              final key = '${s['timestamp']}|$type';
              if (_seenSignals.contains(key)) continue;
              if (_peerConnection == null || payload == null) continue;
              try {
                if (type == 'answer') {
                  _seenSignals.add(key);
                  await _peerConnection!.setRemoteDescription(
                    RTCSessionDescription(payload['sdp'], payload['type']),
                  );
                  _remoteDescSet = true;
                } else if (type == 'offer') {
                  _seenSignals.add(key);
                  await _peerConnection!.setRemoteDescription(
                    RTCSessionDescription(payload['sdp'], payload['type']),
                  );
                  _remoteDescSet = true;
                  final answer = await _peerConnection!.createAnswer({
                    'offerToReceiveAudio': 1,
                    'offerToReceiveVideo': 0,
                  });
                  await _peerConnection!.setLocalDescription(answer);
                  await _sendSignal(
                    bookingId,
                    'answer',
                    answer.toMap(),
                    senderRole: role,
                    clientId: _myClientId,
                  );
                } else if (type == 'candidate') {
                  if (!_remoteDescSet) continue;
                  _seenSignals.add(key);
                  await _peerConnection!.addCandidate(
                    RTCIceCandidate(
                      payload['candidate'],
                      payload['sdpMid'],
                      payload['sdpMLineIndex'],
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Signal $type error: $e');
              }
            }
          }
        }
      } catch (_) {}
    });
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _callDurationSeconds = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDurationSeconds++;
      notifyListeners();
    });
  }

  void _cleanUpCall() {
    _durationTimer?.cancel();
    _pollTimer?.cancel();
    FlutterRingtonePlayer().stop();

    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _localStream = null;

    _remoteStream?.dispose();
    _remoteStream = null;

    _peerConnection?.close();
    _peerConnection?.dispose();
    _peerConnection = null;

    Future.delayed(const Duration(seconds: 2), () {
      _callStatus = CallStatus.idle;
      _activeBookingId = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _incomingCheckTimer?.cancel();
    _cleanUpCall();
    super.dispose();
  }
}
