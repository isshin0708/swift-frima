import Vapor

@main
struct AppMain {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        
        let app = try await Application.make(env)
        
        do {
            try await configure(app)
            try await app.execute()
        } catch {
            // エラーが発生した場合も非同期で安全にシャットダウン
            try await app.asyncShutdown()
            throw error
        }
        // 正常終了時の非同期シャットダウン
        try await app.asyncShutdown()
    }
}
