import Foundation

public enum APIError: LocalizedError, Sendable {
    case invalidURL
    case unauthorized
    case server(status: Int, message: String?)
    case decoding
    case network(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "URLが不正です。"
        case .unauthorized: return "ログインが必要です。"
        case .server(let status, let message): return message ?? "サーバーエラーです。(HTTP \(status))"
        case .decoding: return "サーバーの応答を解析できませんでした。"
        case .network(let message): return "通信エラー: \(message)"
        case .cancelled: return "通信がキャンセルされました。"
        }
    }
}

public struct NetworkClient: Sendable {
    public let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = [], authToken: String? = nil) async throws -> T {
        let request = try makeRequest(path: path, method: "GET", queryItems: queryItems, authToken: authToken)
        return try await send(request)
    }

    public func post<Body: Encodable, T: Decodable>(_ path: String, body: Body, authToken: String? = nil) async throws -> T {
        var request = try makeRequest(path: path, method: "POST", queryItems: [], authToken: authToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.iso8601.encode(body)
        return try await send(request)
    }

    public func postNoContent<Body: Encodable>(_ path: String, body: Body, authToken: String? = nil) async throws {
        var request = try makeRequest(path: path, method: "POST", queryItems: [], authToken: authToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.iso8601.encode(body)
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.network("不正なHTTPレスポンス") }
            guard (200..<300).contains(http.statusCode) else {
                if http.statusCode == 401 { throw APIError.unauthorized }
                let message = (try? JSONDecoder().decode(ServerErrorPayload.self, from: data))?.reason
                throw APIError.server(status: http.statusCode, message: message)
            }
        } catch is CancellationError {
            throw APIError.cancelled
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    private func makeRequest(path: String, method: String, queryItems: [URLQueryItem], authToken: String?) throws -> URLRequest {
        let normalized = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard var components = URLComponents(url: baseURL.appendingPathComponent(normalized), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let authToken { request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization") }
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.network("不正なHTTPレスポンス") }
            guard (200..<300).contains(http.statusCode) else {
                if http.statusCode == 401 { throw APIError.unauthorized }
                let message = (try? JSONDecoder().decode(ServerErrorPayload.self, from: data))?.reason
                throw APIError.server(status: http.statusCode, message: message)
            }
            do { return try JSONDecoder.iso8601.decode(T.self, from: data) }
            catch { throw APIError.decoding }
        } catch is CancellationError { throw APIError.cancelled }
        catch let error as APIError { throw error }
        catch { throw APIError.network(error.localizedDescription) }
    }
}

private struct ServerErrorPayload: Decodable { let error: String?; let reason: String? }

extension JSONDecoder {
    static let iso8601: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()
}
extension JSONEncoder {
    static let iso8601: JSONEncoder = { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }()
}
