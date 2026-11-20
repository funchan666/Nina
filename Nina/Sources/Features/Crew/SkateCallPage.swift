import AVFoundation
import Combine
import SwiftUI
import UIKit

enum SkateCallKind: Hashable {
    case voice, video
    var title: String { self == .video ? "Video call" : "Voice call" }
}

struct SkateCallPage: View {
    let peer: UUID
    let kind: SkateCallKind
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow
    @Environment(\.scenePhase) private var scene
    @StateObject private var camera = SkateCallCamera()
    @State private var phase = Phase.preparing
    @State private var position = CGPoint(x: 0.93, y: 0.78)
    @GestureState private var delta = CGSize.zero
    @State private var started = false
    @State private var finished = false

    private enum Phase {
        case preparing
        case waiting(AVCaptureDevice?)
        case permissions(String)
        case ended(String)

        var message: String {
            switch self {
            case .preparing: return "Checking access…"
            case .waiting: return "Waiting preview"
            case .permissions(let message), .ended(let message): return message
            }
        }
    }

    var body: some View {
        VStack(spacing: 7) {
            NinaActionBand(height: 55) {
                HStack {
                    NinaIconButton(title: "Close call", icon: .close, fg: NinaTheme.paper, action: close)
                    Text(kind.title).font(NinaTheme.card).lineLimit(2)
                    Spacer(minLength: 0)
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let skater = library.visibleSkater(peer) {
                        Text(skater.profile.name).font(NinaTheme.heading).accessibilityAddTraits(.isHeader)
                    }
                    Text(phase.message)
                        .font(NinaTheme.body)
                        .fixedSize(horizontal: false, vertical: true)
                    if case .permissions = phase {
                        NinaButton("Open iPhone Settings", icon: .settings, kind: .paper, action: NinaDeviceSettings.open)
                    }
                }
                .frame(maxWidth: 670, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
            }
            .frame(maxHeight: 150)
            GeometryReader { geometry in
                if case .waiting(let device?) = phase {
                    cameraTile(device: device, geometry: geometry)
                } else if case .waiting = phase {
                    InkGlyph(ink: .phone, size: 72, color: NinaTheme.grip)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            NinaActionBand(height: 66) {
                NinaButton("Close waiting", icon: .close, kind: .destructive, action: close)
                    .accessibilityLabel("Cancel and close call waiting")
            }
        }
        .foregroundColor(NinaTheme.paper)
        .background(NinaTheme.ink.ignoresSafeArea(.container))
        .task { await begin() }
        .onChange(of: scene) { phase in
            if phase == .background {
                finish("Waiting ended when Nina went into the background.")
            }
        }
        .onDisappear { camera.stop() }
    }

    @ViewBuilder private func cameraTile(device: AVCaptureDevice, geometry: GeometryProxy) -> some View {
        let width = min(152, max(0, geometry.size.width - 18))
        let height = min(width * 1.22, max(0, geometry.size.height - 18))
        let dx = max(1, geometry.size.width - width)
        let dy = max(1, geometry.size.height - height)
        let x = width / 2 + position.x * dx + delta.width
        let y = height / 2 + position.y * dy + delta.height
        let permitted = CGRect(x: width / 2, y: height / 2, width: dx, height: dy)
        let regions = NinaRegions.activeRegions(in: geometry)
        let desired = CGPoint(x: x, y: y)
        if width >= 48, height >= 48,
           let center = safeCenter(near: desired, in: permitted, cameraWidth: width, cameraHeight: height, avoiding: regions) {
            SkateFrontPreview(session: camera.session, device: device)
                .frame(width: width, height: height)
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    Text("Your camera").font(NinaTheme.caption).padding(6).background(NinaTheme.ink)
                        .allowsHitTesting(false)
                }
                .accessibilityLabel("Your camera")
                .accessibilityHint("Drag to move the camera within the available area")
                .position(center)
                .gesture(DragGesture(coordinateSpace: .named("NinaCameraArea"))
                    .updating($delta) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        let final = CGPoint(x: width / 2 + position.x * dx + value.translation.width,
                                            y: height / 2 + position.y * dy + value.translation.height)
                        if let point = safeCenter(near: final, in: permitted, cameraWidth: width, cameraHeight: height, avoiding: regions) {
                            position = CGPoint(x: (point.x - width / 2) / dx, y: (point.y - height / 2) / dy)
                        }
                    })
                .coordinateSpace(name: "NinaCameraArea")
        } else {
            Text("Open more space to see your camera.")
                .font(NinaTheme.body)
                .padding(8)
        }
    }

    private func safeCenter(near desired: CGPoint, in bounds: CGRect, cameraWidth: CGFloat, cameraHeight: CGFloat,
                            avoiding regions: [CGRect]) -> CGPoint? {
        let halfX = cameraWidth / 2
        let halfY = cameraHeight / 2
        let xs = [desired.x, bounds.minX, bounds.maxX] + regions.flatMap { [$0.minX - halfX - 4, $0.maxX + halfX + 4] }
        let ys = [desired.y, bounds.minY, bounds.maxY] + regions.flatMap { [$0.minY - halfY - 4, $0.maxY + halfY + 4] }
        let candidates = xs.flatMap { x in
            ys.map { y in CGPoint(x: min(bounds.maxX, max(bounds.minX, x)), y: min(bounds.maxY, max(bounds.minY, y))) }
        }
        return candidates.filter { point in
            let frame = CGRect(x: point.x - halfX, y: point.y - halfY, width: cameraWidth, height: cameraHeight)
            return !regions.contains { $0.intersects(frame) }
        }.min { distance($0, to: desired) < distance($1, to: desired) }
    }

    private func distance(_ first: CGPoint, to second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }

    private func begin() async {
        guard !started else { return }
        started = true
        guard library.canContact(peer) else {
            finish("Both skaters must follow each other to open call waiting.")
            return
        }
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            if !Task.isCancelled && !finished { phase = .permissions("Allow microphone access to open call waiting.") }
            return
        }
        guard !Task.isCancelled, !finished, scene != .background else { return }
        var device: AVCaptureDevice?
        if kind == .video {
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                if !Task.isCancelled && !finished { phase = .permissions("Allow camera access to see your camera.") }
                return
            }
            do {
                try Task.checkCancellation()
                guard !finished, scene != .background, library.canContact(peer) else {
                    finish("Call waiting is no longer available.")
                    return
                }
                device = try await camera.start()
            } catch {
                if !Task.isCancelled { finish("Couldn't start the front camera.") }
                return
            }
        }
        guard !Task.isCancelled, !finished, scene != .background, library.canContact(peer) else {
            finish("Call waiting is no longer available.")
            return
        }
        phase = .waiting(device)
        do {
            try await Task.sleep(nanoseconds: 25_000_000_000)
            if case .waiting = phase { finish("The waiting window ended.") }
        } catch {
            camera.stop()
        }
    }

    private func finish(_ reason: String) {
        finished = true
        camera.stop()
        phase = .ended(reason)
    }

    private func close() {
        finished = true
        camera.stop()
        flow.back()
    }
}

private final class SkateCallCamera: ObservableObject {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "nina.call.front-camera", qos: .userInitiated)

    func start() async throws -> AVCaptureDevice {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let device = try self.configure()
                    self.session.startRunning()
                    guard self.session.isRunning else { throw NinaIssue("The camera did not start.") }
                    continuation.resume(returning: device)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func configure() throws -> AVCaptureDevice {
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera],
                                                          mediaType: .video, position: .front)
        guard let device = discovery.devices.first else { throw NinaIssue("There’s no front camera available.") }
        let input = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if session.canSetSessionPreset(.medium) { session.sessionPreset = .medium }
        for previous in session.inputs { session.removeInput(previous) }
        guard session.canAddInput(input) else { throw NinaIssue("The front camera is busy.") }
        session.addInput(input)
        return device
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
            self.session.beginConfiguration()
            for input in self.session.inputs { self.session.removeInput(input) }
            self.session.commitConfiguration()
        }
    }
}

private struct SkateFrontPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let device: AVCaptureDevice

    final class Surface: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        private var rotationCoordinator: NSObject?
        private var rotation: NSKeyValueObservation?

        func bind(to session: AVCaptureSession, device: AVCaptureDevice) {
            preview.session = session
            preview.videoGravity = .resizeAspectFill
            if #available(iOS 17, *) {
                let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: preview)
                rotationCoordinator = coordinator
                rotation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak self] _, update in
                    guard let angle = update.newValue else { return }
                    DispatchQueue.main.async {
                        guard let connection = self?.preview.connection, connection.isVideoRotationAngleSupported(angle) else { return }
                        connection.videoRotationAngle = angle
                    }
                }
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let connection = preview.connection else { return }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = true
            }
            if #unavailable(iOS 17), connection.isVideoOrientationSupported {
                switch window?.windowScene?.interfaceOrientation {
                case .landscapeLeft: connection.videoOrientation = .landscapeLeft
                case .landscapeRight: connection.videoOrientation = .landscapeRight
                case .portraitUpsideDown: connection.videoOrientation = .portraitUpsideDown
                default: connection.videoOrientation = .portrait
                }
            }
        }

        func unbind() {
            rotation?.invalidate()
            rotation = nil
            rotationCoordinator = nil
            preview.session = nil
        }
    }

    func makeUIView(context: Context) -> Surface {
        let view = Surface()
        view.backgroundColor = .black
        view.bind(to: session, device: device)
        return view
    }

    func updateUIView(_ view: Surface, context: Context) {}

    static func dismantleUIView(_ view: Surface, coordinator: Void) { view.unbind() }
}
