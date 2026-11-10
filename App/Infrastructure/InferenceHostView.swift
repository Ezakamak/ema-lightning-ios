// SPDX-License-Identifier: Apache-2.0
import UIKit
import SwiftUI

/// A real, on-screen viewport. Never place the WKWebView in a 1×1 background.
final class InferenceHostView: UIView {
    let engine: EMASpeechEngine
    init(engine: EMASpeechEngine) {
        self.engine = engine
        super.init(frame: .zero)
        addSubview(engine.webView)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func layoutSubviews() {
        super.layoutSubviews()
        engine.webView.frame = bounds
        engine.hostDidChange()
    }
    override func didMoveToWindow() { super.didMoveToWindow(); engine.hostDidChange() }
}

struct InferenceViewport: UIViewRepresentable {
    let engine: EMASpeechEngine
    func makeUIView(context: Context) -> InferenceHostView { InferenceHostView(engine: engine) }
    func updateUIView(_ view: InferenceHostView, context: Context) { view.setNeedsLayout() }
}
