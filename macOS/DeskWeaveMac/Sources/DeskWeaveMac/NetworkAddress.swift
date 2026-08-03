import Foundation

enum NetworkAddress {
    static func localIPv4Addresses(port: UInt16) -> [String] {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else {
            return []
        }
        defer { freeifaddrs(pointer) }

        var results: [String] = []
        var current: UnsafeMutablePointer<ifaddrs>? = first

        while let interface = current?.pointee {
            defer { current = interface.ifa_next }

            guard let address = interface.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET),
                  (interface.ifa_flags & UInt32(IFF_UP)) != 0,
                  (interface.ifa_flags & UInt32(IFF_LOOPBACK)) == 0 else {
                continue
            }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let length = socklen_t(address.pointee.sa_len)
            let result = getnameinfo(
                address,
                length,
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            if result == 0 {
                let ip = String(cString: hostname)
                results.append("\(ip):\(port)")
            }
        }

        return Array(Set(results)).sorted()
    }
}
