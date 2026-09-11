import Fluent
import FluentSQL

struct CreateItems: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("items")
            .id()
            .field("user_id", .uuid, .required)
            .field("name", .string, .required)
            .field("description", .string, .required)
            .field("price", .sql(raw: "NUMERIC(12,2)"), .required)
            .field("manufacturer_suggested_retail_price", .sql(raw: "NUMERIC(12,2)"))
            .field("reference_price", .sql(raw: "NUMERIC(12,2)"))
            .field("category_id", .int, .required)
            .field("status", .string, .required)
            .field("image_url", .string)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("items").delete()
    }
}
