// Copyright (c) 2026 Jhey
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import ScreenCaptureKit

final class DesktopCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private var cancelled = false
    private var configuration: SCStreamConfiguration?
    private var requestedFPS: Int32 = 60
    private var appliedFPS: Int32 = 60
    private var reconfiguring = false
    // Called by the main-run-loop motion timer; SCStream callbacks use .main too.
    func setActive(_ value: Bool, framesPerSecond: Int = 60) {
        requestedFPS = value ? Int32(min(120, max(30, framesPerSecond))) : 5
        guard !reconfiguring, requestedFPS != appliedFPS,
              let stream, let configuration else { return }
        reconfiguring = true
        Task { @MainActor in
            defer { reconfiguring = false }
            // Do not lose a rapid open/close request while an update is awaiting.
            while !cancelled, self.stream === stream, requestedFPS != appliedFPS {
                let fps = requestedFPS
                configuration.minimumFrameInterval = CMTime(value: 1, timescale: fps)
                do { try await stream.updateConfiguration(configuration); appliedFPS = fps }
                catch { if !cancelled { onError?(error) }; break }
            }
        }
    }
    var onFrame: ((CVPixelBuffer) -> Void)?
    var onError: ((Error) -> Void)?
    private(set) var frames = 0

    @MainActor
    func start(displayID: CGDirectDisplayID, framesPerSecond: Int = 60) async throws {
        // The menu bar app's overlay is hidden at rest. Include offscreen windows
        // when discovering the app that must be excluded from the display stream.
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        // A clamshell/display transition can cancel us while discovery is awaiting.
        guard !cancelled else { throw CancellationError() }
        guard let display = content.displays.first(where: { $0.displayID == displayID }),
              let ownApp = content.applications.first(where: { $0.processID == ProcessInfo.processInfo.processIdentifier }) else {
            throw NSError(domain: "LidPlane", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find this display or exclude the overlay from capture."])
        }
        let filter = SCContentFilter(display: display, excludingApplications: [ownApp], exceptingWindows: [])
        let config = SCStreamConfiguration()
        // Capture the backing pixels, not the logical display dimensions.
        // Scaled Retina modes can report logical pixels through CGDisplayPixelsWide.
        let mode = CGDisplayCopyDisplayMode(displayID)
        let width = mode?.pixelWidth ?? CGDisplayPixelsWide(displayID)
        let height = mode?.pixelHeight ?? CGDisplayPixelsHigh(displayID)
        config.width = max(2, width)
        config.height = max(2, height)
        // Begin at full cadence; the first opening frames must not arrive at 5 Hz.
        requestedFPS = Int32(min(120, max(30, framesPerSecond)))
        appliedFPS = requestedFPS
        config.minimumFrameInterval = CMTime(value: 1, timescale: requestedFPS)
        self.configuration = config
        config.queueDepth = 3
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.capturesAudio = false
        config.colorSpaceName = CGColorSpace.sRGB
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
        self.stream = stream
        try await stream.startCapture()
        if cancelled {
            // stop() may have run while startCapture() was still in flight.
            try? await stream.stopCapture()
            throw CancellationError()
        }
        NSLog("Desktop capture started, %d x %d; own app excluded", config.width, config.height)
    }

    @MainActor
    func stop() async {
        cancelled = true
        let current = stream
        stream = nil
        try? await current?.stopCapture()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard self.stream === stream, type == .screen, sampleBuffer.isValid,
              let metadata = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let status = metadata.first?[.status] as? Int, status == SCFrameStatus.complete.rawValue,
              let pixelBuffer = sampleBuffer.imageBuffer else { return }
        frames += 1
        if frames == 1 { NSLog("Desktop capture received first complete frame") }
        onFrame?(pixelBuffer)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard self?.stream === stream else { return }
            self?.onError?(error)
        }
    }
}
