import AuthenticationServices
import SwiftUI

/// The backup row on Me: where the data is, and the switch to put a copy in the cloud.
struct CloudBackupSection: View {
    @Environment(AppModel.self) private var model

    @State private var isDeleting = false

    private var cloud: CloudBackup { model.cloud }

    var body: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(cloud.status.text())
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }
            } icon: {
                Image(systemName: cloud.status.symbol).foregroundStyle(Palette.time)
            }

            switch cloud.status {
            case .notConfigured:
                EmptyView()
            case .signedOut, .needsSignIn:
                AppleBackupButton()
            default:
                Button {
                    Task { await cloud.syncNow() }
                } label: {
                    Label("Back up now", systemImage: "arrow.clockwise")
                }
                .disabled(cloud.status == .syncing)
                Button("Turn off backup on this iPhone") { cloud.signOut() }
                    .foregroundStyle(Palette.textSecondary)
                Button("Turn off all report links") {
                    Task {
                        if let failure = await cloud.revokeReportLinks() { model.problem = failure }
                    }
                }
                Button("Delete cloud account", role: .destructive) { isDeleting = true }
            }
        } header: {
            Text("Backup")
        } footer: {
            Text(footer)
        }
        .sheet(isPresented: $isDeleting) { DeleteAccountSheet() }
    }

    private var title: String {
        cloud.isSignedIn ? "On this iPhone and in the cloud" : "Saved on this iPhone"
    }

    private var footer: String {
        if cloud.isSignedIn {
            return "\(model.entries.count) entries. A new phone gets everything back after the same sign-in."
        }
        return "\(model.entries.count) entries. With backup on, a lost or broken phone loses nothing. Turning it off never deletes entries."
    }
}

/// Sign in with Apple, then back up (or restore) right away.
struct AppleBackupButton: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @State private var nonce = ""
    var label: SignInWithAppleButton.Label = .continue

    var body: some View {
        SignInWithAppleButton(label) { request in
            nonce = CloudBackup.makeNonce()
            request.requestedScopes = []
            request.nonce = CloudBackup.sha256(nonce)
        } onCompletion: { result in
            handle(result)
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: Metrics.primaryTouch)
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8)
            else {
                model.problem = "Apple did not return a sign-in token. Try again."
                return
            }
            let raw = nonce
            let cloud = model.cloud
            Task { await cloud.signIn(appleIdentityToken: token, nonce: raw) }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            model.problem = "Sign in with Apple did not finish: \(error.localizedDescription)"
        }
    }
}

/// Deleting the cloud account asks for Apple sign-in once more, so the server can revoke the login.
struct DeleteAccountSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var nonce = ""
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Delete your cloud account?")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Palette.text)
                Text("This removes the cloud copy of every entry and receipt photo, and your Kinledger account. Entries on this iPhone stay, and you can export them first in Me.")
                    .foregroundStyle(Palette.textSecondary)
                Text("A phone you lose afterwards cannot get them back.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.moneyInk)
                if isWorking {
                    ProgressView("Deleting…")
                } else {
                    SignInWithAppleButton(.continue) { request in
                        nonce = CloudBackup.makeNonce()
                        request.requestedScopes = []
                        request.nonce = CloudBackup.sha256(nonce)
                    } onCompletion: { result in
                        handle(result)
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: Metrics.primaryTouch)
                    Text("Confirm with Apple to delete.")
                        .font(.footnote)
                        .foregroundStyle(Palette.textSecondary)
                }
                if let message {
                    Text(message).font(.subheadline).foregroundStyle(Palette.error)
                }
                Spacer()
            }
            .padding(20)
            .background(Palette.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let codeData = credential.authorizationCode,
                  let code = String(data: codeData, encoding: .utf8)
            else {
                message = "Apple did not confirm. Try again."
                return
            }
            isWorking = true
            let cloud = model.cloud
            Task {
                let failure = await cloud.deleteAccount(appleAuthorizationCode: code)
                isWorking = false
                if let failure { message = failure } else { dismiss() }
            }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            message = error.localizedDescription
        }
    }
}

/// From the first screen on a new phone: sign in and bring everything back.
struct RestoreSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Bring back your entries")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Palette.text)
                Text("Sign in with the same Apple account you used for backup. Entries, receipt photos and who you care for come back to this iPhone.")
                    .foregroundStyle(Palette.textSecondary)
                AppleBackupButton(label: .signIn)
                BackupStatusLine(status: model.cloud.status)
                Spacer()
            }
            .padding(20)
            .background(Palette.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .onChange(of: model.profile) { _, profile in
                if profile != nil { dismiss() }
            }
        }
    }
}

/// The small backup line under the date on Today.
struct BackupStatusLine: View {
    let status: BackupStatus

    var body: some View {
        Label(status.text(), systemImage: status.symbol)
            .font(.footnote)
            .foregroundStyle(Palette.textSecondary)
            .accessibilityLabel(status.text())
    }
}
