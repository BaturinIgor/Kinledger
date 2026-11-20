import SwiftUI

/// Mockups of every screen, state and popup (design/<version>/screens).
/// With `-screenshots -design-screen <id>` the app opens that screen straight away on the screenshot data;
/// DesignCatalogUITests takes the pictures. Debug builds only: in release every value here is the
/// app's normal default.
enum DesignFlags {
    static func has(_ flag: String) -> Bool {
        #if DEBUG
        return ScreenshotData.isActive && ProcessInfo.processInfo.arguments.contains(flag)
        #else
        return false
        #endif
    }

    static func value(_ name: String) -> String? {
        #if DEBUG
        guard ScreenshotData.isActive else { return nil }
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
        return args[i + 1]
        #else
        return nil
        #endif
    }

    /// Pro unlocked without a purchase.
    static var pro: Bool { has("-design-pro") }
    /// First onboarding step (1 or 2).
    static var onboardingStep: Int { Int(value("-design-step") ?? "") ?? 1 }
    /// Text already typed in the quick log amount field.
    static var amount: String? { value("-design-amount") }

    static var initialTab: RootView.Tab {
        switch value("-design-tab") {
        case "log": .log
        case "report": .report
        case "me": .me
        default: .today
        }
    }
}

#if DEBUG
extension AppModel {
    /// The screenshot month plus what the mockups need: one entry in the trash, an edited entry,
    /// and the empty, first-launch and storage-problem states.
    static func design() -> AppModel {
        let store = try! EntryStore.inMemory()
        let profile = ScreenshotData.profile()
        if !DesignFlags.has("-design-onboarding") {
            try? store.saveProfile(profile)
            try? store.saveRecipient(Recipient(id: UUID(), name: String(localized: "Dave"), contact: "dave@example.com", relation: "Brother"))
        }
        if !DesignFlags.has("-design-empty") && !DesignFlags.has("-design-onboarding") {
            let entries = ScreenshotData.entries(currency: profile.currencyCode)
            for entry in entries { try? store.save(entry) }
            // The newest entry gets a later edit, so its history shows two versions.
            if var edited = entries.first {
                edited.note = "Picked up the new prescription too."
                try? store.save(edited)
            }
            // One entry in the trash.
            if let trashed = entries.last { try? store.moveToTrash(trashed.id) }
        }
        let problem = DesignFlags.has("-design-problem")
            ? "Kinledger could not open its storage on this iPhone, so new entries are not being kept. Restart the app. (The disk is full.)"
            : nil
        return AppModel(store: store, receipts: try! ReceiptStore.temporary(), problem: problem, cloudConfig: .current)
    }
}

enum DesignScreen: String, Identifiable {
    // Sheets
    case quickLog, quickLogEdit, paywall, restore, deleteAccount
    // Pushed screens
    case entry, taxExport, trash, addRecipient

    var id: String { rawValue }
    var isPush: Bool { [.entry, .taxExport, .trash, .addRecipient].contains(self) }

    static var requested: DesignScreen? { DesignFlags.value("-design-screen").flatMap(DesignScreen.init(rawValue:)) }

    @MainActor @ViewBuilder
    func content(_ model: AppModel) -> some View {
        switch self {
        case .quickLog: QuickLogView()
        case .quickLogEdit: QuickLogView(editing: model.entries.first)
        case .paywall: PaywallView()
        case .restore: RestoreSheet()
        case .deleteAccount: DeleteAccountSheet()
        case .entry:
            if let id = model.entries.first?.id { EntryDetailView(entryID: id) }
        case .taxExport: TaxExportView()
        case .trash: TrashView()
        case .addRecipient: AddRecipientView()
        }
    }
}

/// Opens the requested screen over the app the way the app itself shows it.
struct DesignPresenter: ViewModifier {
    @Environment(AppModel.self) private var model
    @State private var sheet: DesignScreen?
    @State private var push: DesignScreen?

    func body(content: Content) -> some View {
        content
            .overlay {
                if let push {
                    NavigationStack { push.content(model) }
                        .background(Palette.background.ignoresSafeArea())
                        .accessibilityIdentifier("design.ready")
                }
            }
            .sheet(item: $sheet) { screen in
                screen.content(model).accessibilityIdentifier("design.ready")
            }
            .task {
                if DesignFlags.has("-design-dark") {
                    for scene in UIApplication.shared.connectedScenes {
                        (scene as? UIWindowScene)?.windows.forEach { $0.overrideUserInterfaceStyle = .dark }
                    }
                }
                guard let screen = DesignScreen.requested else { return }
                if screen.isPush {
                    push = screen
                } else {
                    try? await Task.sleep(for: .milliseconds(300))
                    sheet = screen
                }
            }
    }
}
#endif

extension View {
    /// Debug builds only: the design catalog opens this screen's popup by itself.
    @ViewBuilder
    func designPresenter() -> some View {
        #if DEBUG
        modifier(DesignPresenter())
        #else
        self
        #endif
    }
}
