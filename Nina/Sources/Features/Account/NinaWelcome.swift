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
                VStack(alignment: .leading, spacing: 0) {
                    if mode == .welcome {
                        welcome
                            .padding(.leading, margins.leading + 6)
                            .padding(.trailing, margins.trailing + 6)
                            .padding(.bottom, 24)
                            .frame(maxWidth: 540)
                            .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .bottom)
                    } else {
                        NinaActionBand(height: 60) {
                            HStack {
                                NinaIconButton(title: "Back to welcome", icon: .back, bg: NinaTheme.paper) {
                                    guard !busy else { return }
                                    NinaKeyboard.dismiss()
                                    password = ""
                                    error = ""
                                    mode = .welcome
                                }
                                .disabled(busy)
                                Spacer(minLength: 0)
                            }
                        }
                        Spacer(minLength: min(geometry.size.height * 0.16, 130))
                        emailForm
                            .padding(.horizontal, max(20, margins.leading))
                            .padding(.vertical, 26)
                            .frame(maxWidth: 560)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(NinaTheme.paper)
                            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26))
                    }
                }
                .frame(minHeight: geometry.size.height, alignment: .bottom)
            }
            .scrollDismissesKeyboard(.interactively)
            .background {
                Image("WelcomeGround").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom)
                    .clipped().ignoresSafeArea(.container)
                    .accessibilityHidden(true).allowsHitTesting(false)
            }
        }
        .background(NinaTheme.ink.ignoresSafeArea(.container))
        .font(NinaTheme.body)
        .foregroundColor(mode == .welcome ? NinaTheme.paper : NinaTheme.ink)
        .fullScreenCover(item: $policy) { document in NinaPolicyPage(policy: document) { policy = nil } }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("See you\nat the spot.")
                .font(.custom("BarlowCondensed-Bold", size: 55, relativeTo: .largeTitle))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("For the clips you replay and the friends you skate with.")
                .foregroundColor(NinaTheme.paper)
            if let deletion = library.deletionNotice { NinaNotice(text: deletion) }
            NinaButton("Create profile", wide: true) { mode = .register }
            NinaButton("Sign in", kind: .ink, wide: true) { mode = .email }
        }
    }

    private var emailForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(mode == .register ? "Meet your next crew." : "Welcome back.")
                .font(NinaTheme.title).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(mode == .register ? "Make a profile. Share your next skate day." : "Your next session starts here.")
                .foregroundColor(NinaTheme.muted)
            NinaField(title: "Email address", value: $email, keyboard: .emailAddress)
                .textInputAutocapitalization(.never).autocorrectionDisabled().textContentType(.username)
            VStack(alignment: .leading, spacing: 5) {
                Text("Password").font(NinaTheme.label).accessibilityHidden(true)
                SecureField("", text: $password)
                    .textContentType(mode == .register ? .newPassword : .password)
                    .accessibilityLabel("Password").submitLabel(.go).onSubmit(finishEmail)
                    .font(NinaTheme.body).padding(12).frame(minHeight: 50)
                    .background(NinaTheme.sage).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            agreement
            if !error.isEmpty { NinaNotice(text: error, error: true).accessibilityAddTraits(.updatesFrequently) }
            NinaButton(busy ? "Opening your profile…" : mode == .register ? "Create profile" : "Sign in", wide: true, action: finishEmail)
                .disabled(busy || !accepted)
            NinaButton(mode == .register ? "Have a profile? Sign in" : "New here? Create a profile", kind: .text) {
                mode = mode == .register ? .email : .register
                error = ""
            }.disabled(busy)
            appleButton
        }
        .disabled(busy)
    }

    private var agreement: some View {
        VStack(alignment: .leading, spacing: 0) {
            NinaCheck(title: "I agree to the Terms and Privacy Policy", enabled: $accepted)
            HStack(spacing: 5) {
                NinaButton("Terms", kind: .text) { policy = .terms }
                NinaButton("Privacy Policy", kind: .text) { policy = .privacy }
            }
        }
    }

    private var appleButton: some View {
        SignInWithAppleButton(.signIn) { request in
            guard accepted, !busy else { return }
            busy = true
            error = ""
            request.requestedScopes = [.fullName]
        } onCompletion: { result in
            defer { busy = false }
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
                } catch { self.error = (error as? NinaIssue)?.text ?? "Apple sign-in couldn't be saved." }
            case .failure(let failure):
                if (failure as? ASAuthorizationError)?.code != .canceled {
                    error = "Apple sign-in couldn't complete. Try again."
                }
            }
        }
        .signInWithAppleButtonStyle(.black).frame(height: 50)
        .disabled(!accepted || busy)
    }

    private func finishEmail() {
        guard !busy, accepted else { return }
        busy = true
        error = ""
        NinaKeyboard.dismiss()
        defer { busy = false }
        do {
            try library.signIn(email: email, password: password)
            password = ""
        } catch { self.error = (error as? NinaIssue)?.text ?? "Couldn't open your profile. Try again." }
    }
}
