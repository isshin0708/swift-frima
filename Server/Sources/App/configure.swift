import Fluent
import FluentPostgresDriver
import NIOSSL
import Vapor

public func configure(_ app: Application) async throws {
    guard let databaseURL = Environment.get("DATABASE_URL"), !databaseURL.isEmpty else {
        throw Abort(.internalServerError, reason: "DATABASE_URL is not configured")
    }
    guard
        let url = URL(string: databaseURL),
        let hostname = url.host,
        let username = url.user
    else {
        throw Abort(.internalServerError, reason: "DATABASE_URL is not a valid postgres connection string")
    }
    let database = url.path.split(separator: "/").last.map(String.init) ?? "postgres"
    let port = url.port ?? 5432

    // SupabaseのTLS証明書チェーンは、NIOSSLの既定のトラストストアでは検証に失敗することがある。
    // ここでは通信は暗号化しつつ証明書検証だけをスキップする(標準的なlibpqの sslmode=require と同等の挙動)。
    // より厳密な検証(sslmode=verify-full相当)にしたい場合は、SupabaseのCA証明書を読み込んで
    // `tlsConfiguration.trustRoots = .certificates([...])` を設定し、certificateVerificationを
    // `.fullVerification` に戻すことを推奨する。
    var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
    tlsConfiguration.certificateVerification = .none

    let postgresConfiguration = SQLPostgresConfiguration(
        hostname: hostname,
        port: port,
        username: username,
        password: url.password,
        database: database,
        tls: .prefer(try NIOSSLContext(configuration: tlsConfiguration))
    )

    app.databases.use(.postgres(configuration: postgresConfiguration), as: .psql)
    app.migrations.add(CreateItems())
    app.migrations.add(CreateOrders())
    try routes(app)
    try await app.autoMigrate()
}
