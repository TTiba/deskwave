import XCTest
import VirtualDisplayBridge

final class VirtualDisplayBridgeTests: XCTestCase {
    func testVirtualDisplayCanBeCreatedAndReleased() throws {
        XCTAssertTrue(
            SSVVirtualDisplayAPIAvailable(),
            "The private CGVirtualDisplay classes are unavailable."
        )

        guard let display = SSVCreateVirtualDisplay(1280, 800, 60) else {
            XCTFail("macOS refused to create the virtual display.")
            return
        }
        defer { SSVReleaseVirtualDisplay(display) }

        XCTAssertNotEqual(
            SSVVirtualDisplayID(display),
            0,
            "The virtual display was created without a valid display ID."
        )
    }
}
