// SPDX-License-Identifier: Apache-2.0
import AVFoundation
import UIKit
import SpeechCore

enum CaptionVideoExporter {
    private static let width = 720
    private static let height = 1280
    private static let fps: Int32 = 12

    static func export(recording: SpeechRecording, audioURL: URL, destination: URL, logoURL: URL?, progress: @escaping @Sendable (Double) -> Void) async throws {
        try Task.checkCancellation()
        let silentURL = destination.deletingLastPathComponent().appendingPathComponent("frames.mp4")
        defer { try? FileManager.default.removeItem(at: silentURL) }
        let audioAsset = AVURLAsset(url: audioURL)
        let duration = try await audioAsset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite, seconds > 0, seconds <= 181 else { throw MediaExportError.failed("Video için ses süresi geçersiz.") }
        let cues = CaptionTimeline.cues(text: recording.text, duration: seconds)
        let logo = logoURL.flatMap { UIImage(contentsOfFile: $0.path) }
        let writer = try AVAssetWriter(outputURL: silentURL, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 1_800_000, AVVideoMaxKeyFrameIntervalKey: 24]
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ])
        guard writer.canAdd(input) else { throw MediaExportError.failed("H.264 video kodlayıcı kullanılamıyor.") }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? MediaExportError.failed("Video başlatılamadı.") }
        writer.startSession(atSourceTime: .zero)
        do {
            try await withTaskCancellationHandler {
                let frames = max(1, Int(ceil(seconds * Double(fps))))
                for frame in 0..<frames {
                    try Task.checkCancellation()
                    let deadline = Date().addingTimeInterval(15)
                    while !input.isReadyForMoreMediaData {
                        try Task.checkCancellation()
                        guard writer.status == .writing, Date() < deadline else {
                            throw writer.error ?? MediaExportError.failed("Video kodlayıcı 15 saniye boyunca yanıt vermedi.")
                        }
                        try await Task.sleep(for: .milliseconds(5))
                    }
                    let time = min(seconds, Double(frame) / Double(fps))
                    let cue = cues.first { time >= $0.start && time < $0.end } ?? cues.last
                    try autoreleasepool {
                        guard let pool = adaptor.pixelBufferPool else { throw MediaExportError.failed("Video kare havuzu hazırlanamadı.") }
                        var pixel: CVPixelBuffer?
                        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixel) == kCVReturnSuccess, let pixel else {
                            throw MediaExportError.failed("Video karesi için bellek ayrılamadı.")
                        }
                        try draw(pixel: pixel, cue: cue, time: time, duration: seconds, logo: logo)
                        guard adaptor.append(pixel, withPresentationTime: CMTime(value: Int64(frame), timescale: fps)) else {
                            throw writer.error ?? MediaExportError.failed("Video karesi yazılamadı.")
                        }
                    }
                    progress(Double(frame + 1) / Double(frames) * 0.85)
                }
                input.markAsFinished()
                await writer.finishWriting()
                try Task.checkCancellation()
                guard writer.status == .completed else { throw writer.error ?? MediaExportError.failed("Video tamamlanamadı.") }
            } onCancel: { writer.cancelWriting() }
            let composition = AVMutableComposition()
            let videoAsset = AVURLAsset(url: silentURL)
            guard let videoTrack = try await videoAsset.loadTracks(withMediaType: .video).first,
                  let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first,
                  let targetVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                  let targetAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                throw MediaExportError.failed("Video ve ses kanalları birleştirilemedi.")
            }
            try targetVideo.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: videoTrack, at: .zero)
            try targetAudio.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: audioTrack, at: .zero)
            guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality),
                  session.supportedFileTypes.contains(.mp4) else { throw MediaExportError.failed("MP4 dışa aktarımı desteklenmiyor.") }
            session.outputURL = destination; session.outputFileType = .mp4; session.shouldOptimizeForNetworkUse = true
            try await withTaskCancellationHandler {
                await session.export()
                try Task.checkCancellation()
                guard session.status == .completed else { throw session.error ?? MediaExportError.failed("MP4 dışa aktarımı tamamlanamadı.") }
            } onCancel: { session.cancelExport() }
            let final = AVURLAsset(url: destination)
            let videoTracks = try await final.loadTracks(withMediaType: .video)
            let audioTracks = try await final.loadTracks(withMediaType: .audio)
            guard !videoTracks.isEmpty, !audioTracks.isEmpty else { throw MediaExportError.failed("MP4 içinde ses veya video kanalı eksik.") }
            progress(1)
        } catch { writer.cancelWriting(); try? FileManager.default.removeItem(at: destination); throw error }
    }

    private static func draw(pixel: CVPixelBuffer, cue: CaptionCue?, time: Double, duration: Double, logo: UIImage?) throws {
        CVPixelBufferLockBaseAddress(pixel, [])
        defer { CVPixelBufferUnlockBaseAddress(pixel, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(pixel), width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixel), space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { throw MediaExportError.failed("Video çizim alanı oluşturulamadı.") }
        context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(context); defer { UIGraphicsPopContext() }
        let bounds = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        UIColor(red: 0.055, green: 0.06, blue: 0.08, alpha: 1).setFill(); context.fill(bounds)
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor(red: 0.42, green: 0.035, blue: 0.08, alpha: 1).cgColor, UIColor(red: 0.055, green: 0.06, blue: 0.08, alpha: 1).cgColor] as CFArray, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: CGFloat(width), y: CGFloat(height)), options: [])
        }
        let icon = CGRect(x: 56, y: 100, width: 92, height: 92)
        context.saveGState(); UIBezierPath(roundedRect: icon, cornerRadius: 23).addClip(); logo?.draw(in: icon); context.restoreGState()
        text("EMA Lightning", rect: CGRect(x: 168, y: 112, width: 500, height: 45), size: 30, weight: .semibold, color: .white)
        text("Türkçe, senin sesinle.", rect: CGRect(x: 168, y: 157, width: 500, height: 36), size: 21, weight: .regular, color: UIColor.white.withAlphaComponent(0.55))
        let phrase = cue?.text ?? ""
        let rect = CGRect(x: 56, y: 360, width: 608, height: 540)
        let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 12; paragraph.lineBreakMode = .byCharWrapping
        var size: CGFloat = 58
        var attributes: [NSAttributedString.Key: Any] = [:]
        var measured: CGRect = .zero
        repeat {
            attributes = [.font: UIFont.systemFont(ofSize: size, weight: .bold), .foregroundColor: UIColor.white, .paragraphStyle: paragraph]
            measured = (phrase as NSString).boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
            if measured.height <= rect.height { break }; size -= 2
        } while size >= 18
        (phrase as NSString).draw(with: CGRect(x: rect.minX, y: rect.midY - measured.height / 2, width: rect.width, height: measured.height + 10), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
        text("METİNDEN SESE", rect: CGRect(x: 56, y: 292, width: 608, height: 34), size: 18, weight: .semibold, color: UIColor.white.withAlphaComponent(0.45))
        let bar = CGRect(x: 56, y: 1056, width: 608, height: 6)
        UIColor.white.withAlphaComponent(0.15).setFill(); UIBezierPath(roundedRect: bar, cornerRadius: 3).fill()
        UIColor.systemRed.setFill(); UIBezierPath(roundedRect: CGRect(x: bar.minX, y: bar.minY, width: bar.width * CGFloat(time / duration), height: 6), cornerRadius: 3).fill()
        text(String(format: "%d:%02d / %d:%02d", Int(time) / 60, Int(time) % 60, Int(duration) / 60, Int(duration) % 60), rect: CGRect(x: 56, y: 1086, width: 608, height: 36), size: 21, weight: .medium, color: UIColor.white.withAlphaComponent(0.6))
        text("EMA ile oluşturuldu", rect: CGRect(x: 56, y: 1170, width: 608, height: 40), size: 22, weight: .medium, color: UIColor.white.withAlphaComponent(0.35))
    }
    private static func text(_ value: String, rect: CGRect, size: CGFloat, weight: UIFont.Weight, color: UIColor) {
        (value as NSString).draw(in: rect, withAttributes: [.font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
    }
}
