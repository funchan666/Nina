import AuthenticationServices
import SwiftUI

@MainActor
@main
struct NinaApp: App {
    @StateObject private var library = NinaLibrary()
    @StateObject private var playback = DeckPlayback()
    @StateObject private var store = GripStore()

    var body: some Scene {
        WindowGroup {
            NinaGate()
                .environmentObject(library)
                .environmentObject(playback)
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
    }
}

struct NinaGate: View {
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var playback: DeckPlayback
    @EnvironmentObject private var store: GripStore
    @Environment(\.scenePhase) private var scene
    @State private var opened = false
    @State private var failure = false
    @State private var retry = 0

    var body: some View {
        Group {
            if !opened {
                boot
            } else if let account = library.activeID {
                NinaShell(playback: playback).id(account)
            } else {
                NinaWelcome()
            }
        }
        .task(id: retry) {
            do {
                try await NinaConfiguration.prepareMedia()
                try library.load()
                opened = true
                store.listen(to: library)
            } catch {
                failure = true
            }
        }
        .onChange(of: scene) { if $0 != .active { playback.pause() } }
        .onChange(of: library.activeID) { _ in
            playback.releaseMedia()
            store.dismissOffer()
        }
        .onReceive(NotificationCenter.default.publisher(for: ASAuthorizationAppleIDProvider.credentialRevokedNotification)) { _ in
            if library.me?.method == .apple { try? library.signOut() }
        }
    }

    private var boot: some View {
        VStack(spacing: 13) {
            InkGlyph(ink: .load, size: 46, color: NinaTheme.grip)
            Text(failure ? "Journal unavailable" : "Opening your journal")
                .font(NinaTheme.heading)
                .foregroundColor(NinaTheme.paper)
            if failure {
                Text("Unlock your iPhone and try opening your journal again.")
                    .font(NinaTheme.body)
                    .foregroundColor(NinaTheme.paper)
                    .multilineTextAlignment(.center)
                NinaButton("Try again", icon: .load) {
                    failure = false
                    retry += 1
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NinaTheme.ink.ignoresSafeArea(.container))
    }
}
