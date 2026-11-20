import SwiftUI

struct ProfileEditor: View {
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow
    @State private var name = ""
    @State private var bio = ""
    @State private var stance = SkateStance.regular
    @State private var selection: SkateSelection?
    @State private var removePhoto = false
    @State private var loaded = false
    @State private var saveTask: Task<Void, Never>?
    @State private var busy = false

    var body: some View {
        NinaPage("Edit profile", ground: "CrewGround", editing: true) {
            if let selection {
                SkateStill(url: selection.url, label: "Selected profile photo", fill: false, pixels: 420)
                    .frame(height: 130)
            } else if let me = library.me, !removePhoto {
                SkaterAvatar(skater: me, edge: 83)
            }
            VStack(alignment: .leading, spacing: 5) {
                SkatePickerButton(source: .photos, title: "Choose a profile photo", icon: .avatar, pick: use, report: error)
                SkatePickerButton(source: .picture, title: "Take a profile photo", icon: .camera, pick: use, report: error)
                if selection != nil || (library.me?.profile.avatar != nil && !removePhoto) {
                    NinaButton("Remove photo", icon: .close, kind: .paper) {
                        selection = nil
                        removePhoto = true
                    }
                }
                if flow.notice?.contains("Settings") == true {
                    NinaButton("Open iPhone Settings", icon: .settings, kind: .paper, action: NinaDeviceSettings.open)
                }
            }
            .disabled(busy)
            NinaField(title: "Display name", value: $name)
            VStack(alignment: .leading, spacing: 5) {
                Text("Stance").font(NinaTheme.label)
                NinaChoices(choices: SkateStance.allCases, selection: $stance, label: \.title)
            }
            NinaField(title: "Skater bio", value: $bio, lines: 4)
            NinaButton(busy ? "Saving…" : "Save profile", icon: .check, action: save)
                .disabled(busy || name.cleaned.isEmpty)
        }
        .onAppear {
            guard !loaded, let profile = library.me?.profile else { return }
            loaded = true
            name = profile.name
            bio = profile.bio
            stance = profile.stance
        }
        .onDisappear { saveTask?.cancel() }
    }

    private func use(_ selection: SkateSelection) {
        guard !busy else { return }
        self.selection = selection
        removePhoto = false
        flow.notice = nil
    }

    private func error(_ message: String) { flow.notice = message }

    private func save() {
        guard !busy, let me = library.me else { return }
        NinaKeyboard.dismiss()
        let chosen = selection
        let origin = flow.position
        var profile = SkaterProfile(name: name, stance: stance, bio: bio, avatar: removePhoto ? nil : me.profile.avatar)
        busy = true
        saveTask = Task {
            var imported: SkateAttachment?
            defer { busy = false; saveTask = nil }
            do {
                if let chosen {
                    imported = try await NinaFiles.importMedia(chosen, owner: me.id, forAvatar: true)
                    profile.avatar = imported
                }
                try Task.checkCancellation()
                guard me.id == library.activeID else { throw NinaIssue("Open the profile that owns this photo.") }
                try library.updateProfile(profile)
                if let old = me.profile.avatar, old != profile.avatar { NinaFiles.remove(old, owner: me.id) }
                if flow.position == origin {
                    flow.back()
                    flow.notice = "Profile saved."
                }
            } catch let issue {
                if let imported { NinaFiles.remove(imported, owner: me.id) }
                if !Task.isCancelled { error((issue as? NinaIssue)?.text ?? "Couldn't save your profile.") }
            }
        }
    }
}
