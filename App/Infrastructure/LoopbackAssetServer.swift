// SPDX-License-Identifier: Apache-2.0
import Foundation
import Network

/// Serves only the bundled EMA directory, bound to IPv4 loopback on an ephemeral port.
/// HTTP provides WebKit with standard ES module/WASM semantics without a remote server.
final class LoopbackAssetServer {
    private let root: URL
    private let token = UUID().uuidString
    private let queue = DispatchQueue(label: "net.ekatech.ema.assets")
    private var listener: NWListener?
    private var connections: [UUID: NWConnection] = [:]

    init(root: URL) { self.root = root.standardizedFileURL }

    func start() async throws -> URL {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        let listener = try NWListener(using: parameters)
        self.listener = listener
        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            listener.stateUpdateHandler = { [weak self] state in
                guard !resumed else { return }
                switch state {
                case .ready:
                    guard let self, let port = listener.port else { return }
                    resumed = true
                    continuation.resume(returning: URL(string: "http://127.0.0.1:\(port.rawValue)/\(self.token)/index.html")!)
                case .failed(let error):
                    resumed = true
                    continuation.resume(throwing: error)
                case .cancelled:
                    resumed = true
                    continuation.resume(throwing: CancellationError())
                default: break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { connection.cancel(); return }
                let id = UUID()
                self.connections[id] = connection
                connection.stateUpdateHandler = { [weak self] state in
                    if case .cancelled = state { self?.connections.removeValue(forKey: id) }
                }
                connection.start(queue: self.queue)
                self.receive(connection, accumulated: Data())
            }
            listener.start(queue: queue)
        }
    }

    private func receive(_ connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] bytes, _, complete, error in
            guard let self else { connection.cancel(); return }
            var request = accumulated
            request.append(bytes ?? Data())
            if request.count > 8192 || error != nil { connection.cancel(); return }
            if request.range(of: Data("\r\n\r\n".utf8)) != nil {
                self.respond(connection, request: request)
            } else if complete { connection.cancel() }
            else { self.receive(connection, accumulated: request) }
        }
    }

    private func respond(_ connection: NWConnection, request: Data) {
        let parts = String(decoding: request, as: UTF8.self).components(separatedBy: "\r\n")[0].split(separator: " ")
        guard parts.count == 3, parts[0] == "GET",
              let decoded = String(parts[1]).removingPercentEncoding,
              decoded.hasPrefix("/\(token)/"), !decoded.contains(".."), !decoded.contains("\\") else {
            send(connection, status: "403 Forbidden", type: "text/plain", body: Data())
            return
        }
        let relative = String(decoded.dropFirst(token.count + 2)).components(separatedBy: "?")[0]
        let file = root.appendingPathComponent(relative).standardizedFileURL
        guard file.path.hasPrefix(root.path + "/"),
              let body = try? Data(contentsOf: file, options: .mappedIfSafe) else {
            send(connection, status: "404 Not Found", type: "text/plain", body: Data())
            return
        }
        let types = ["html": "text/html", "js": "text/javascript", "mjs": "text/javascript",
                     "json": "application/json", "wasm": "application/wasm"]
        send(connection, status: "200 OK", type: types[file.pathExtension] ?? "application/octet-stream", body: body)
    }

    private func send(_ connection: NWConnection, status: String, type: String, body: Data) {
        let policy = "default-src 'none'; script-src 'self' 'wasm-unsafe-eval'; worker-src 'self'; connect-src 'self'"
        let headers = "HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nContent-Security-Policy: \(policy)\r\n\r\n"
        var response = Data(headers.utf8)
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
    }

    func stop() {
        queue.async { [self] in
            listener?.cancel()
            for connection in connections.values { connection.cancel() }
            connections.removeAll()
        }
    }
}
