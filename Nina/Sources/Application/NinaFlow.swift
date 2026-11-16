import SwiftUI

enum NinaTab: String, CaseIterable, Identifiable {
    case lines = "Lines", sessions = "Sessions", crew = "Crew"

    var id: Self { self }
    var icon: NinaInk {
        switch self {
        case .lines: return .lines
        case .sessions: return .sessions
        case .crew: return .crew
        }
    }
}

enum NinaRoute: Hashable {
    case line(String)
    case lineViewer(String)
    case postEditor(UUID?)
    case submissions
    case submissionViewer(UUID)
    case spotEditor(UUID?, String?)
    case spot(UUID)
    case trick(UUID?, UUID?, String?)
    case crewAtSpot(String, String)
    case profile(UUID)
    case profileEditor
    case relationships(UUID, Bool)
    case messages
    case conversation(UUID)
    case call(UUID, SkateCallKind)
    case report(SafetySubject)
    case block(UUID)
    case blacklist
    case settings
    case policy(NinaPolicy)
    case deleteProfile
    case wallet
    case covers
}

struct NinaRouteEntry: Identifiable {
    var id = UUID()
    let route: NinaRoute
}

@MainActor
final class NinaFlow: ObservableObject {
    @Published private(set) var tab: NinaTab = .lines
    @Published private(set) var paths: [NinaTab: [NinaRouteEntry]] = [:]
    @Published var notice: String?
    private let playback: DeckPlayback

    init(playback: DeckPlayback) { self.playback = playback }

    func open(_ route: NinaRoute) {
        guard paths[tab]?.last?.route != route else { return }
        playback.pause()
        NinaKeyboard.dismiss()
        notice = nil
        paths[tab, default: []].append(NinaRouteEntry(route: route))
    }

    func back() {
        guard paths[tab]?.isEmpty == false else { return }
        playback.pause()
        NinaKeyboard.dismiss()
        notice = nil
        paths[tab]?.removeLast()
    }

    func select(_ destination: NinaTab) {
        guard tab != destination else { return }
        playback.pause()
        NinaKeyboard.dismiss()
        notice = nil
        tab = destination
    }

    func run(_ change: () throws -> Void) {
        do {
            try change()
        } catch {
            notice = (error as? NinaIssue)?.text ?? "That change couldn't be saved. Try again."
        }
    }
}

struct NinaShell: View {
    @StateObject private var flow: NinaFlow
    @Environment(\.dynamicTypeSize) private var textSize

    init(playback: DeckPlayback) { _flow = StateObject(wrappedValue: NinaFlow(playback: playback)) }

    var body: some View {
        ZStack {
            ForEach(NinaTab.allCases) { tab in
                tabStack(tab)
                    .opacity(flow.tab == tab ? 1 : 0)
                    .allowsHitTesting(flow.tab == tab)
                    .accessibilityHidden(flow.tab != tab)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let notice = flow.notice {
                HStack(alignment: .center, spacing: 2) {
                    NinaNotice(text: notice)
                    NinaIconButton(title: "Dismiss message", icon: .close, bg: NinaTheme.paper) { flow.notice = nil }
                }
                .padding(.horizontal, 12)
                .background(NinaTheme.paper)
            }
        }
        .environmentObject(flow)
    }

    private func tabStack(_ tab: NinaTab) -> some View {
        let path = flow.paths[tab, default: []]
        let rootActive = flow.tab == tab && path.isEmpty
        return ZStack {
            tabPage(tab)
                .safeAreaInset(edge: .bottom, spacing: 0) { dock }
                .environment(\.ninaRouteVisible, rootActive)
                .opacity(path.isEmpty ? 1 : 0)
                .allowsHitTesting(rootActive)
                .accessibilityHidden(!rootActive)
            ForEach(path) { entry in
                let active = flow.tab == tab && entry.id == path.last?.id
                screen(entry.route)
                    .environment(\.ninaRouteVisible, active)
                    .opacity(active ? 1 : 0)
                    .allowsHitTesting(active)
                    .accessibilityHidden(!active)
            }
        }
    }

    @ViewBuilder private func tabPage(_ tab: NinaTab) -> some View {
        switch tab {
        case .lines: LinesIndex()
        case .sessions: SessionBook()
        case .crew: CrewIndex()
        }
    }

    private var dock: some View {
        NinaActionBand(height: textSize.isAccessibilitySize ? 76 : 62, minimumWidth: 155) {
            HStack(spacing: 3) {
                ForEach(NinaTab.allCases) { tab in
                    let selected = flow.tab == tab
                    Button {
                        flow.select(tab)
                    } label: {
                        VStack(spacing: 2) {
                            InkGlyph(ink: tab.icon, size: 21, color: selected ? NinaTheme.ink : NinaTheme.paper)
                            Text(tab.rawValue).font(NinaTheme.caption).lineLimit(1).minimumScaleFactor(0.65)
                        }
                        .foregroundColor(selected ? NinaTheme.ink : NinaTheme.paper)
                        .frame(minWidth: 44, maxWidth: .infinity, minHeight: 45)
                        .padding(.vertical, 2)
                        .background(selected ? NinaTheme.grip : NinaTheme.ink)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(NinaPress())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .background(NinaTheme.ink.ignoresSafeArea(.container, edges: .bottom))
    }

    @ViewBuilder private func screen(_ route: NinaRoute) -> some View {
        switch route {
        case .line(let id): LineDetail(id: id)
        case .lineViewer(let id): LineViewer(id: id)
        case .postEditor(let id): SubmissionEditor(id: id)
        case .submissions: SubmissionsPage()
        case .submissionViewer(let id): SubmissionViewer(id: id)
        case .spotEditor(let id, let line): SpotEditor(id: id, referenceID: line)
        case .spot(let id): SpotPage(id: id)
        case .trick(let id, let spot, let line): TrickEditor(id: id, spotID: spot, referenceID: line)
        case .crewAtSpot(let key, let name): CrewIndex(spotKey: key, spotName: name)
        case .profile(let id): SkaterPage(id: id)
        case .profileEditor: ProfileEditor()
        case .relationships(let id, let incoming): RelationshipsPage(id: id, incoming: incoming)
        case .messages: MessagesPage()
        case .conversation(let id): ConversationPage(peer: id)
        case .call(let id, let kind): SkateCallPage(peer: id, kind: kind)
        case .report(let subject): ReportPage(subject: subject)
        case .block(let id): BlockPage(peer: id)
        case .blacklist: BlacklistPage()
        case .settings: NinaSettings()
        case .policy(let policy): NinaPolicyPage(policy: policy, dismiss: flow.back)
        case .deleteProfile: DeleteProfilePage()
        case .wallet: GripWallet()
        case .covers: JournalCoverShop()
        }
    }
}
