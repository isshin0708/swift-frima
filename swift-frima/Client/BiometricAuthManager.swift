import Foundation
import LocalAuthentication
import Observation

@MainActor
@Observable
public final class BiometricAuthManager {
    public private(set) var isUnlocked = false
    public private(set) var errorMessage: String?

    public init() {}

    public var biometryType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    @discardableResult
    public func authenticate(reason: String) async -> Bool {
        errorMessage = nil
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            errorMessage = message(for: error)
            isUnlocked = false
            return false
        }
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            isUnlocked = success
            if !success { errorMessage = "Face ID認証に失敗しました。" }
            return success
        } catch {
            isUnlocked = false
            errorMessage = message(for: error as NSError)
            return false
        }
    }

    private func message(for error: NSError?) -> String {
        guard let error, let code = LAError.Code(rawValue: error.code) else {
            return error?.localizedDescription ?? "Face IDを利用できません。"
        }
        switch code {
        case .biometryNotEnrolled: return "Face IDが登録されていません。設定からFace IDを登録してください。"
        case .biometryNotAvailable: return "この端末ではFace IDを利用できません。"
        case .biometryLockout: return "Face IDがロックされています。端末のパスコードで解除してから再試行してください。"
        case .userCancel, .appCancel, .systemCancel: return "Face ID認証がキャンセルされました。"
        default: return error.localizedDescription
        }
    }
}
