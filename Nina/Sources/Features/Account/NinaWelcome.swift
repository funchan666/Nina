import AuthenticationServices
import SwiftUI

struct NinaWelcome: View {
    private enum Mode { case welcome, email, register }

    @EnvironmentObject private var library: NinaLibrary
    @State private var mode: Mode = .welcome
    @State private var accepted = false
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error = ""
    @State private var policy: NinaPolicy?

    var body: some View {
        GeometryReader { geometry in
            let margins = NinaRegions.contentMargins(geometry)
            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    if mode == .welcome {
                        welcomeHeader
                    } else {
                        emailForm
                    }
                    agreement
                    if busy {
                        HStack {
                            InkGlyph(ink: .load, color: NinaTheme.grip)
                            Text("Opening your profile").font(NinaTheme.label)
                        }
                        .foregroundColor(NinaTheme.paper)
                        .accessibilityElement(children: .combine)
                    }
                    if !error.isEmpty { NinaNotice(text: error, error: true) }
                    if let deletion = library.deletionNotice { NinaNotice(text: deletion) }
                    if mode == .welcome {
                        welcomeActions
                    } else {
                        NinaButton(mode == .register ? "Create profile" : "Continue", icon: .check, action: finishEmail)
                            .disabled(busy || !accepted)
                    }
                }
                .padding(16)
                .background(NinaTheme.ink.opacity(0.97))
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.leading, margins.leading)
                .padding(.trailing, margins.trailing)
                .padding(.bottom, 10)
                .frame(minHeight: geometry.size.height, alignment: .bottom)
            }
            .background {
                NinaGround(image: "WelcomeGround")
                    .overlay(alignment: .topLeading) {
                        Image("WheelMark")
                            .resizable().scaledToFit()
                            .frame(width: 68, height: 68)
                            .padding(.leading, margins.leading)
                            .accessibilityHidden(true)
                    }
            }
            .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { movement in
                if abs(movement.translation.height) > abs(movement.translation.width) { NinaKeyboard.dismiss() }
            })
        }
        .foregroundColor(NinaTheme.paper)
        .fullScreenCover(item: $policy) { document in NinaPolicyPage(policy: document) { policy = nil } }
    }

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Nina")
                .font(NinaTheme.title)
                .accessibilityAddTraits(.isHeader)
            Text("Find a line. Keep a skate journal.")
                .font(NinaTheme.body)
                .foregroundColor(NinaTheme.paper)
        }
    }

    private var agreement: some View {
        VStack(alignment: .leading, spacing: 0) {
            NinaCheck(title: "I agree to the Terms and Privacy Policy", enabled: $accepted)
            HStack(spacing: 6) {
                NinaButton("Terms", kind: .paper) { policy = .terms }
                NinaButton("Privacy", kind: .paper) { policy = .privacy }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
        .background(NinaTheme.sage)
    }

    private var welcomeActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            SignInWithAppleButton(.continue) { request in
                busy = true
                error = ""
                request.requestedScopes = [.fullName]
            } onCompletion: { result in
                busy = false
                guard accepted else { return }
                switch result {
                case .success(let authorization):
                    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                        error = "Apple couldn't return your profile."
                        return
                    }
                    do {
                        let name = credential.fullName.map { PersonNameComponentsFormatter().string(from: $0) }
                        try library.signIn(appleSubject: credential.user, fullName: name)
                    } catch let issue {
                        error = (issue as? NinaIssue)?.text ?? "Apple sign-in couldn't be saved."
                    }
                case .failure(let failure):
                    if (failure as? ASAuthorizationError)?.code != .canceled {
                        error = "Apple sign-in couldn't complete. Try again."
                    }
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 47)
            .disabled(!accepted || busy)

            HStack(spacing: 8) {
                NinaButton("Email sign-in", kind: .primary) {
                    error = ""
                    mode = .email
                }
                NinaButton("Create profile", kind: .paper) {
                    error = ""
                    mode = .register
                }
            }
            .disabled(busy)
        }
    }

    private var emailForm: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(mode == .register ? "Create a skater profile" : "Email sign-in").font(NinaTheme.heading)
                Spacer(minLength: 0)
                NinaIconButton(title: "Back", icon: .back, fg: NinaTheme.paper) {
                    NinaKeyboard.dismiss()
                    error = ""
                    password = ""
                    mode = .welcome
                }
            }
            Text("Email profiles are available on this iPhone.")
                .font(NinaTheme.body)
            VStack(alignment: .leading, spacing: 8) {
                TextField("Email address", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Divider()
                SecureField("Password", text: $password)
                    .submitLabel(.done)
                    .onSubmit(finishEmail)
            }
            .font(NinaTheme.body)
            .foregroundColor(NinaTheme.ink)
            .padding(12)
            .background(NinaTheme.paper)
        }
    }

    private func finishEmail() {
        guard !busy, accepted else { return }
        NinaKeyboard.dismiss()
        busy = true
        error = ""
        Task { @MainActor in
            await Task.yield()
            defer { busy = false }
            do {
                try library.signIn(email: email, password: password)
                password = ""
            } catch let issue {
                error = (issue as? NinaIssue)?.text ?? "Couldn't open your profile. Try again."
            }
        }
    }
}
