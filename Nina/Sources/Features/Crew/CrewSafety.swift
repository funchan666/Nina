import SwiftUI
import UIKit

struct ReportPage: View {
    let subject: SafetySubject
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow
    @State private var reason: SafetyReason?

    var body: some View {
        NinaPage("Report", ground: "CrewGround") {
            Text("Choose why you want to hide this item.")
            ForEach(SafetyReason.allCases) { item in
                NinaButton(item.rawValue, icon: item == reason ? .check : nil, kind: item == reason ? .ink : .paper) {
                    reason = item
                }
                .accessibilityAddTraits(item == reason ? .isSelected : [])
            }
            if let reason {
                NinaNotice(text: "Confirm this report to hide the item.")
                NinaButton("Confirm report", icon: .flag, kind: .destructive) {
                    flow.run {
                        try library.fileReport(subject, reason: reason)
                        flow.back()
                        flow.notice = "Report recorded. Item hidden."
                    }
                }
            }
        }
    }
}

struct BlockPage: View {
    let peer: UUID
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow

    var body: some View {
        NinaPage("Block skater", ground: "CrewGround") {
            let person = library.visibleSkater(peer)?.profile.name ?? "this skater"
            NinaEmpty(icon: .flag, title: "Block \(person)?",
                      note: "Blocking hides profiles, comments and activity and removes both follow connections.")
            NinaButton("Block skater", icon: .close, kind: .destructive) {
                flow.run {
                    try library.setBlocked(peer, blocked: true)
                    flow.back()
                    flow.notice = "Skater blocked."
                }
            }
            NinaButton("Cancel", kind: .paper, action: flow.back)
        }
    }
}

struct BlacklistPage: View {
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow

    var body: some View {
        NinaPage("Blocked skaters", ground: "CrewGround") {
            let items = (library.me?.blocked ?? []).compactMap { library.archive.accounts[$0] }
                .sorted { $0.profile.name < $1.profile.name }
            if items.isEmpty { NinaEmpty(icon: .crew, title: "No blocked skaters", note: "") }
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.profile.name).font(NinaTheme.card)
                    NinaButton("Unblock", icon: .check, kind: .paper) {
                        flow.run {
                            try library.setBlocked(item.id, blocked: false)
                            flow.notice = "Skater unblocked."
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NinaTheme.paper)
            }
        }
    }
}

@MainActor
enum NinaDeviceSettings {
    static func open() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}

struct NinaSettings: View {
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow
    @Environment(\.openURL) private var openURL

    var body: some View {
        NinaPage("Settings", ground: "CrewGround") {
            NinaRow(title: "Blocked skaters", detail: nil, icon: .crew) { flow.open(.blacklist) }
            ForEach(NinaPolicy.allCases) { policy in
                NinaRow(title: policy.title, detail: nil, icon: nil) { flow.open(.policy(policy)) }
            }
            if !NinaConfiguration.supportEmail.isEmpty,
               let contact = URL(string: "mailto:" + NinaConfiguration.supportEmail) {
                NinaRow(title: "Contact support", detail: nil, icon: .comment) { openURL(contact) }
            }
            NinaButton("Sign out", kind: .paper) { flow.run { try library.signOut() } }
            NinaButton("Delete profile", kind: .destructive) { flow.open(.deleteProfile) }
        }
    }
}

struct DeleteProfilePage: View {
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow
    @State private var confirmed = false

    var body: some View {
        NinaPage("Delete profile", ground: "CrewGround") {
            NinaEmpty(icon: .avatar, title: "Remove your skate profile",
                      note: "This erases your spots, trick logs, media, messages, connections and Grip.")
            NinaCheck(title: "Delete this profile and its records", enabled: $confirmed)
            NinaButton("Delete profile", icon: .close, kind: .destructive) {
                flow.run { try library.deleteAccount() }
            }
            .disabled(!confirmed)
        }
    }
}
