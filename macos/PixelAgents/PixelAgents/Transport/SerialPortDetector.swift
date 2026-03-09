import Foundation
import IOKit
import IOKit.serial

/// Represents a detected USB serial port.
struct SerialPortInfo: Identifiable, Hashable {
    let id: String     // device path, e.g. /dev/cu.usbmodem1234
    let name: String   // display name

    var path: String { id }
}

/// Detects USB serial ports using IOKit notifications.
/// Publishes available ports and notifies on changes.
final class SerialPortDetector: ObservableObject {
    @Published private(set) var availablePorts: [SerialPortInfo] = []

    private var notifyPort: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0

    /// Known USB serial path prefixes (matching Python bridge patterns).
    private static let knownPrefixes = [
        "/dev/cu.usbmodem",
        "/dev/cu.usbserial",
        "/dev/cu.wchusbserial",
    ]

    init() {
        refresh()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Port enumeration

    /// Enumerate all matching serial ports right now.
    func refresh() {
        var ports: [SerialPortInfo] = []

        let matchingDict = IOServiceMatching(kIOSerialBSDServiceValue) as NSMutableDictionary
        matchingDict[kIOSerialBSDTypeKey] = kIOSerialBSDAllTypes

        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
        guard kr == KERN_SUCCESS else {
            availablePorts = ports
            return
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            guard let pathCF = IORegistryEntryCreateCFProperty(
                service,
                kIOCalloutDeviceKey as CFString,
                kCFAllocatorDefault, 0
            )?.takeRetainedValue() as? String else { continue }

            // Filter to known USB serial prefixes
            guard Self.knownPrefixes.contains(where: { pathCF.hasPrefix($0) }) else { continue }

            let name = pathCF.components(separatedBy: "/").last ?? pathCF
            ports.append(SerialPortInfo(id: pathCF, name: name))
        }

        DispatchQueue.main.async {
            self.availablePorts = ports
        }
    }

    // MARK: - IOKit notifications

    /// Start monitoring for USB serial device add/remove events.
    func startMonitoring() {
        guard notifyPort == nil else { return }
        notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notifyPort = notifyPort else { return }

        let runLoopSource = IONotificationPortGetRunLoopSource(notifyPort).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)

        let matchingAdd = IOServiceMatching(kIOSerialBSDServiceValue) as NSDictionary
        let matchingRemove = IOServiceMatching(kIOSerialBSDServiceValue) as NSDictionary

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        IOServiceAddMatchingNotification(
            notifyPort,
            kIOFirstMatchNotification,
            matchingAdd,
            { (refCon, iterator) in
                // Drain the iterator (required by IOKit)
                var entry = IOIteratorNext(iterator)
                while entry != 0 {
                    IOObjectRelease(entry)
                    entry = IOIteratorNext(iterator)
                }
                guard let refCon = refCon else { return }
                let detector = Unmanaged<SerialPortDetector>.fromOpaque(refCon).takeUnretainedValue()
                detector.refresh()
            },
            selfPtr,
            &addedIterator
        )
        // Drain initial iterator
        drainIterator(addedIterator)

        IOServiceAddMatchingNotification(
            notifyPort,
            kIOTerminatedNotification,
            matchingRemove,
            { (refCon, iterator) in
                var entry = IOIteratorNext(iterator)
                while entry != 0 {
                    IOObjectRelease(entry)
                    entry = IOIteratorNext(iterator)
                }
                guard let refCon = refCon else { return }
                let detector = Unmanaged<SerialPortDetector>.fromOpaque(refCon).takeUnretainedValue()
                detector.refresh()
            },
            selfPtr,
            &removedIterator
        )
        drainIterator(removedIterator)
    }

    /// Stop IOKit notifications.
    func stopMonitoring() {
        if addedIterator != 0 {
            IOObjectRelease(addedIterator)
            addedIterator = 0
        }
        if removedIterator != 0 {
            IOObjectRelease(removedIterator)
            removedIterator = 0
        }
        if let port = notifyPort {
            IONotificationPortDestroy(port)
            notifyPort = nil
        }
    }

    private func drainIterator(_ iterator: io_iterator_t) {
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
    }
}
