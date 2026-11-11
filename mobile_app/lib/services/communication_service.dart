import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../core/network/api_client.dart';

enum CallStatus { idle, outgoingRinging, incomingRinging, connected, ended, rejected }

class CommunicationService extends ChangeNotifier {
  final ApiClient _apiClient;

  CommunicationService(this._apiClient);

  // Call states
  CallStatus _callStatus = CallStatus.idle;
  int? _activeBookingId;
  String? _counterpartName;
  String? _counterpartRole;
  int _callDurationSeconds = 0;
  Timer? _durationTimer;
  Timer? _pollTimer;

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

  Future<bool> initiateCall({
    required int bookingId,
    required String callerRole,
    required String callerName,
    required String receiverName,
  }) async {
    _activeBookingId = bookingId;
    _counterpartName = receiverName;
    _counterpartRole = callerRole == 'PASSENGER' ? 'Tài xế / Nhà xe' : 'Hành khách';
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

  Future<void> answerCall({required int bookingId, required String role}) async {
    FlutterRingtonePlayer().stop();
    _callStatus = CallStatus.connected;
    notifyListeners();

    try {
      await _apiClient.post(
        '/communication/call/action',
        data: {
          'booking_id': bookingId,
          'action': 'ACCEPT',
        },
      );
    } catch (_) {}

    await _initWebRTC();
    _startDurationTimer();
  }

  Future<void> rejectCall({required int bookingId}) async {
    FlutterRingtonePlayer().stop();
    _callStatus = CallStatus.rejected;
    notifyListeners();

    try {
      await _apiClient.post(
        '/communication/call/action',
        data: {
          'booking_id': bookingId,
          'action': 'REJECT',
        },
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
      // Cấu hình Google STUN public servers
      final configuration = <String, dynamic>{
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(configuration);

      // Yêu cầu quyền Micro và lấy luồng âm thanh
      final mediaConstraints = <String, dynamic>{
        'audio': true,
        'video': false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }

      // Xử lý luồng âm thanh đối phương gửi về
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          notifyListeners();
        }
      };

      // Xử lý ICE Candidate
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (_activeBookingId != null) {
          _sendSignal(_activeBookingId!, 'candidate', candidate.toMap());
        }
      };
    } catch (e) {
      debugPrint('Error initWebRTC: $e');
    }
  }

  Future<void> _createOffer(int bookingId, String role) async {
    if (_peerConnection == null) return;
    try {
      final description = await _peerConnection!.createOffer({'offerToReceiveAudio': 1});
      await _peerConnection!.setLocalDescription(description);
      await _sendSignal(bookingId, 'offer', description.toMap(), senderRole: role);
    } catch (e) {
      debugPrint('Error createOffer: $e');
    }
  }

  Future<void> _sendSignal(
    int bookingId,
    String type,
    Map<String, dynamic> payload, {
    String? senderRole,
  }) async {
    try {
      await _apiClient.post(
        '/communication/call/signal',
        data: {
          'booking_id': bookingId,
          'signal_type': type,
          'payload': payload,
          'sender_role': senderRole ?? 'CALLER',
        },
      );
    } catch (_) {}
  }

  void _startCallStatusPolling(int bookingId, String role) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_callStatus == CallStatus.ended || _callStatus == CallStatus.rejected || _callStatus == CallStatus.idle) {
        timer.cancel();
        return;
      }

      try {
        final res = await _apiClient.get(
          '/communication/$bookingId/call-status',
          queryParameters: {'role': role},
        );

        if (res.statusCode == 200 && res.data is Map) {
          final data = res.data;
          final status = data['status'];

          if (status == 'CONNECTED' && _callStatus != CallStatus.connected) {
            FlutterRingtonePlayer().stop();
            _callStatus = CallStatus.connected;
            _startDurationTimer();
            notifyListeners();
          } else if (status == 'REJECTED' || status == 'ENDED') {
            timer.cancel();
            FlutterRingtonePlayer().stop();
            _callStatus = (status == 'REJECTED') ? CallStatus.rejected : CallStatus.ended;
            notifyListeners();
            _cleanUpCall();
          }

          // Xử lý signals (answer / candidate)
          final signals = data['signals'] as List?;
          if (signals != null) {
            for (final s in signals) {
              final type = s['signal_type'];
              final payload = s['payload'];
              if (type == 'answer' && _peerConnection != null) {
                final desc = RTCSessionDescription(payload['sdp'], payload['type']);
                await _peerConnection!.setRemoteDescription(desc);
              } else if (type == 'candidate' && _peerConnection != null) {
                final cand = RTCIceCandidate(payload['candidate'], payload['sdpMid'], payload['sdpMLineIndex']);
                await _peerConnection!.addCandidate(cand);
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
    _cleanUpCall();
    super.dispose();
  }
}
