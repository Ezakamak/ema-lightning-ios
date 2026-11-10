// SPDX-License-Identifier: Apache-2.0
import SwiftUI

enum StudioStyle {
    static let accent = Color(red: 0.88, green: 0.08, blue: 0.16)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let logoURL = Bundle.main.url(forResource: "Logo-original", withExtension: "jpg", subdirectory: "Brand")
}
@MainActor
struct BrandLogo: View {
    var size: CGFloat = 48
    var body: some View {
        Group {
            if let url = StudioStyle.logoURL, let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else { Image(systemName: "waveform").resizable().scaledToFit().padding(10).foregroundStyle(.white).background(StudioStyle.accent) }
        }.frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)).accessibilityHidden(true)
    }
}
@MainActor
struct RecordingRow: View {
    let recording: SpeechRecording
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "waveform").font(.title3).foregroundStyle(StudioStyle.accent)
                .frame(width: 46, height: 46).background(StudioStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 5) {
                Text(recording.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                Text(recording.createdAt, format: .dateTime.day().month(.abbreviated).hour().minute()).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            Text(recording.durationLabel).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
        }.padding(.vertical, 6).contentShape(Rectangle())
    }
}
@MainActor
struct StudioEmptyState: View {
    let title: String
    let message: String
    let symbol: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 38, weight: .light)).foregroundStyle(StudioStyle.accent)
                .frame(width: 84, height: 84).background(StudioStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 28))
            Text(title).font(.title3.weight(.semibold))
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 300)
        }.padding(32).frame(maxWidth: .infinity)
    }
}
@MainActor
struct ExportProgressView: View {
    @ObservedObject var exporter: ExportCoordinator
    var body: some View {
        if exporter.isExporting {
            HStack(spacing: 14) {
                if let progress = exporter.progress { ProgressView(value: progress).frame(width: 40) }
                else { ProgressView() }
                Text(exporter.label).font(.subheadline.weight(.medium))
                Spacer()
                Button("İptal", action: exporter.cancel).font(.subheadline.weight(.semibold)).buttonStyle(.borderless)
            }.padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)).padding(.horizontal).accessibilityIdentifier("exportProgress")
        }
    }
}
