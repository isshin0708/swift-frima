import Fluent
import FluentSQL

struct CreateOrders: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("orders")
            .id()
            .field("item_id", .uuid, .required, .references("items", "id"))
            .field("buyer_id", .uuid, .required)
            .field("price", .sql(unsafeRaw: "NUMERIC(12,2)"), .required)
            .field("status", .string, .required)
            .field("payment_intent_id", .string)
            .field("paid_at", .datetime)
            .field("created_at", .datetime)
            .unique(on: "item_id", "status")
            .unique(on: "payment_intent_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("orders").delete()
    }
}
