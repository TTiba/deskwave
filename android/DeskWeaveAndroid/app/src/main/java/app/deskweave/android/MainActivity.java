package app.deskweave.android;

import android.app.Activity;
import android.content.Context;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaFormat;
import android.os.Build;
import android.os.Bundle;
import android.os.SystemClock;
import android.text.InputType;
import android.view.Gravity;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.io.BufferedInputStream;
import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.EOFException;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.ByteBuffer;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicBoolean;

public final class MainActivity extends Activity {
    private static final int DEFAULT_PORT = 5900;
    private static final int STREAM_MAGIC = 0x53535632; // "SSV2"
    private static final int PACKET_CONFIGURATION = 1;
    private static final int PACKET_FRAME = 2;
    private static final int FLAG_KEY_FRAME = 1;
    private static final int MAX_PAYLOAD_BYTES = 16 * 1024 * 1024;

    private SurfaceView surfaceView;
    private LinearLayout controlPanel;
    private EditText addressInput;
    private Button connectButton;
    private TextView statusText;
    private volatile Surface renderSurface;
    private Receiver receiver;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        buildInterface();
        enterImmersiveMode();
    }

    private void buildInterface() {
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);

        surfaceView = new SurfaceView(this);
        // Keep the app window transparent over the SurfaceView. A background
        // drawable here can cover the decoder's separate surface on some
        // Android devices, leaving the physical display black even though
        // MediaCodec is producing frames.
        surfaceView.setZOrderOnTop(false);
        surfaceView.getHolder().setFormat(PixelFormat.OPAQUE);
        surfaceView.setClickable(true);
        surfaceView.getHolder().addCallback(new SurfaceHolder.Callback() {
            @Override
            public void surfaceCreated(SurfaceHolder holder) {
                renderSurface = holder.getSurface();
                if (connectButton != null) {
                    connectButton.setEnabled(true);
                }
            }

            @Override
            public void surfaceChanged(
                    SurfaceHolder holder,
                    int format,
                    int width,
                    int height
            ) {
                renderSurface = holder.getSurface();
            }

            @Override
            public void surfaceDestroyed(SurfaceHolder holder) {
                renderSurface = null;
                if (receiver != null) {
                    stopReceiver("The video surface was closed.");
                }
            }
        });
        root.addView(surfaceView, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
        ));

        controlPanel = new LinearLayout(this);
        controlPanel.setOrientation(LinearLayout.HORIZONTAL);
        controlPanel.setGravity(Gravity.CENTER_VERTICAL);
        controlPanel.setPadding(dp(18), dp(12), dp(18), dp(12));
        controlPanel.setBackgroundColor(Color.rgb(23, 25, 29));

        addressInput = new EditText(this);
        addressInput.setSingleLine(true);
        addressInput.setHint(getString(R.string.address_hint));
        addressInput.setTextColor(Color.WHITE);
        addressInput.setHintTextColor(Color.rgb(150, 153, 162));
        addressInput.setInputType(InputType.TYPE_CLASS_TEXT);
        LinearLayout.LayoutParams inputParams = new LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1
        );
        controlPanel.addView(addressInput, inputParams);

        connectButton = new Button(this);
        connectButton.setText(R.string.connect);
        connectButton.setEnabled(false);
        connectButton.setOnClickListener(view -> toggleConnection());
        controlPanel.addView(connectButton);

        statusText = new TextView(this);
        statusText.setText(R.string.waiting);
        statusText.setTextColor(Color.rgb(210, 212, 218));
        statusText.setPadding(dp(14), 0, 0, 0);
        controlPanel.addView(statusText);

        FrameLayout.LayoutParams panelParams = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.TOP
        );
        root.addView(controlPanel, panelParams);

        surfaceView.setOnClickListener(view -> {
            controlPanel.setVisibility(
                    controlPanel.getVisibility() == View.VISIBLE
                            ? View.GONE
                            : View.VISIBLE
            );
            enterImmersiveMode();
        });

        setContentView(root);
    }

    private void toggleConnection() {
        if (receiver != null) {
            stopReceiver("Disconnected.");
            return;
        }

        Surface surface = renderSurface;
        if (surface == null || !surface.isValid()) {
            statusText.setText("The video surface is not ready yet.");
            return;
        }

        Endpoint endpoint;
        try {
            endpoint = Endpoint.parse(addressInput.getText().toString());
        } catch (IllegalArgumentException error) {
            statusText.setText(error.getMessage());
            return;
        }

        hideKeyboard();
        addressInput.setEnabled(false);
        connectButton.setText(R.string.disconnect);
        statusText.setText("Connecting…");

        receiver = new Receiver(endpoint, surface);
        receiver.start();
    }

    private void stopReceiver(String message) {
        Receiver current = receiver;
        receiver = null;
        if (current != null) {
            current.close();
        }
        addressInput.setEnabled(true);
        connectButton.setText(R.string.connect);
        statusText.setText(message);
    }

    private void onConnected(Receiver source) {
        if (receiver != source) {
            return;
        }
        statusText.setText("Connected — waiting for H.264…");
    }

    private void onVideoConfigured(
            Receiver source,
            VideoConfiguration configuration,
            String decoderName
    ) {
        if (receiver != source) {
            return;
        }
        statusText.setText(
                configuration.width + "×" + configuration.height
                        + " • " + configuration.framesPerSecond + " fps"
                        + " • " + decoderName
        );
        controlPanel.postDelayed(() -> {
            if (receiver == source) {
                controlPanel.setVisibility(View.GONE);
                enterImmersiveMode();
            }
        }, 1500);
    }

    private void onStatistics(Receiver source, String statistics) {
        if (receiver == source && controlPanel.getVisibility() == View.VISIBLE) {
            statusText.setText(statistics);
        }
    }

    private void onConnectionEnded(Receiver source, String message) {
        if (receiver != source || isFinishing() || isDestroyed()) {
            return;
        }
        stopReceiver(message);
        controlPanel.setVisibility(View.VISIBLE);
    }

    @SuppressWarnings("deprecation")
    private void enterImmersiveMode() {
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        | View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        );
    }

    private void hideKeyboard() {
        InputMethodManager manager =
                (InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE);
        manager.hideSoftInputFromWindow(addressInput.getWindowToken(), 0);
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            enterImmersiveMode();
        }
    }

    @Override
    protected void onDestroy() {
        if (receiver != null) {
            receiver.close();
            receiver = null;
        }
        super.onDestroy();
    }

    private final class Receiver extends Thread {
        private final Endpoint endpoint;
        private final Surface surface;
        private final AtomicBoolean running = new AtomicBoolean(true);
        private Socket socket;

        Receiver(Endpoint endpoint, Surface surface) {
            super("DeskWeaveH264Receiver");
            this.endpoint = endpoint;
            this.surface = surface;
        }

        @Override
        public void run() {
            H264Decoder decoder = new H264Decoder(surface);
            try (Socket activeSocket = new Socket()) {
                socket = activeSocket;
                activeSocket.setTcpNoDelay(true);
                activeSocket.setReceiveBufferSize(4 * 1024 * 1024);
                activeSocket.connect(
                        new InetSocketAddress(endpoint.host, endpoint.port),
                        5000
                );

                runOnUiThread(() -> onConnected(this));

                try (DataInputStream input = new DataInputStream(
                        new BufferedInputStream(activeSocket.getInputStream(), 4 * 1024 * 1024)
                )) {
                    long reportStartedAt = SystemClock.elapsedRealtime();
                    int receivedFrames = 0;
                    int renderedFrames = 0;
                    int droppedFrames = 0;
                    long bytes = 0;

                    while (running.get()) {
                        int magic = input.readInt();
                        if (magic != STREAM_MAGIC) {
                            throw new IOException(
                                    "Incompatible protocol. Update both applications."
                            );
                        }

                        int packetType = input.readUnsignedByte();
                        int flags = input.readUnsignedByte();
                        input.readUnsignedShort(); // Reserved.
                        int payloadLength = input.readInt();
                        long presentationTimeMicroseconds = input.readLong();

                        if (payloadLength <= 0 || payloadLength > MAX_PAYLOAD_BYTES) {
                            throw new IOException(
                                    "Invalid packet size: " + payloadLength
                            );
                        }

                        byte[] payload = new byte[payloadLength];
                        input.readFully(payload);
                        bytes += 20L + payloadLength;

                        if (packetType == PACKET_CONFIGURATION) {
                            VideoConfiguration configuration =
                                    VideoConfiguration.parse(payload);
                            String decoderName = decoder.configure(configuration);
                            runOnUiThread(() -> onVideoConfigured(
                                    this,
                                    configuration,
                                    decoderName
                            ));
                            continue;
                        }

                        if (packetType != PACKET_FRAME || !decoder.isConfigured()) {
                            continue;
                        }

                        boolean keyFrame = (flags & FLAG_KEY_FRAME) != 0;
                        receivedFrames++;
                        H264Decoder.DecodeResult result = decoder.queueFrame(
                                payload,
                                presentationTimeMicroseconds,
                                keyFrame
                        );
                        renderedFrames += result.renderedFrames;
                        if (!result.accepted) {
                            droppedFrames++;
                        }

                        long now = SystemClock.elapsedRealtime();
                        long elapsed = now - reportStartedAt;
                        if (elapsed >= 1000) {
                            double seconds = elapsed / 1000.0;
                            int receivedFps = (int) Math.round(receivedFrames / seconds);
                            int displayFps = (int) Math.round(renderedFrames / seconds);
                            double megabits = bytes * 8.0 / seconds / 1_000_000.0;
                            String statistics = String.format(
                                    Locale.US,
                                    "%d received • %d displayed • %.1f Mbit/s • %d dropped",
                                    receivedFps,
                                    displayFps,
                                    megabits,
                                    droppedFrames
                            );
                            runOnUiThread(() -> onStatistics(this, statistics));
                            receivedFrames = 0;
                            renderedFrames = 0;
                            droppedFrames = 0;
                            bytes = 0;
                            reportStartedAt = now;
                        }
                    }
                }
            } catch (EOFException error) {
                if (running.get()) {
                    runOnUiThread(() -> onConnectionEnded(
                            this,
                            "The Mac ended the stream."
                    ));
                }
            } catch (IOException | RuntimeException error) {
                if (running.get()) {
                    String message = "Failed: " + error.getLocalizedMessage();
                    runOnUiThread(() -> onConnectionEnded(this, message));
                }
            } finally {
                decoder.release();
                socket = null;
            }
        }

        void close() {
            running.set(false);
            Socket current = socket;
            if (current != null) {
                try {
                    current.close();
                } catch (IOException ignored) {
                    // Socket is already closing.
                }
            }
        }
    }

    private static final class H264Decoder {
        private static final String MIME_TYPE = MediaFormat.MIMETYPE_VIDEO_AVC;

        private final Surface surface;
        private final MediaCodec.BufferInfo bufferInfo = new MediaCodec.BufferInfo();
        private MediaCodec codec;
        private boolean awaitingKeyFrame = true;

        H264Decoder(Surface surface) {
            this.surface = surface;
        }

        boolean isConfigured() {
            return codec != null;
        }

        String configure(VideoConfiguration configuration) throws IOException {
            release();

            MediaFormat format = MediaFormat.createVideoFormat(
                    MIME_TYPE,
                    configuration.width,
                    configuration.height
            );
            format.setByteBuffer(
                    "csd-0",
                    withAnnexBStartCode(configuration.sequenceParameterSet)
            );
            format.setByteBuffer(
                    "csd-1",
                    withAnnexBStartCode(configuration.pictureParameterSet)
            );
            format.setInteger(
                    MediaFormat.KEY_FRAME_RATE,
                    configuration.framesPerSecond
            );
            format.setInteger(
                    MediaFormat.KEY_MAX_INPUT_SIZE,
                    MAX_PAYLOAD_BYTES
            );

            MediaCodecInfo decoderInfo = findCompatibleDecoder(configuration);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                format.setInteger(MediaFormat.KEY_PRIORITY, 0);
                format.setFloat(
                        MediaFormat.KEY_OPERATING_RATE,
                        configuration.framesPerSecond
                );
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                format.setInteger(MediaFormat.KEY_LOW_LATENCY, 1);
            }

            MediaCodec created = MediaCodec.createByCodecName(decoderInfo.getName());
            try {
                created.configure(format, surface, null, 0);
                created.start();
            } catch (RuntimeException error) {
                created.release();
                throw error;
            }
            codec = created;
            awaitingKeyFrame = true;
            return created.getName();
        }

        private static MediaCodecInfo findCompatibleDecoder(
                VideoConfiguration configuration
        ) throws IOException {
            android.media.MediaCodecList codecList = new android.media.MediaCodecList(
                    android.media.MediaCodecList.REGULAR_CODECS
            );
            for (MediaCodecInfo info : codecList.getCodecInfos()) {
                if (info.isEncoder()) {
                    continue;
                }
                for (String type : info.getSupportedTypes()) {
                    if (!MIME_TYPE.equalsIgnoreCase(type)) {
                        continue;
                    }
                    try {
                        MediaCodecInfo.VideoCapabilities videoCapabilities =
                                info.getCapabilitiesForType(type).getVideoCapabilities();
                        if (videoCapabilities != null
                                && videoCapabilities.areSizeAndRateSupported(
                                        configuration.width,
                                        configuration.height,
                                        configuration.framesPerSecond
                                )) {
                            return info;
                        }
                    } catch (IllegalArgumentException ignored) {
                        // Try the next AVC decoder advertised by the device.
                    }
                }
            }
            throw new IOException(
                    "This tablet has no H.264 decoder for "
                            + configuration.width + "×" + configuration.height
                            + " at " + configuration.framesPerSecond + " fps."
            );
        }

        DecodeResult queueFrame(
                byte[] frame,
                long presentationTimeMicroseconds,
                boolean keyFrame
        ) throws IOException {
            MediaCodec activeCodec = codec;
            if (activeCodec == null) {
                return new DecodeResult(false, 0);
            }

            int rendered = drainOutput(activeCodec, 0);
            if (awaitingKeyFrame && !keyFrame) {
                return new DecodeResult(false, rendered);
            }

            int inputIndex = activeCodec.dequeueInputBuffer(8_000);
            if (inputIndex < 0) {
                awaitingKeyFrame = true;
                return new DecodeResult(false, rendered);
            }

            ByteBuffer inputBuffer = activeCodec.getInputBuffer(inputIndex);
            if (inputBuffer == null || inputBuffer.capacity() < frame.length) {
                awaitingKeyFrame = true;
                return new DecodeResult(false, rendered);
            }

            inputBuffer.clear();
            inputBuffer.put(frame);
            activeCodec.queueInputBuffer(
                    inputIndex,
                    0,
                    frame.length,
                    presentationTimeMicroseconds,
                    0
            );
            if (keyFrame) {
                awaitingKeyFrame = false;
            }

            // Wait briefly for the first decoded output. ScreenCaptureKit may
            // send only one frame while the desktop is static; without this
            // wait that frame can remain queued until the screen changes.
            rendered += drainOutput(activeCodec, 8_000);
            return new DecodeResult(true, rendered);
        }

        private int drainOutput(MediaCodec activeCodec, long firstTimeoutUs) {
            int rendered = 0;
            boolean firstAttempt = true;
            while (true) {
                int outputIndex = activeCodec.dequeueOutputBuffer(
                        bufferInfo,
                        firstAttempt ? firstTimeoutUs : 0
                );
                firstAttempt = false;
                if (outputIndex >= 0) {
                    activeCodec.releaseOutputBuffer(outputIndex, true);
                    rendered++;
                } else if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    // The Surface handles the new output format automatically.
                } else {
                    break;
                }
            }
            return rendered;
        }

        void release() {
            MediaCodec current = codec;
            codec = null;
            awaitingKeyFrame = true;
            if (current != null) {
                try {
                    current.stop();
                } catch (RuntimeException ignored) {
                    // The codec may already have stopped after a surface loss.
                }
                current.release();
            }
        }

        private static ByteBuffer withAnnexBStartCode(byte[] parameterSet) {
            byte[] data = new byte[4 + parameterSet.length];
            data[3] = 1;
            System.arraycopy(parameterSet, 0, data, 4, parameterSet.length);
            return ByteBuffer.wrap(data);
        }

        static final class DecodeResult {
            final boolean accepted;
            final int renderedFrames;

            DecodeResult(boolean accepted, int renderedFrames) {
                this.accepted = accepted;
                this.renderedFrames = renderedFrames;
            }
        }
    }

    private static final class VideoConfiguration {
        final int width;
        final int height;
        final int framesPerSecond;
        final byte[] sequenceParameterSet;
        final byte[] pictureParameterSet;

        VideoConfiguration(
                int width,
                int height,
                int framesPerSecond,
                byte[] sequenceParameterSet,
                byte[] pictureParameterSet
        ) {
            this.width = width;
            this.height = height;
            this.framesPerSecond = framesPerSecond;
            this.sequenceParameterSet = sequenceParameterSet;
            this.pictureParameterSet = pictureParameterSet;
        }

        static VideoConfiguration parse(byte[] payload) throws IOException {
            try (DataInputStream input = new DataInputStream(
                    new ByteArrayInputStream(payload)
            )) {
                int width = input.readUnsignedShort();
                int height = input.readUnsignedShort();
                int framesPerSecond = input.readUnsignedShort();
                int sequenceLength = input.readUnsignedShort();
                int pictureLength = input.readUnsignedShort();

                if (width == 0
                        || height == 0
                        || framesPerSecond == 0
                        || sequenceLength == 0
                        || pictureLength == 0
                        || sequenceLength + pictureLength != input.available()) {
                    throw new IOException("Invalid H.264 configuration.");
                }

                byte[] sequenceParameterSet = new byte[sequenceLength];
                byte[] pictureParameterSet = new byte[pictureLength];
                input.readFully(sequenceParameterSet);
                input.readFully(pictureParameterSet);

                return new VideoConfiguration(
                        width,
                        height,
                        framesPerSecond,
                        sequenceParameterSet,
                        pictureParameterSet
                );
            }
        }
    }

    private static final class Endpoint {
        final String host;
        final int port;

        Endpoint(String host, int port) {
            this.host = host;
            this.port = port;
        }

        static Endpoint parse(String value) {
            String trimmed = value == null ? "" : value.trim();
            if (trimmed.isEmpty()) {
                throw new IllegalArgumentException("Enter the address shown on the Mac.");
            }

            String host = trimmed;
            int port = DEFAULT_PORT;
            int separator = trimmed.lastIndexOf(':');
            if (separator > 0) {
                host = trimmed.substring(0, separator).trim();
                try {
                    port = Integer.parseInt(trimmed.substring(separator + 1).trim());
                } catch (NumberFormatException error) {
                    throw new IllegalArgumentException("The port must be a number.");
                }
            }

            if (host.isEmpty() || port < 1 || port > 65535) {
                throw new IllegalArgumentException("Invalid address.");
            }
            return new Endpoint(host, port);
        }
    }
}
