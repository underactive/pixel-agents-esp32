import SwiftUI

/// Displays the pre-rendered office scene frame at 320x224.
/// The actual rendering is done by OfficeRenderer via BridgeService's scene timer.
struct OfficeCanvasView: View {
    @EnvironmentObject var bridge: BridgeService

    var body: some View {
        if let frame = bridge.officeFrame {
            Image(decorative: frame, scale: 1.0)
                .interpolation(.none)
        } else {
            Color.black
                .frame(width: 320, height: 224)
        }
    }
}
