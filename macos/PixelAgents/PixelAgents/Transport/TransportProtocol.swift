import Foundation

/// Common interface for serial and BLE transports.
protocol TransportProtocol: AnyObject {
    var isConnected: Bool { get }
    func send(_ data: Data) -> Bool
    func disconnect()
}
