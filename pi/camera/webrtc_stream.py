"""Live camera streaming over WebRTC (Pi = callee), one signaling loop per camera.

Each camera in config.CAMERAS gets its own node:
    /gardens/{id}/cameras/{camId}/meta            -> {name}
    /gardens/{id}/cameras/{camId}/webrtc/offer    <- phone posts SDP offer
    /gardens/{id}/cameras/{camId}/webrtc/answer   -> Pi posts SDP answer

The phone posts an offer; the Pi attaches that camera's video track, answers, and
streams peer-to-peer (Pi -> phone). Firebase is only the signaling channel. One
MediaRelay per camera lets several viewers share a single capture device.

On a real Pi each camera is a USB device (/dev/video<source>); in mock mode each
streams a distinct labelled colour pattern so multi-camera works without hardware.
"""
import asyncio

import config
import firebase_client as fb

try:
    import av
    import numpy as np
    from aiortc import RTCPeerConnection, RTCSessionDescription, VideoStreamTrack
    from aiortc.contrib.media import MediaPlayer, MediaRelay

    _AIORTC = True
except ImportError:  # aiortc/av/numpy not installed
    _AIORTC = False
    VideoStreamTrack = object

VIDEO_CLOCK_RATE = 90000

# A different base colour per camera so mock streams are visually distinct.
_MOCK_COLOURS = [(0, 80, 0), (0, 0, 100), (100, 40, 0), (60, 0, 80)]


class TestPatternTrack(VideoStreamTrack):
    """A moving gradient tinted per-camera — proves the pipeline without hardware."""

    def __init__(self, index: int = 0, width: int = 480, height: int = 320):
        super().__init__()
        self._w, self._h = width, height
        self._tint = np.array(
            _MOCK_COLOURS[index % len(_MOCK_COLOURS)], dtype=np.uint16
        )
        ys, xs = np.meshgrid(
            np.linspace(0, 255, height, dtype=np.uint16),
            np.linspace(0, 255, width, dtype=np.uint16),
            indexing="ij",
        )
        self._xs, self._ys = xs, ys

    async def recv(self):
        pts, time_base = await self.next_timestamp()
        shift = int((pts / VIDEO_CLOCK_RATE) * 50) % 256
        r = ((self._xs + shift + self._tint[0]) % 256).astype(np.uint8)
        g = ((self._ys + shift + self._tint[1]) % 256).astype(np.uint8)
        b = np.full((self._h, self._w), (shift + self._tint[2]) % 256, dtype=np.uint8)
        frame = av.VideoFrame.from_ndarray(np.dstack([r, g, b]), format="rgb24")
        frame.pts = pts
        frame.time_base = time_base
        return frame


# camId -> (relay, source_track). Built lazily, shared across viewers.
_sources = {}


def _source_for(cam: dict, index: int):
    """A MediaRelay-wrapped track for this camera (opened once, shared)."""
    cam_id = cam["id"]
    if cam_id in _sources:
        return _sources[cam_id]

    if config.MOCK_HARDWARE:
        track = TestPatternTrack(index)
    else:
        # USB webcam via V4L2 on Linux (the Raspberry Pi). MediaPlayer keeps the
        # device open; MediaRelay fans it out to multiple peers.
        player = MediaPlayer(
            f"/dev/video{cam['source']}",
            format="v4l2",
            options={"video_size": "640x480", "framerate": "15"},
        )
        track = player.video

    relay = MediaRelay()
    _sources[cam_id] = (relay, track)
    return _sources[cam_id]


async def _answer(cam: dict, index: int, offer: dict):
    relay, source = _source_for(cam, index)
    pc = RTCPeerConnection()
    pc.addTrack(relay.subscribe(source))

    @pc.on("connectionstatechange")
    async def _on_state():
        print(f"[webrtc:{cam['id']}] connection: {pc.connectionState}")
        if pc.connectionState in ("failed", "closed", "disconnected"):
            await pc.close()

    await pc.setRemoteDescription(
        RTCSessionDescription(sdp=offer["sdp"], type=offer["type"])
    )
    answer = await pc.createAnswer()
    await pc.setLocalDescription(answer)  # gathers ICE before returning
    fb.set_value(
        f"cameras/{cam['id']}/webrtc/answer",
        {"sdp": pc.localDescription.sdp, "type": pc.localDescription.type},
    )
    print(f"[webrtc:{cam['id']}] answer sent — streaming")
    return pc


async def _camera_loop(cam: dict, index: int, stop_event):
    """Watch one camera's /webrtc/offer and answer each new offer."""
    offer_path = f"cameras/{cam['id']}/webrtc/offer"
    answer_path = f"cameras/{cam['id']}/webrtc/answer"
    fb.set_value(f"cameras/{cam['id']}/meta", {"name": cam["name"]})
    fb.set_value(answer_path, None)  # clear stale handshake
    last_offer = None
    peers = []

    while stop_event is None or not stop_event.is_set():
        try:
            offer = fb.get_value(offer_path)
            if offer and offer != last_offer:
                last_offer = offer
                fb.set_value(answer_path, None)
                peers.append(await _answer(cam, index, offer))
        except Exception as exc:
            print(f"[webrtc:{cam['id']}] {exc}")
        await asyncio.sleep(1.0)

    for pc in peers:
        await pc.close()


async def serve(stop_event=None):
    """Run a signaling loop for every configured camera, concurrently."""
    if not _AIORTC:
        print("[webrtc] aiortc not installed — cameras disabled (see requirements.txt)")
        return
    cameras = config.CAMERAS
    print(f"[webrtc] signaling ready for {len(cameras)} camera(s): "
          f"{', '.join(c['id'] for c in cameras)}")
    await asyncio.gather(
        *(_camera_loop(cam, i, stop_event) for i, cam in enumerate(cameras))
    )


def run(stop_event=None):
    """Entry point for a background thread (own asyncio loop)."""
    asyncio.run(serve(stop_event))
