// SPDX-License-Identifier: Apache-2.0
import SwiftUI

#if DEBUG
private struct LegacyFormButtonProbe: View {
    @State private var read = 0
    @State private var stop = 0
    var body: some View {
        Form {
            HStack {
                Button("Oku") { read += 1 }.accessibilityIdentifier("legacyRead")
                Spacer()
                Button("Durdur") { stop += 1 }.accessibilityIdentifier("legacyStop")
            }
            Text("read \(read)").accessibilityIdentifier("legacyReadCount")
            Text("stop \(stop)").accessibilityIdentifier("legacyStopCount")
        }
    }
}
#endif

@main
@MainActor
struct EMALightningApp: App {
    @StateObject private var model: SpeechViewModel
    @Environment(\.scenePhase) private var scenePhase
    init() {
        #if DEBUG
        let fault: EMATestFault = ProcessInfo.processInfo.arguments.contains("--ema-ui-worker-error") ? .thrownWorker : .none
        _model = StateObject(wrappedValue: SpeechViewModel(fault: fault))
        #else
        _model = StateObject(wrappedValue: SpeechViewModel())
        #endif
    }
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--legacy-form-buttons") { LegacyFormButtonProbe() }
            else { screen }
            #else
            screen
            #endif
        }
    }
    private var screen: some View {
        StudioRootView(model: model).task { await model.pronunciations.sync.check() }.onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.pronunciations.sync.check() } }
            if phase == .background { model.stop() }
        }
    }
}
