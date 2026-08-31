import Foundation
import Network

struct H264StreamConfiguration: Equatable {
    let width: UInt16
    let height: UInt16
    let framesPerSecond: UInt16
    let sequenceParameterSet: Data
    let pictureParameterSet: Data
}

final class FrameBroadcaster {
    typealias StatusHandler = (String) -> Void

    private enum PacketKind {
        case configuration
        case frame
    }

    private struct PendingPacket {
        let kind: PacketKind
        let data: Data
    }

    private final class Client {
        let id = UUID()
        let connection: NWConnection
        var sending = false
        var configured = false
        var waitingForKeyFrame = true
        var pendingConfiguration: Data?
        var pendingFrame: Data?

        init(connection: NWConnection) {
            self.connection = connection
        }
    }

    private let queue = DispatchQueue(label: "second-screen.network")
    private var listener: NWListener?
    private var clients: [UUID: Client] = [:]
    private var latestConfigurationPacket: Data?
    private let statusHandler: StatusHandler

    init(statusHandler: @escaping StatusHandler) {
        self.statusHandler = statusHandler
    }

    func start(port: UInt16) throws {
        guard listener == nil else { return }
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw StreamError.invalidPort
        }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters, on: endpointPort)
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.report("H.264 server ready on port \(port)")
            case .failed(let error):
                self?.report("Server failed: \(error.localizedDescription)")
            case .cancelled:
                self?.report("Server stopped")
            default:
                break
            }
        }
        self.listener = listener
        listener.start(queue: queue)
    }

    func stop() {
        queue.async {
            self.listener?.cancel()
            self.listener = nil
            self.clients.values.forEach { $0.connection.cancel() }
            self.clients.removeAll()
            self.latestConfigurationPacket = nil
        }
    }

    func publish(configuration: H264StreamConfiguration) {
        let packet = StreamProtocol.configurationPacket(configuration)
        queue.async {
            self.latestConfigurationPacket = packet
            for client in self.clients.values {
                client.configured = false
                client.waitingForKeyFrame = true
                client.pendingFrame = nil
                client.pendingConfiguration = packet
                self.pump(client)
            }
        }
    }

    func publish(
        frame: Data,
        presentationTimeMicroseconds: UInt64,
        isKeyFrame: Bool
    ) {
        guard frame.count <= Int(UInt32.max) else { return }
        let packet = StreamProtocol.framePacket(
            frame,
            presentationTimeMicroseconds: presentationTimeMicroseconds,
            isKeyFrame: isKeyFrame
        )

        queue.async {
            for client in self.clients.values {
                if client.pendingFrame != nil {
                    // Dropping an inter frame would break the H.264 reference
                    // chain. Discard the backlog and resume only at the next
                    // IDR frame, keeping latency bounded without corruption.
                    client.pendingFrame = nil
                    client.waitingForKeyFrame = true
                }
                if client.waitingForKeyFrame {
                    guard isKeyFrame else { continue }
                    client.waitingForKeyFrame = false
                }

                // Keep only the newest unsent frame. This is the main
                // low-latency behavior when the network cannot sustain 60 fps.
                client.pendingFrame = packet
                self.pump(client)
            }
        }
    }

    private func accept(_ connection: NWConnection) {
        let client = Client(connection: connection)
        clients[client.id] = client

        connection.stateUpdateHandler = { [weak self, weak client] state in
            guard let self, let client else { return }
            self.queue.async {
                switch state {
                case .ready:
                    client.pendingConfiguration = self.latestConfigurationPacket
                    self.pump(client)
                    self.report("Tablet connected over H.264")
                case .failed(let error):
                    self.remove(client, reason: error.localizedDescription)
                case .cancelled:
                    self.remove(client, reason: nil)
                default:
                    break
                }
            }
        }
        connection.start(queue: queue)
    }

    private func pump(_ client: Client) {
        guard !client.sending else { return }

        let pending: PendingPacket
        if let configuration = client.pendingConfiguration {
            client.pendingConfiguration = nil
            pending = PendingPacket(kind: .configuration, data: configuration)
        } else if client.configured, let frame = client.pendingFrame {
            client.pendingFrame = nil
            pending = PendingPacket(kind: .frame, data: frame)
        } else {
            return
        }

        client.sending = true
        client.connection.send(
            content: pending.data,
            completion: .contentProcessed { [weak self, weak client] error in
                guard let self, let client else { return }
                self.queue.async {
                    client.sending = false
                    if let error {
                        self.remove(client, reason: error.localizedDescription)
                        return
                    }
                    if pending.kind == .configuration {
                        client.configured = true
                    }
                    self.pump(client)
                }
            }
        )
    }

    private func remove(_ client: Client, reason: String?) {
        guard clients.removeValue(forKey: client.id) != nil else { return }
        client.connection.cancel()
        if let reason {
            report("Tablet disconnected: \(reason)")
        } else {
            report("Tablet disconnected")
        }
    }

    private func report(_ message: String) {
        DispatchQueue.main.async {
            self.statusHandler(message)
        }
    }

    enum StreamError: LocalizedError {
        case invalidPort

        var errorDescription: String? {
            "Invalid TCP port."
        }
    }
}

private enum StreamProtocol {
    private static let magic: UInt32 = 0x44573331 // "DW31"
    private static let configurationType: UInt8 = 1
    private static let frameType: UInt8 = 2
    private static let keyFrameFlag: UInt8 = 1

    static func configurationPacket(_ configuration: H264StreamConfiguration) -> Data {
        var payload = Data()
        payload.appendBigEndian(configuration.width)
        payload.appendBigEndian(configuration.height)
        payload.appendBigEndian(configuration.framesPerSecond)
        payload.appendBigEndian(UInt16(configuration.sequenceParameterSet.count))
        payload.appendBigEndian(UInt16(configuration.pictureParameterSet.count))
        payload.append(configuration.sequenceParameterSet)
        payload.append(configuration.pictureParameterSet)

        return packet(
            type: configurationType,
            flags: 0,
            presentationTimeMicroseconds: 0,
            payload: payload
        )
    }

    static func framePacket(
        _ frame: Data,
        presentationTimeMicroseconds: UInt64,
        isKeyFrame: Bool
    ) -> Data {
        packet(
            type: frameType,
            flags: isKeyFrame ? keyFrameFlag : 0,
            presentationTimeMicroseconds: presentationTimeMicroseconds,
            payload: frame
        )
    }

    private static func packet(
        type: UInt8,
        flags: UInt8,
        presentationTimeMicroseconds: UInt64,
        payload: Data
    ) -> Data {
        var packet = Data(capacity: 20 + payload.count)
        packet.appendBigEndian(magic)
        packet.append(type)
        packet.append(flags)
        packet.appendBigEndian(UInt16(0))
        packet.appendBigEndian(UInt32(payload.count))
        packet.appendBigEndian(presentationTimeMicroseconds)
        packet.append(payload)
        return packet
    }
}

private extension Data {
    mutating func appendBigEndian<T: FixedWidthInteger>(_ value: T) {
        var bigEndian = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndian) {
            append(contentsOf: $0)
        }
    }
}
