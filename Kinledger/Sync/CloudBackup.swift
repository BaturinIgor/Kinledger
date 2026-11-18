import CryptoKit
import Foundation
import Observation

/// What the backup indicator shows.
enum BackupStatus: Equatable, Sendable {
    /// This build has no cloud project set (CloudConfig is empty).
    case notConfigured
    case signedOut
    case syncing
    case upToDate(Date)
    /// Changes saved on the phone that are not in the cloud yet, for example while offline.
    case waiting(Int)
    case failed(String)
    /// The session ended; signing in again resumes backup with nothing lost.
    case needsSignIn

    /// One calm line for Today and Me. The phone copy is always safe, so nothing here sounds alarming.
    func text(now: Date = .now) -> String {
        switch self {
        case .notConfigured: "Saved on this iPhone. Cloud backup is not set up in this build."
        case .signedOut: "Saved on this iPhone only. Turn on cloud backup in Me."
        case .syncing: "Backing up…"
        case .upToDate(let date):
            if now.timeIntervalSince(date) < 60 {
                "Backed up just now"
            } else {
                "Backed up \(date.formatted(.relative(presentation: .named, unitsStyle: .wide)))"
            }
        case .waiting(0): "Backup starts in a moment"
        case .waiting(let count):
            count == 1
                ? "1 change saved on this iPhone, waiting to back up"
                : "\(count) changes saved on this iPhone, waiting to back up"
        case .failed: "Saved on this iPhone. Backup will try again shortly."
        case .needsSignIn: "Saved on this iPhone. Sign in again in Me to keep backing up."
        }
    }

    var symbol: String {
        switch self {
        case .notConfigured, .signedOut: "iphone"
        case .syncing: "arrow.triangle.2.circlepath.icloud"
        case .upToDate: "checkmark.icloud"
        case .waiting, .failed, .needsSignIn: "icloud.slash"
        }
    }
}

/// Runs cloud backup for the app: sign-in, a sync shortly after each change, and the status line.
@MainActor
@Observable
final class CloudBackup {
    static let lastBackupKey = "backup.lastAt"

    private(set) var status: BackupStatus
    private(set) var lastSummary: SyncSummary?
    /// Called after each sync, so screens show anything that came down (entries, receipts, the profile).
    @ObservationIgnored var onDownloaded: (@MainActor () -> Void)?

    private let store: EntryStore
    private let receipts: ReceiptStore
    private let client: CloudClient?
    private let keychain: KeychainSessionStore
    private var session: CloudSession?
    private var scheduled: Task<Void, Never>?
    private var isRunning = false
    private var runAgain = false

    var isConfigured: Bool { client != nil }
    var isSignedIn: Bool { session != nil }

    init(
        store: EntryStore,
        receipts: ReceiptStore,
        config: CloudConfig?,
        transport: any HTTPTransport = URLSessionTransport(),
        keychain: KeychainSessionStore = KeychainSessionStore()
    ) {
        self.store = store
        self.receipts = receipts
        self.keychain = keychain
        client = config.map { CloudClient(config: $0, transport: transport) }
        session = config == nil ? nil : keychain.load()
        status = .notConfigured
        refreshStatus()
    }

    // MARK: Sign in

    /// A fresh random nonce. Apple gets its SHA-256, Supabase gets the raw value.
    static func makeNonce() -> String {
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<32).map { _ in alphabet.randomElement(using: &generator)! })
    }

    static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func signIn(appleIdentityToken: String, nonce: String) async {
        guard let client else { return }
        status = .syncing
        do {
            let session = try await client.signInWithApple(idToken: appleIdentityToken, nonce: nonce)
            self.session = session
            keychain.save(session)
            await syncNow()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// Stops backup on this phone. Entries stay on the phone and in the cloud.
    func signOut() {
        scheduled?.cancel()
        session = nil
        keychain.clear()
        try? store.resetSyncState()
        status = isConfigured ? .signedOut : .notConfigured
    }

    /// Backs up first, so the link shows everything logged so far, then creates the link.
    func shareReportLink(month: Date, includeNotes: Bool) async -> Result<URL, ReportLinkFailure> {
        guard let client, isSignedIn else { return .failure(ReportLinkFailure("Turn on backup in Me to share a link.")) }
        await syncNow()
        guard let session else { return .failure(ReportLinkFailure("Sign in again in Me to share a link.")) }
        let link = ReportLink(month: month, includeNotes: includeNotes)
        do {
            try await client.createReportLink(link, session: session)
            return .success(link.url)
        } catch {
            return .failure(ReportLinkFailure("The link could not be made: \(error.localizedDescription)"))
        }
    }

    func revokeReportLinks() async -> String? {
        guard let client, let session else { return "Backup is not on, so there are no links." }
        do {
            try await client.revokeAllReportLinks(session: session)
            return nil
        } catch {
            return "Links were not turned off: \(error.localizedDescription)"
        }
    }

    /// Deletes the cloud copy and the account. Entries on this iPhone stay.
    /// Returns an error message to show, or nil when it worked.
    func deleteAccount(appleAuthorizationCode: String) async -> String? {
        guard let client, var session else { return "Backup is not on, so there is no cloud account to delete." }
        scheduled?.cancel()
        do {
            if session.isExpired() {
                session = try await client.refresh(session)
            }
            try await client.deleteAccount(authorizationCode: appleAuthorizationCode, session: session)
            signOut()
            return nil
        } catch {
            return "The cloud account was not deleted: \(error.localizedDescription)"
        }
    }

    // MARK: Syncing

    /// Backs up a couple of seconds after the last change, so a burst of edits goes up together.
    func syncSoon(delay: Duration = .seconds(2)) {
        refreshStatus()
        guard isSignedIn else { return }
        scheduled?.cancel()
        scheduled = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    func syncNow() async {
        guard let client, var session else {
            refreshStatus()
            return
        }
        if isRunning {
            runAgain = true
            return
        }
        isRunning = true
        defer { isRunning = false }
        status = .syncing

        do {
            if session.isExpired() {
                session = try await client.refresh(session)
                self.session = session
                keychain.save(session)
            }
            let engine = SyncEngine(store: store, receipts: receipts, client: client)
            let summary = try await engine.run(session: session)
            lastSummary = summary
            try? store.setSyncValue(CloudCodec.format(.now), for: Self.lastBackupKey)
            onDownloaded?()
            refreshStatus()
        } catch let error as CloudError where error.needsSignIn {
            self.session = nil
            keychain.clear()
            status = .needsSignIn
        } catch {
            let waiting = (try? store.pendingCount()) ?? 0
            status = waiting > 0 ? .waiting(waiting) : .failed(error.localizedDescription)
            scheduleRetry()
        }

        if runAgain {
            runAgain = false
            syncSoon(delay: .milliseconds(300))
        }
    }

    private func scheduleRetry() {
        scheduled?.cancel()
        scheduled = Task { [weak self] in
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    func refreshStatus() {
        guard isConfigured else { status = .notConfigured; return }
        guard isSignedIn else {
            if status != .needsSignIn { status = .signedOut }
            return
        }
        if isRunning { return }
        let waiting = (try? store.pendingCount()) ?? 0
        if waiting > 0 {
            status = .waiting(waiting)
        } else if let text = try? store.syncValue(Self.lastBackupKey), let date = CloudCodec.parse(text) {
            status = .upToDate(date)
        } else {
            status = .waiting(0)
        }
    }
}

struct ReportLinkFailure: Error, Equatable {
    let message: String
    init(_ message: String) { self.message = message }
}
