import SwiftUI

enum NinaTab: String, CaseIterable, Identifiable {
    case lines = "Discover", sessions = "Sessions", crew = "Crew", messages = "Inbox", profile = "You"

    var id: Self { self }
    var icon: NinaInk {
        switch self {
        case .lines: return .lines
        case .sessions: return .sessions
        case .crew: return .crew
        case .messages: return .comment
        case .profile: return .avatar
        }
    }
}

enum NinaRoute: Hashable {
    case collection
    case savedLines
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
    struct Position: Equatable {
        let tab: NinaTab
        let entry: UUID?
    }
    @Published private(set) var tab: NinaTab = .lines
    @Published private(set) var paths: [NinaTab: [NinaRouteEntry]] = [:]
    @Published var notice: String?
    private let playback: DeckPlayback

    init(playback: DeckPlayback) { self.playback = playback }

    var position: Position { Position(tab: tab, entry: paths[tab]?.last?.id) }

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
    @EnvironmentObject private var library: NinaLibrary
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if flow.paths[flow.tab, default: []].isEmpty { dock }
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
        .background(NinaTheme.paper.ignoresSafeArea(.container))
    }

    private func tabStack(_ tab: NinaTab) -> some View {
        let path = flow.paths[tab, default: []]
        let rootActive = flow.tab == tab && path.isEmpty
        return ZStack {
            tabPage(tab)
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
        case .lines: DiscoverPage()
        case .sessions: SessionBook()
        case .crew: CrewIndex()
        case .messages: MessagesPage(root: true)
        case .profile:
            if let id = library.activeID { SkaterPage(id: id, root: true) }
        }
    }

    private var dock: some View {
        NinaActionBand(height: textSize.isAccessibilitySize ? 90 : 76, minimumWidth: textSize.isAccessibilitySize ? 480 : 280) {
            HStack(spacing: 3) {
                ForEach(NinaTab.allCases) { tab in
                    let selected = flow.tab == tab
                    Button {
                        flow.select(tab)
                    } label: {
                        VStack(spacing: 2) {
                            InkGlyph(ink: tab.icon, size: 23, color: selected ? NinaTheme.ink : NinaTheme.muted)
                                .frame(width: 47, height: 34)
                                .background(selected ? NinaTheme.grip : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(alignment: .topTrailing) {
                                    if tab == .messages, library.unread > 0 {
                                        Text(library.unread > 99 ? "99+" : "\(library.unread)")
                                            .font(.custom("Barlow-SemiBold", size: 10, relativeTo: .caption2))
                                            .foregroundColor(NinaTheme.paper)
                                            .padding(.horizontal, 4).padding(.vertical, 2)
                                            .background(NinaTheme.oxide).clipShape(Capsule())
                                            .offset(x: 5, y: -4)
                                    }
                                }
                            Text(tab.rawValue).font(.custom("Barlow-SemiBold", size: 12, relativeTo: .caption)).lineLimit(1)
                        }
                        .foregroundColor(selected ? NinaTheme.ink : NinaTheme.muted)
                        .frame(minWidth: 44, maxWidth: .infinity, minHeight: 60)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(NinaPress())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityLabel(tab == .messages && library.unread > 0 ? "Inbox, \(library.unread) unread updates" : tab.rawValue)
                }
            }
        }
        .background(NinaTheme.paper.ignoresSafeArea(.container, edges: .bottom))
    }

    @ViewBuilder private func screen(_ route: NinaRoute) -> some View {
        switch route {
        case .collection: LinesIndex(root: false)
        case .savedLines: LinesIndex(root: false, savedOnly: true)
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
