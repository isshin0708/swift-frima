import Fluent
import Vapor

final class KYCSubmission: Model, Content, @unchecked Sendable {

    static let schema = "kyc_submissions"

    enum Status {
        static let pending = "pending"
        static let approved = "approved"
        static let rejected = "rejected"
    }

    @ID(key: .id)
    var id: UUID?

    @Field(key: "user_id")
    var userId: UUID

    @Field(key: "document_type")
    var documentType: String

    @Field(key: "document_path")
    var documentPath: String

    @Field(key: "status")
    var status: String

    init() {}

    init(
        id: UUID? = nil,
        userId: UUID,
        documentType: String,
        documentPath: String,
        status: String = Status.pending
    ) {
        self.id = id
        self.userId = userId
        self.documentType = documentType
        self.documentPath = documentPath
        self.status = status
    }
}
    