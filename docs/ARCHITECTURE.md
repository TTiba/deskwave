# Architecture

DeskWeave is composed of two native applications connected by a small binary
protocol over one TCP connection.

## macOS sender

1. `VirtualDisplayBridge` dynamically resolves the private CoreGraphics
   virtual display classes and creates a 1792 × 1120 display.
2. `CaptureService` finds that display through ScreenCaptureKit and requests
   NV12 frames at up to 60 fps.
3. `H264Encoder` sends the pixel buffers to a real-time VideoToolbox hardware
   encoder configured for H.264 Main Profile Level 4.2 at approximately
   12 Mbit/s.
4. `FrameBroadcaster` listens on TCP port 5900 and sends codec configuration
   followed by Annex B H.264 access units.

The private API is isolated in an Objective-C bridge so the rest of the app
uses a small C interface and fails gracefully when the symbols are unavailable.

## Android receiver

1. `MainActivity.Receiver` connects to the address entered by the user.
2. It validates packet magic, sizes and codec configuration.
3. `H264Decoder` selects a MediaCodec AVC decoder supporting the requested
   size and frame rate.
4. Annex B access units are queued into MediaCodec and rendered to a
   `SurfaceView`.

## SSV2 framing

Each packet starts with a 20-byte big-endian header:

| Field | Size | Description |
|---|---:|---|
| Magic | 4 | `SSV2` / `0x53535632` |
| Type | 1 | `1` configuration, `2` video frame |
| Flags | 1 | Bit 0 identifies a keyframe |
| Reserved | 2 | Zero |
| Payload length | 4 | Bytes following the header |
| Presentation time | 8 | Microseconds |

The configuration payload contains width, height, expected FPS, SPS length,
PPS length, SPS bytes and PPS bytes. Frame payloads contain one Annex B H.264
access unit.

## Latency and backpressure

Each client has at most one pending frame. If the network cannot keep up, the
sender clears the pending inter-frame chain, waits for the next IDR, and resumes
from a decodable point. This bounds latency instead of allowing an old video
queue to grow indefinitely.

## Trust boundary

SSV2 currently provides framing, not security. There is no pairing,
authentication, integrity protection, or encryption. The listener must remain
on a trusted local network until a secure transport is implemented.

