import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../models/camera.dart';
import '../../providers/garden_providers.dart';

/// Lists the cameras the Pi publishes; tap one to open its live stream.
class CameraPage extends ConsumerWidget {
  const CameraPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameras = ref.watch(camerasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cameras')),
      body: cameras.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No cameras — start the Pi service to see them here.'),
            );
          }
          return ListView(
            children: [
              for (final cam in list)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.videocam, color: Colors.green),
                    title: Text(cam.name),
                    subtitle: Text(cam.id),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CameraStreamPage(camera: cam),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Live WebRTC view for one camera. The phone is the caller: it creates an
/// offer (waiting for ICE gathering so the SDP is complete), writes it to that
/// camera's /webrtc/offer, and applies the Pi's answer. Video then flows
/// peer-to-peer Pi → phone; Firebase is only the signaling channel.
class CameraStreamPage extends ConsumerStatefulWidget {
  const CameraStreamPage({super.key, required this.camera});

  final CameraInfo camera;

  @override
  ConsumerState<CameraStreamPage> createState() => _CameraStreamPageState();
}

class _CameraStreamPageState extends ConsumerState<CameraStreamPage> {
  final _renderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  StreamSubscription<DatabaseEvent>? _answerSub;
  bool _connecting = false;
  String _status = 'Disconnected';

  DatabaseReference get _webrtc =>
      ref.read(gardenServiceProvider).webrtcForCamera(widget.camera.id);

  @override
  void initState() {
    super.initState();
    _renderer.initialize();
  }

  @override
  void dispose() {
    _disconnect();
    _renderer.dispose();
    super.dispose();
  }

  void _setStatus(String s) {
    if (mounted) setState(() => _status = s);
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _status = 'Connecting…';
    });

    final webrtc = _webrtc;
    await webrtc.remove(); // fresh handshake

    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        // Add a TURN server here for strict networks (milestone 9).
      ],
    });
    _pc = pc;

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _renderer.srcObject = event.streams.first;
        _setStatus('Live');
      }
    };
    pc.onConnectionState = (state) {
      _setStatus(state.toString().split('.').last);
    };

    await pc.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );

    _answerSub = webrtc.child('answer').onValue.listen((event) async {
      final value = event.snapshot.value;
      if (value == null || _pc == null) return;
      if (_pc!.signalingState !=
          RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        return;
      }
      final map = Map<String, dynamic>.from(value as Map);
      await _pc!.setRemoteDescription(
        RTCSessionDescription(map['sdp'] as String, map['type'] as String),
      );
    });

    final offer = await pc.createOffer({});
    await pc.setLocalDescription(offer);
    await _waitForIceGathering(pc);

    final local = await pc.getLocalDescription();
    await webrtc.child('offer').set({'sdp': local!.sdp, 'type': local.type});

    setState(() {
      _connecting = false;
      _status = 'Waiting for Pi…';
    });
  }

  Future<void> _waitForIceGathering(RTCPeerConnection pc) async {
    if (pc.iceGatheringState ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }
    final done = Completer<void>();
    pc.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !done.isCompleted) {
        done.complete();
      }
    };
    await done.future.timeout(const Duration(seconds: 5), onTimeout: () {});
  }

  Future<void> _disconnect() async {
    await _answerSub?.cancel();
    _answerSub = null;
    await _pc?.close();
    _pc = null;
    _renderer.srcObject = null;
    try {
      await _webrtc.remove();
    } catch (_) {}
    if (mounted) setState(() => _status = 'Disconnected');
  }

  @override
  Widget build(BuildContext context) {
    final connected = _pc != null;
    return Scaffold(
      appBar: AppBar(title: Text(widget.camera.name)),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              child: _renderer.srcObject != null
                  ? RTCVideoView(_renderer)
                  : Center(
                      child: Text(
                        _status,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text(_status)),
                FilledButton.icon(
                  onPressed: _connecting
                      ? null
                      : (connected ? _disconnect : _connect),
                  icon: Icon(connected ? Icons.stop : Icons.videocam),
                  label: Text(connected ? 'Disconnect' : 'Connect'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
