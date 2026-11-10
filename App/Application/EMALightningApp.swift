// SPDX-License-Identifier: Apache-2.0
import SwiftUI

@main
@MainActor
struct EMALightningApp: App {
    @StateObject private var model = SpeechViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            SpeechView(model: model)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { model.stop() }
                }
        }
    }
}
