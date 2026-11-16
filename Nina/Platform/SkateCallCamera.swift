import AVFoundation
import Foundation

final class SkateCallCamera {
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
