import SwiftUI
import PhotosUI

struct IdentityVerificationView: View {

    enum DocumentType: String, CaseIterable, Identifiable {
        case driversLicense = "運転免許証"
        case myNumberCard = "マイナンバーカード"

        var id: String { rawValue }

        var apiValue: String {
            switch self {
            case .driversLicense:
                return "drivers_license"
            case .myNumberCard:
                return "my_number_card"
            }
        }
    }

    @State private var documentType: DocumentType = .driversLicense
    @State private var selectedItem: PhotosPickerItem?
    @State private var imageData: Data?

    @State private var isSubmitting = false
    @State private var message: String?
    @State private var errorMessage: String?

    let api: NetworkClient
    let auth: AuthViewModel

    var body: some View {

        Form {

            Section("本人確認書類") {

                Picker("書類種類", selection: $documentType) {
                    ForEach(DocumentType.allCases) { type in
                        Text(type.rawValue)
                            .tag(type)
                    }
                }

                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images
                ) {
                    Label(
                        "本人確認書類を選択",
                        systemImage: "photo"
                    )
                }

                if let imageData,
                   let uiImage = UIImage(data: imageData) {

                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 250)
                }

                Button {

                    Task {
                        await submitKYC()
                    }

                } label: {

                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("提出する")
                    }
                }
                .disabled(
                    imageData == nil ||
                    isSubmitting
                )
            }

            if let message {

                Section {
                    Text(message)
                        .foregroundStyle(.green)
                }
            }

            if let errorMessage {

                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("本人確認")
        .task(id: selectedItem) {
            guard let selectedItem else {
                return
            }

            do {
                imageData = try await selectedItem.loadTransferable(
                    type: Data.self
                )
            } catch {
                errorMessage =
                    "画像を読み込めませんでした。"
            }
        }
    }

    private func submitKYC() async {

        guard let imageData else {
            return
        }

        isSubmitting = true
        errorMessage = nil
        message = nil

        defer {
            isSubmitting = false
        }

        do {

            let token = try await auth.accessToken()

            let boundary = UUID().uuidString

            var request = URLRequest(
                url: api.baseURL.appendingPathComponent(
                    "/api/kyc/submit"
                )
            )

            request.httpMethod = "POST"

            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )

            request.setValue(
                "multipart/form-data; boundary=\(boundary)",
                forHTTPHeaderField: "Content-Type"
            )

            request.httpBody = createMultipartBody(
                imageData: imageData,
                documentType: documentType.apiValue,
                boundary: boundary
            )

            let (_, response) = try await URLSession.shared.data(
                for: request
            )

            guard
                let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode)
            else {
                throw APIError.server(
                    status: 500,
                    message: "本人確認書類の提出に失敗しました。"
                )
            }

            message = "本人確認書類を提出しました。"

        } catch {

            errorMessage = error.localizedDescription
        }
    }

    private func createMultipartBody(
        imageData: Data,
        documentType: String,
        boundary: String
    ) -> Data {

        var body = Data()

        let lineBreak = "\r\n"

        body.append(
            "--\(boundary)\(lineBreak)"
                .data(using: .utf8)!
        )

        body.append(
            "Content-Disposition: form-data; name=\"documentType\"\(lineBreak)\(lineBreak)"
                .data(using: .utf8)!
        )

        body.append(
            "\(documentType)\(lineBreak)"
                .data(using: .utf8)!
        )

        body.append(
            "--\(boundary)\(lineBreak)"
                .data(using: .utf8)!
        )

        body.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"identity.jpg\"\(lineBreak)"
                .data(using: .utf8)!
        )

        body.append(
            "Content-Type: image/jpeg\(lineBreak)\(lineBreak)"
                .data(using: .utf8)!
        )

        body.append(imageData)

        body.append(
            lineBreak.data(using: .utf8)!
        )

        body.append(
            "--\(boundary)--\(lineBreak)"
                .data(using: .utf8)!
        )

        return body
    }
}
