import AppKit
import WebKit
import os

/// Manages authentication to cursor.com/dashboard via a WKWebView window.
/// After the user completes the WorkOS OAuth login, session cookies are stored
/// in a persistent WKWebsiteDataStore and can be extracted for API calls.
@MainActor
final class CursorDashboardAuth: NSObject, WKNavigationDelegate, WKUIDelegate {

    private static let log = Logger(subsystem: "com.pixelagents", category: "CursorDashboardAuth")
    private static let dashboardURL = URL(string: "https://cursor.com/dashboard")!

    /// Shared persistent data store — cookies survive across app launches.
    static let dataStore: WKWebsiteDataStore = .default()

    /// Whether we have (potentially valid) session cookies for cursor.com.
    private(set) var hasSession: Bool = false

    private var authWindow: NSWindow?
    private var webView: WKWebView?
    private var urlLabel: NSTextField?
    private var completion: ((Bool) -> Void)?

    // MARK: - Public API

    private static let hasAuthKey = "cursorDashboardHasAuth"

    /// Check if user has previously authenticated to cursor.com.
    /// Uses a UserDefaults flag since WKWebsiteDataStore cookie queries
    /// may not work on cold start before a WKWebView is instantiated.
    func checkExistingSession() -> Bool {
        let hadPreviousAuth = UserDefaults.standard.bool(forKey: Self.hasAuthKey)
        if hadPreviousAuth {
            hasSession = true
            Self.log.info("Previous cursor.com auth found — will attempt API call")
        }
        return hadPreviousAuth
    }

    /// Mark that authentication succeeded (persists across launches).
    func markAuthenticated() {
        hasSession = true
        UserDefaults.standard.set(true, forKey: Self.hasAuthKey)
        // Copy WK cookies to HTTPCookieStorage so they're available on cold start
        // (WKWebsiteDataStore queries don't work before a WKWebView is instantiated)
        Self.dataStore.httpCookieStore.getAllCookies { cookies in
            for cookie in cookies where cookie.domain == "cursor.com" || cookie.domain.hasSuffix(".cursor.com") {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
        }
    }

    /// Mark that authentication is needed (e.g., session expired).
    func markNeedsAuth() {
        hasSession = false
        UserDefaults.standard.set(false, forKey: Self.hasAuthKey)
    }

    /// Open the auth window for the user to sign in to cursor.com.
    /// The window shows a real URL bar so the user can verify the domain.
    /// Completion is called with `true` if cookies were captured, `false` if cancelled.
    func authenticate(completion: @escaping (Bool) -> Void) {
        if authWindow != nil {
            // Window already open — bring to front, don't overwrite the original completion
            authWindow?.makeKeyAndOrderFront(nil)
            return
        }

        self.completion = completion

        // URL bar
        let urlBar = NSTextField(labelWithString: "https://cursor.com/dashboard")
        urlBar.font = .systemFont(ofSize: 12, weight: .regular)
        urlBar.textColor = .secondaryLabelColor
        urlBar.backgroundColor = NSColor.textBackgroundColor
        urlBar.isBezeled = true
        urlBar.bezelStyle = .roundedBezel
        urlBar.isEditable = false
        urlBar.isSelectable = true
        urlBar.alignment = .left
        urlBar.translatesAutoresizingMaskIntoConstraints = false
        self.urlLabel = urlBar

        // Lock icon
        let lockIcon = NSImageView(image: NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Secure")!)
        lockIcon.contentTintColor = .systemGreen
        lockIcon.translatesAutoresizingMaskIntoConstraints = false
        lockIcon.setContentHuggingPriority(.required, for: .horizontal)

        // URL bar container
        let urlContainer = NSStackView(views: [lockIcon, urlBar])
        urlContainer.orientation = .horizontal
        urlContainer.spacing = 6
        urlContainer.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        urlContainer.translatesAutoresizingMaskIntoConstraints = false

        // WKWebView with persistent data store
        let config = WKWebViewConfiguration()
        config.websiteDataStore = Self.dataStore
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.uiDelegate = self
        wv.translatesAutoresizingMaskIntoConstraints = false
        self.webView = wv

        // Container
        let container = NSView()
        container.addSubview(urlContainer)
        container.addSubview(wv)

        NSLayoutConstraint.activate([
            urlContainer.topAnchor.constraint(equalTo: container.topAnchor),
            urlContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            urlContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            wv.topAnchor.constraint(equalTo: urlContainer.bottomAnchor),
            wv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 600),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered,
                              defer: false)
        window.title = "Sign in to Cursor"
        window.contentView = container
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.authWindow = window

        // Load the dashboard (WorkOS will redirect to login if needed)
        wv.load(URLRequest(url: Self.dashboardURL))
    }

    /// Extract cursor.com session cookies for use in URLSession requests.
    func getCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { cont in
            Self.dataStore.httpCookieStore.getAllCookies { cookies in
                let cursorCookies = cookies.filter { $0.domain == "cursor.com" || $0.domain.hasSuffix(".cursor.com") }
                cont.resume(returning: cursorCookies)
            }
        }
    }

    /// Clear stored session (for re-auth).
    func clearSession() {
        hasSession = false
        // Clear WKWebsiteDataStore cookies
        Self.dataStore.httpCookieStore.getAllCookies { cookies in
            for cookie in cookies where cookie.domain == "cursor.com" || cookie.domain.hasSuffix(".cursor.com") {
                Self.dataStore.httpCookieStore.delete(cookie)
            }
        }
        // Clear HTTPCookieStorage cookies (used as fallback by analytics API)
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies where cookie.domain == "cursor.com" || cookie.domain.hasSuffix(".cursor.com") {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }

    // MARK: - WKNavigationDelegate

    nonisolated func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        Task { @MainActor in
            guard let url = webView.url else { return }
            updateURLBar(url)
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            guard let url = webView.url else { return }
            updateURLBar(url)

            // Check if we landed on the dashboard (login successful)
            if url.host == "cursor.com" && url.path.hasPrefix("/dashboard") {
                Self.log.info("Cursor dashboard loaded — session cookies captured")
                markAuthenticated()
                // Auto-close after a short delay so the user sees success
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.closeWindow(success: true)
                }
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView,
                             decidePolicyFor navigationAction: WKNavigationAction,
                             decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Allow cursor.com, workos.com, and related auth domains (exact or subdomain match)
        let scheme = navigationAction.request.url?.scheme ?? ""
        // Allow about:blank / about:srcdoc (used by Cloudflare Turnstile sandboxed iframes)
        if scheme == "about" {
            decisionHandler(.allow)
            return
        }
        let host = navigationAction.request.url?.host ?? ""
        let allowedDomains = ["cursor.com", "workos.com", "cursor.sh",
                              "google.com", "github.com", "googleapis.com",
                              "cloudflare.com", "cloudflareinsights.com"]
        let allowed = allowedDomains.contains { host == $0 || host.hasSuffix(".\($0)") }
        if !allowed {
            let log = Logger(subsystem: "com.pixelagents", category: "CursorDashboardAuth")
            log.warning("Blocked navigation to: \(navigationAction.request.url?.absoluteString ?? "nil", privacy: .public)")
        }
        decisionHandler(allowed ? .allow : .cancel)
    }

    // MARK: - WKUIDelegate

    /// Handle window.open() / target="_blank" (e.g., CAPTCHA human verification).
    /// Load the request in the existing webview instead of silently dropping it.
    nonisolated func webView(_ webView: WKWebView,
                             createWebViewWith configuration: WKWebViewConfiguration,
                             for navigationAction: WKNavigationAction,
                             windowFeatures: WKWindowFeatures) -> WKWebView? {
        // If the target frame is nil, it's a new-window request — load in-place
        if navigationAction.targetFrame == nil || navigationAction.targetFrame?.isMainFrame == false {
            webView.load(navigationAction.request)
        }
        return nil
    }

    // MARK: - Private

    private func updateURLBar(_ url: URL) {
        // Show scheme + host + path only (strip query params that may contain tokens)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        let display = components?.string ?? url.absoluteString
        urlLabel?.stringValue = display
        // Green lock for HTTPS
        if let lockParent = urlLabel?.superview as? NSStackView,
           let lockIcon = lockParent.arrangedSubviews.first as? NSImageView {
            lockIcon.contentTintColor = url.scheme == "https" ? .systemGreen : .systemRed
        }
    }

    private func closeWindow(success: Bool) {
        guard let window = authWindow else { return }  // already closed
        authWindow = nil
        webView = nil
        let cb = completion
        completion = nil
        window.close()
        cb?(success)
    }
}

// MARK: - NSWindowDelegate

extension CursorDashboardAuth: NSWindowDelegate {
    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            guard completion != nil else { return }  // already handled by closeWindow
            let success = hasSession
            authWindow = nil
            webView = nil
            let cb = completion
            completion = nil
            cb?(success)
        }
    }
}
