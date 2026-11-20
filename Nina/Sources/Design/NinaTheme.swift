import SwiftUI
import UIKit

enum NinaTheme {
    static let paper = Color(red: 245/255, green: 240/255, blue: 229/255)
    static let ink = Color(red: 24/255, green: 38/255, blue: 32/255)
    static let grip = Color(red: 223/255, green: 240/255, blue: 117/255)
    static let sage = Color(red: 221/255, green: 228/255, blue: 213/255)
    static let muted = Color(red: 71/255, green: 84/255, blue: 73/255)
    static let oxide = Color(red: 150/255, green: 56/255, blue: 37/255)

    static let title = Font.custom("BarlowCondensed-Bold", size: 44, relativeTo: .largeTitle)
    static let heading = Font.custom("BarlowCondensed-Bold", size: 32, relativeTo: .title2)
    static let card = Font.custom("BarlowCondensed-Bold", size: 26, relativeTo: .title3)
    static let body = Font.custom("Barlow-Regular", size: 17, relativeTo: .body)
    static let label = Font.custom("Barlow-SemiBold", size: 16, relativeTo: .body)
    static let caption = Font.custom("Barlow-SemiBold", size: 14, relativeTo: .caption)
}

enum NinaInk: String {
    case lines = "InkLines", sessions = "InkSessions", crew = "InkCrew", add = "InkAdd"
    case back = "InkBack", close = "InkClose", play = "InkPlay", pause = "InkPause"
    case speaker = "InkSpeaker", muted = "InkMuted", expand = "InkExpand", like = "InkLike"
    case liked = "InkLiked", save = "InkSave", comment = "InkComment", flag = "InkFlag"
    case saved = "InkSaved", grip = "InkGrip", more = "InkMore", send = "InkSend"
    case phone = "InkPhone", video = "InkVideo", check = "InkCheck", settings = "InkSettings"
    case camera = "InkCamera", load = "InkLoad", spot = "InkSpot", edit = "InkEdit"
    case ramp = "InkRamp", deck = "InkDeck", avatar = "InkAvatar", thumb = "InkThumb"
}

struct InkGlyph: View {
    let ink: NinaInk
    var size: CGFloat = 24
    var color = NinaTheme.ink

    var body: some View {
        Image(ink.rawValue)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundColor(color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct NinaGround: View {
    let image: String
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                NinaTheme.paper
                Image(image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .opacity(0.24)
            }
        }
        .ignoresSafeArea(.container)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

enum NinaButtonKind: Equatable { case primary, paper, ink, text, destructive }

struct NinaPress: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(!enabled ? 0.47 : configuration.isPressed ? 0.72 : 1)
    }
}

struct NinaButton: View {
    let title: String
    var icon: NinaInk?
    var kind: NinaButtonKind
    var wide: Bool
    var action: () -> Void

    init(_ title: String, icon: NinaInk? = nil, kind: NinaButtonKind = .primary, wide: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.kind = kind
        self.wide = wide
        self.action = action
    }

    private var ground: Color {
        switch kind {
        case .primary: return NinaTheme.grip
        case .paper: return NinaTheme.paper
        case .ink: return NinaTheme.ink
        case .text: return .clear
        case .destructive: return NinaTheme.oxide
        }
    }

    private var ink: Color { kind == .ink || kind == .destructive ? NinaTheme.paper : NinaTheme.ink }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let icon { InkGlyph(ink: icon, size: 21, color: ink) }
                Text(title).font(NinaTheme.label).foregroundColor(ink)
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .frame(minWidth: 44, maxWidth: wide ? .infinity : nil, minHeight: 50)
            .background(ground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
        }
        .buttonStyle(NinaPress())
    }
}

struct NinaIconButton: View {
    let title: String
    let icon: NinaInk
    var fg = NinaTheme.ink
    var bg = Color.clear
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            InkGlyph(ink: icon, color: fg)
                .frame(width: 46, height: 46)
                .background(bg)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
        }
        .buttonStyle(NinaPress())
        .accessibilityLabel(Text(title))
    }
}

struct NinaHeading: View {
    let text: String
    var body: some View {
        Text(text).font(NinaTheme.heading).foregroundColor(NinaTheme.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

struct NinaEmpty: View {
    let icon: NinaInk
    let title: String
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            InkGlyph(ink: icon, size: 49)
            NinaHeading(text: title)
            if !note.isEmpty { Text(note).foregroundColor(NinaTheme.muted) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(NinaTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct NinaChoices<Value: Hashable>: View {
    let choices: [Value]
    @Binding var selection: Value
    let label: (Value) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(choices, id: \.self) { choice in
                    NinaButton(label(choice), kind: selection == choice ? .ink : .paper) { selection = choice }
                        .accessibilityAddTraits(selection == choice ? .isSelected : [])
                }
            }
        }
    }
}

struct NinaCheck: View {
    let title: String
    @Binding var enabled: Bool

    var body: some View {
        Button {
            enabled.toggle()
        } label: {
            HStack(spacing: 10) {
                Group {
                    if enabled { InkGlyph(ink: .check, size: 20) }
                    else { Color.clear.frame(width: 20, height: 20) }
                }
                .frame(width: 32, height: 32)
                .background(enabled ? NinaTheme.grip : NinaTheme.sage)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(title).font(NinaTheme.label).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .foregroundColor(NinaTheme.ink)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(NinaPress())
        .accessibilityValue(Text(enabled ? "On" : "Off"))
    }
}

struct NinaField: View {
    let title: String
    @Binding var value: String
    var keyboard: UIKeyboardType = .default
    var lines = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(NinaTheme.label).accessibilityHidden(true)
            field
                .font(NinaTheme.body)
                .keyboardType(keyboard)
                .submitLabel(.done)
                .onSubmit(NinaKeyboard.dismiss)
                .accessibilityLabel(Text(title))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 50, alignment: .topLeading)
                .background(NinaTheme.sage)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder private var field: some View {
        if lines > 1, #available(iOS 16, *) {
            TextField("", text: $value, axis: .vertical).lineLimit(lines...max(lines, 6))
        } else {
            TextField("", text: $value)
        }
    }
}

struct NinaNotice: View {
    let text: String
    var error = false

    var body: some View {
        Text(text)
            .font(NinaTheme.label)
            .foregroundColor(error ? NinaTheme.oxide : NinaTheme.ink)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NinaTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct NinaRow: View {
    let title: String
    var detail: String?
    var icon: NinaInk?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                if let icon { InkGlyph(ink: icon, size: 26) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(NinaTheme.label)
                    if let detail { Text(detail).font(NinaTheme.body).foregroundColor(NinaTheme.muted) }
                }
                Spacer(minLength: 0)
            }
            .multilineTextAlignment(.leading)
            .foregroundColor(NinaTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(NinaTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(NinaPress())
    }
}

@MainActor
enum NinaKeyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
