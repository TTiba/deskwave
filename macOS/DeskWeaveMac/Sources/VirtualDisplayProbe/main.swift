import Darwin
import CoreGraphics
import Foundation
import VirtualDisplayBridge

guard SSVVirtualDisplayAPIAvailable() else {
    fputs("ERROR: CGVirtualDisplay is not available on this macOS version.\n", stderr)
    exit(2)
}

guard let display = SSVCreateVirtualDisplay(1280, 800, 60) else {
    fputs("ERROR: macOS refused to create the virtual display.\n", stderr)
    exit(3)
}

let displayID = SSVVirtualDisplayID(display)
guard displayID != 0 else {
    SSVReleaseVirtualDisplay(display)
    fputs("ERRO: a tela virtual foi criada sem display ID.\n", stderr)
    exit(4)
}

if let mode = CGDisplayCopyDisplayMode(displayID) {
    print(
        "OK: tela virtual \(mode.width)x\(mode.height) pontos, "
            + "\(mode.pixelWidth)x\(mode.pixelHeight) pixels, ID \(displayID)."
    )
} else {
    print("OK: tela virtual criada com display ID \(displayID).")
}
SSVReleaseVirtualDisplay(display)
print("OK: tela virtual removida.")
