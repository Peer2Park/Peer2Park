// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation

public struct APIError: Error, LocalizedError {
    public let message: String
    public var errorDescription: String? { message }
}

public final class APIClient {
    private let session: URLSession
    private let baseURL: URL

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    @available(iOS 15.0, *)
    public func get(path: String) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError(message: "Bad status")
        }
        return data
    }

    // convenience
    @available(iOS 15.0, *)
    public func health() async throws -> String {
        let data = try await get(path: "health")
        return String(decoding: data, as: UTF8.self)
    }
}
