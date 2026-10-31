import Foundation
import Network
import UniformTypeIdentifiers
import CarLinkCore

/// An ephemeral loopback-only endpoint for the selected local file. Supports
/// AVPlayer's byte-range requests without loading a whole movie into memory.
/// CarPlay handoff of this endpoint remains dependent on the iOS media proxy.
final class LocalMediaServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.carlink.local-media")
    private var listener: NWListener?
    private var connections: [UUID: NWConnection] = [:]

    func start(file: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.stopOnQueue()
                do {
                    let parameters = NWParameters.tcp
                    parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
                    let listener = try NWListener(using: parameters)
                    let token = "/" + UUID().uuidString + "." + file.pathExtension
                    var completed = false
                    listener.stateUpdateHandler = { state in
                        switch state {
                        case .ready:
                            guard !completed, let port = listener.port,
                                  let url = URL(string: "http://127.0.0.1:\(port.rawValue)\(token)") else { return }
                            completed = true
                            listener.stateUpdateHandler = nil
                            continuation.resume(returning: url)
                        case .failed(let error):
                            guard !completed else { return }
                            completed = true
                            listener.stateUpdateHandler = nil
                            listener.cancel()
                            continuation.resume(throwing: error)
                        case .cancelled:
                            guard !completed else { return }
                            completed = true
                            listener.stateUpdateHandler = nil
                            continuation.resume(throwing: CancellationError())
                        default: break
                        }
                    }
                    listener.newConnectionHandler = { [weak self] connection in
                        guard let self, self.connections.count < 4 else { connection.cancel(); return }
                        let id = UUID()
                        self.connections[id] = connection
                        connection.stateUpdateHandler = { [weak self, weak connection] state in
                            if case .cancelled = state { self?.connections[id] = nil }
                            if case .failed = state { self?.connections[id] = nil; connection?.cancel() }
                        }
                        connection.start(queue: self.queue)
                        self.readRequest(connection, file: file, token: token, accumulated: Data())
                    }
                    self.listener = listener
                    listener.start(queue: self.queue)
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    func stop() { queue.async { self.stopOnQueue() } }

    private func stopOnQueue() {
        listener?.cancel()
        listener = nil
        let active = Array(connections.values)
        connections.removeAll()
        active.forEach { $0.cancel() }
    }

    private func readRequest(_ connection: NWConnection, file: URL, token: String, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8_192) { [weak self] data, _, done, error in
            guard let self else { connection.cancel(); return }
            var request = accumulated
            if let data { request.append(data) }
            guard request.count <= 16_384 else { self.reply(connection, status: "431 Request Header Fields Too Large"); return }
            if let text = String(data: request, encoding: .utf8), text.contains("\r\n\r\n") {
                self.serve(connection, request: text, file: file, token: token)
            } else if done || error != nil { connection.cancel() }
            else { self.readRequest(connection, file: file, token: token, accumulated: request) }
        }
    }

    private func serve(_ connection: NWConnection, request: String, file: URL, token: String) {
        let lines = request.components(separatedBy: "\r\n")
        let first = (lines.first ?? "").split(separator: " ")
        guard first.count == 3 else { reply(connection, status: "400 Bad Request"); return }
        guard first[0] == "GET" || first[0] == "HEAD" else { reply(connection, status: "405 Method Not Allowed"); return }
        guard first[1] == Substring(token) else { reply(connection, status: "404 Not Found"); return }
        do {
            let values = try file.resourceValues(forKeys: [.fileSizeKey])
            let size = UInt64(values.fileSize ?? 0)
            let rangeHeader = lines.first(where: { $0.lowercased().hasPrefix("range:") })?
                .dropFirst(6).trimmingCharacters(in: .whitespaces)
            let range = rangeHeader.flatMap { HTTPByteRange.parse($0, size: size) }
            if rangeHeader != nil && range == nil {
                reply(connection, status: "416 Range Not Satisfiable", extra: "Content-Range: bytes */\(size)\r\n")
                return
            }
            let start = range?.start ?? 0
            let count = range?.count ?? size
            let mime = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            var headers = "HTTP/1.1 \(range == nil ? "200 OK" : "206 Partial Content")\r\nContent-Type: \(mime)\r\nContent-Length: \(count)\r\nAccept-Ranges: bytes\r\nCache-Control: no-store\r\nConnection: close\r\n"
            if let range { headers += "Content-Range: bytes \(range.start)-\(range.end)/\(size)\r\n" }
            headers += "\r\n"
            if first[0] == "HEAD" || count == 0 {
                connection.send(content: Data(headers.utf8), completion: .contentProcessed { _ in connection.cancel() })
                return
            }
            let handle = try FileHandle(forReadingFrom: file)
            try handle.seek(toOffset: start)
            connection.send(content: Data(headers.utf8), completion: .contentProcessed { [weak self] error in
                guard error == nil, let self else { try? handle.close(); connection.cancel(); return }
                self.sendFile(connection, handle: handle, remaining: count)
            })
        } catch { reply(connection, status: "500 Internal Server Error") }
    }

    private func sendFile(_ connection: NWConnection, handle: FileHandle, remaining: UInt64) {
        guard remaining > 0 else { try? handle.close(); connection.cancel(); return }
        do {
            guard let chunk = try handle.read(upToCount: Int(min(remaining, 262_144))), !chunk.isEmpty else {
                try? handle.close(); connection.cancel(); return
            }
            connection.send(content: chunk, completion: .contentProcessed { [weak self] error in
                guard error == nil, let self else { try? handle.close(); connection.cancel(); return }
                self.sendFile(connection, handle: handle, remaining: remaining - UInt64(chunk.count))
            })
        } catch { try? handle.close(); connection.cancel() }
    }

    private func reply(_ connection: NWConnection, status: String, extra: String = "") {
        let response = "HTTP/1.1 \(status)\r\n\(extra)Content-Length: 0\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
    }
}
