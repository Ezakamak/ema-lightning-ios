// SPDX-License-Identifier: Apache-2.0
import AVFoundation
import JavaScriptCore

enum MediaExportError: LocalizedError {
    case failed(String)
    var errorDescription: String? { if case .failed(let message) = self { return message }; return nil }
}

/// A separately bundled, replaceable LGPL-3.0 JavaScript library; no remote scripts.
enum MP3Encoder {
    static func encode(source: URL, destination: URL, library: URL) throws {
        let audio = try AVAudioFile(forReading: source, commonFormat: .pcmFormatInt16, interleaved: false)
        guard audio.processingFormat.channelCount == 1,
              let buffer = AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: 1152),
              let context = JSContext() else { throw MediaExportError.failed("MP3 için mono PCM ses açılamadı.") }
        var exception: String?
        context.exceptionHandler = { _, value in exception = value?.toString() ?? "JavaScript hatası" }
        context.evaluateScript(try String(contentsOf: library, encoding: .utf8))
        guard exception == nil else { throw MediaExportError.failed("MP3 kodlayıcı yüklenemedi: \(exception!)") }
        context.evaluateScript("var encoder = new lamejs.Mp3Encoder(1, \(Int(audio.processingFormat.sampleRate)), 128); function encodeChunk(a) { return Array.prototype.slice.call(encoder.encodeBuffer(new Int16Array(a))); } function flushMP3() { return Array.prototype.slice.call(encoder.flush()); }")
        guard exception == nil else { throw MediaExportError.failed("MP3 kodlayıcı başlatılamadı: \(exception!)") }
        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else { throw MediaExportError.failed("MP3 dosyası oluşturulamadı.") }
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }
        func write(_ value: JSValue?) throws {
            if let exception { throw MediaExportError.failed("MP3 kodlama hatası: \(exception)") }
            guard let bytes = value?.toArray() as? [NSNumber] else { throw MediaExportError.failed("MP3 kodlayıcı geçersiz veri döndürdü.") }
            try output.write(contentsOf: Data(bytes.map { UInt8(truncating: $0) }))
        }
        while audio.framePosition < audio.length {
            try Task.checkCancellation()
            try audio.read(into: buffer, frameCount: 1152)
            guard let samples = buffer.int16ChannelData?[0], buffer.frameLength > 0 else { break }
            let input = Array(UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength)))
            try autoreleasepool { try write(context.objectForKeyedSubscript("encodeChunk")?.call(withArguments: [input])) }
        }
        try write(context.objectForKeyedSubscript("flushMP3")?.call(withArguments: []))
        try output.synchronize()
        let result = try AVAudioPlayer(contentsOf: destination)
        let expected = Double(audio.length) / audio.processingFormat.sampleRate
        guard result.duration > 0, abs(result.duration - expected) < 1 else { throw MediaExportError.failed("Üretilen MP3 ses süresi doğrulanamadı.") }
    }
}
