// SPDX-License-Identifier: Apache-2.0
import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    @Published var developerMode: Bool { didSet { defaults.set(developerMode, forKey: "developerMode") } }
    @Published var appearance: Int { didSet { defaults.set(appearance, forKey: "appearance") } }
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        developerMode = defaults.bool(forKey: "developerMode")
        appearance = defaults.integer(forKey: "appearance")
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ema-ui-worker-error") { developerMode = true }
        if ProcessInfo.processInfo.arguments.contains("--uitest-clean") { developerMode = false }
        #endif
    }
}
