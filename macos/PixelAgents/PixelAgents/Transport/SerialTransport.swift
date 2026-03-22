import Foundation

/// Serial port transport using POSIX file descriptors.
/// Opens /dev/cu.* at 115200 baud, 8N1, no flow control.
final class SerialTransport: TransportProtocol {
    private var fd: Int32 = -1
    private let fdLock = NSLock()
    private var readSource: DispatchSourceRead?
    private let queue = DispatchQueue(label: "com.pixelagents.serial", qos: .userInitiated)

    /// Buffer for incoming data (screenshot responses).
    private var readBuffer = Data()
    private let readBufferLock = NSLock()

    var isConnected: Bool {
        fdLock.lock()
        let connected = fd >= 0
        fdLock.unlock()
        return connected
    }

    /// Open a serial port at 115200 baud.
    func connect(port: String) -> Bool {
        guard fd < 0 else { return true } // already connected

        let fileDescriptor = open(port, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fileDescriptor >= 0 else {
            return false
        }

        // Configure termios for 115200/8N1
        var options = termios()
        tcgetattr(fileDescriptor, &options)

        cfsetispeed(&options, speed_t(B115200))
        cfsetospeed(&options, speed_t(B115200))

        // Raw mode: no echo, no signals, no canonical processing
        options.c_lflag &= ~tcflag_t(ICANON | ECHO | ECHOE | ISIG)
        options.c_iflag &= ~tcflag_t(IXON | IXOFF | IXANY | ICRNL | INLCR)
        options.c_oflag &= ~tcflag_t(OPOST)

        // 8 data bits, no parity, 1 stop bit
        options.c_cflag &= ~tcflag_t(PARENB | CSTOPB | CSIZE)
        options.c_cflag |= tcflag_t(CS8 | CLOCAL | CREAD)

        // Minimum bytes to read, no timeout (VMIN=16, VTIME=17 on Darwin)
        withUnsafeMutablePointer(to: &options.c_cc) { ptr in
            let cc = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: cc_t.self)
            cc[Int(VMIN)] = 0
            cc[Int(VTIME)] = 0
        }

        tcsetattr(fileDescriptor, TCSANOW, &options)

        // Clear O_NONBLOCK after configuration
        let currentFlags = fcntl(fileDescriptor, F_GETFL)
        _ = fcntl(fileDescriptor, F_SETFL, currentFlags & ~O_NONBLOCK)

        fdLock.lock()
        self.fd = fileDescriptor
        fdLock.unlock()

        // Set up async read source for incoming data
        setupReadSource()

        return true
    }

    func send(_ data: Data) -> Bool {
        fdLock.lock()
        let currentFd = fd
        fdLock.unlock()
        guard currentFd >= 0 else { return false }

        let result = data.withUnsafeBytes { buffer -> Int in
            guard let ptr = buffer.baseAddress else { return -1 }
            var totalWritten = 0
            while totalWritten < buffer.count {
                let n = write(currentFd, ptr + totalWritten, buffer.count - totalWritten)
                if n < 0 { return -1 }
                totalWritten += n
            }
            return totalWritten
        }

        if result < 0 {
            disconnect()
            return false
        }
        return true
    }

    func disconnect() {
        readSource?.cancel()
        readSource = nil
        fdLock.lock()
        if fd >= 0 {
            close(fd)
            fd = -1
        }
        fdLock.unlock()
        readBufferLock.lock()
        readBuffer.removeAll()
        readBufferLock.unlock()
    }

    /// Read available data (for screenshot responses). Returns and clears the read buffer.
    func drainReadBuffer() -> Data {
        readBufferLock.lock()
        let data = readBuffer
        readBuffer.removeAll()
        readBufferLock.unlock()
        return data
    }

    /// Read exactly `count` bytes with a deadline. Returns nil on timeout.
    func readExact(count: Int, deadline: Date) -> Data? {
        var accumulated = Data()

        while accumulated.count < count {
            if Date() > deadline { return nil }

            // Try drain buffer first
            let buffered = drainReadBuffer()
            if !buffered.isEmpty {
                accumulated.append(buffered)
                continue
            }

            // Poll with short timeout
            Thread.sleep(forTimeInterval: 0.01)
        }

        // If we got more than needed, put excess back
        if accumulated.count > count {
            let excess = accumulated.suffix(from: count)
            readBufferLock.lock()
            readBuffer.insert(contentsOf: excess, at: 0)
            readBufferLock.unlock()
            accumulated = accumulated.prefix(count)
        }

        return Data(accumulated)
    }

    // MARK: - Private

    private func setupReadSource() {
        guard fd >= 0 else { return }

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.handleRead()
        }
        source.setCancelHandler { /* nothing */ }
        source.resume()
        self.readSource = source
    }

    private func handleRead() {
        fdLock.lock()
        let currentFd = fd
        fdLock.unlock()
        guard currentFd >= 0 else { return }

        var buf = [UInt8](repeating: 0, count: 256)
        let bytesRead = read(currentFd, &buf, buf.count)

        if bytesRead > 0 {
            let data = Data(buf[0..<bytesRead])
            readBufferLock.lock()
            readBuffer.append(data)
            readBufferLock.unlock()
        }
    }
}
