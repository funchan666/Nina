import SwiftUI

struct NinaAction {
    let title: String
    let icon: NinaInk
    let run: () -> Void
}

struct NinaPage<Content: View>: View {
    let title: String
    var ground: String?
    var root: Bool
    var editing: Bool
    var action: NinaAction?
    @ViewBuilder var content: () -> Content
    @EnvironmentObject private var flow: NinaFlow

    init(_ title: String, ground: String? = nil, root: Bool = false, editing: Bool = false,
         action: NinaAction? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.ground = ground
        self.root = root
        self.editing = editing
        self.action = action
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            if !root {
                NinaActionBand(height: 52) {
                    HStack {
                        NinaIconButton(title: "Back", icon: .back, bg: NinaTheme.paper, action: flow.back)
                            .flipsForRightToLeftLayoutDirection(true)
                        Spacer(minLength: 0)
                        if editing { NinaButton("Done typing", icon: .check, kind: .paper, action: NinaKeyboard.dismiss) }
                    }
                }
            }
            GeometryReader { geometry in
                let margins = NinaRegions.contentMargins(geometry)
                withKeyboard(scrollContent(margins: margins))
            }
        }
        .background {
            if let ground {
                NinaGround(image: ground)
            } else {
                NinaTheme.sage.ignoresSafeArea(.container)
            }
        }
        .foregroundColor(NinaTheme.ink)
        .font(NinaTheme.body)
    }

    private func scrollContent(margins: EdgeInsets) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title)
                        .font(root ? NinaTheme.title : NinaTheme.heading)
                        .accessibilityAddTraits(.isHeader)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    if let action {
                        NinaButton(action.title, icon: action.icon, action: action.run)
                    }
                }
                content()
            }
            .frame(maxWidth: 730, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.leading, margins.leading)
            .padding(.trailing, margins.trailing)
            .padding(.top, root ? 12 : 4)
            .padding(.bottom, 30)
            .background {
                if editing { Color.clear.contentShape(Rectangle()).onTapGesture(perform: NinaKeyboard.dismiss) }
            }
        }
    }

    @ViewBuilder private func withKeyboard<Scroll: View>(_ scroll: Scroll) -> some View {
        if editing, #available(iOS 16, *) {
            scroll.scrollDismissesKeyboard(.interactively)
        } else if editing {
            scroll.simultaneousGesture(
                DragGesture(minimumDistance: 22).onEnded { movement in
                    if abs(movement.translation.height) > abs(movement.translation.width) { NinaKeyboard.dismiss() }
                }
            )
        } else {
            scroll
        }
    }
}

struct NinaActionBand<Content: View>: View {
    let height: CGFloat
    var minimumWidth: CGFloat = 120
    @ViewBuilder var content: () -> Content
    @Environment(\.layoutDirection) private var direction

    var body: some View {
        GeometryReader { geometry in
            let insets = NinaRegions.bandMargins(geometry, direction: direction)
            let available = geometry.size.width - insets.leading - insets.trailing
            Group {
                if available < minimumWidth {
                    ScrollView(.horizontal, showsIndicators: false) {
                        content().frame(width: minimumWidth, height: height)
                    }
                } else {
                    content().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.leading, insets.leading)
            .padding(.trailing, insets.trailing)
        }
        .frame(height: height)
    }
}

enum NinaRegions {
    static func contentMargins(_ geometry: GeometryProxy) -> EdgeInsets {
        if #available(iOS 27.1, *) {
            let system = geometry.contentMargins(for: .container, edges: .horizontal)
            return EdgeInsets(top: 0, leading: max(16, system.leading), bottom: 0, trailing: max(16, system.trailing))
        }
        return EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18)
    }

    static func bandMargins(_ geometry: GeometryProxy, direction: LayoutDirection) -> EdgeInsets {
        let margins = contentMargins(geometry)
        let rtl = direction == .rightToLeft
        let side = max(0, (geometry.size.width - 760) / 2)
        let left = max(rtl ? margins.trailing : margins.leading, side)
        let right = max(rtl ? margins.leading : margins.trailing, side)
        let width = max(0, geometry.size.width - left - right)
        let band = CGRect(x: left, y: 0, width: width, height: geometry.size.height)
        let protected = activeRegions(in: geometry).map { $0.intersection(band) }.filter { !$0.isNull && !$0.isEmpty }
        let slots = freeHorizontalRanges(in: band, excluding: protected)
        let slot = slots.max { ($0.upperBound - $0.lowerBound) < ($1.upperBound - $1.lowerBound) }
        let resolvedLeft: CGFloat
        let resolvedRight: CGFloat
        if let slot {
            resolvedLeft = slot.lowerBound
            resolvedRight = max(0, geometry.size.width - slot.upperBound)
        } else {
            resolvedLeft = left
            resolvedRight = right
        }
        return EdgeInsets(top: 0, leading: rtl ? resolvedRight : resolvedLeft,
                          bottom: 0, trailing: rtl ? resolvedLeft : resolvedRight)
    }

    static func activeRegions(in geometry: GeometryProxy) -> [CGRect] {
        guard #available(iOS 27.1, *) else { return [] }
        let dividers = geometry.reservedRegions(kind: .division, layoutDirectionBehavior: .fixed)
        let occlusions = geometry.reservedRegions(kind: .occlusion, layoutDirectionBehavior: .fixed)
        return (dividers + occlusions).filter(\.isActive).map(\.frame)
    }

    private static func freeHorizontalRanges(in bounds: CGRect, excluding rects: [CGRect]) -> [ClosedRange<CGFloat>] {
        var ranges: [ClosedRange<CGFloat>] = []
        var edge = bounds.minX
        for rect in rects.sorted(by: { $0.minX < $1.minX }) {
            if rect.minX > edge { ranges.append(edge...min(bounds.maxX, rect.minX)) }
            edge = max(edge, rect.maxX)
        }
        if edge < bounds.maxX { ranges.append(edge...bounds.maxX) }
        return ranges
    }
}

private struct NinaRouteVisibility: EnvironmentKey { static let defaultValue = true }
extension EnvironmentValues {
    var ninaRouteVisible: Bool {
        get { self[NinaRouteVisibility.self] }
        set { self[NinaRouteVisibility.self] = newValue }
    }
}
