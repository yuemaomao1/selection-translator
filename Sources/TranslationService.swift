import AppKit
import Foundation
import NaturalLanguage
import SwiftUI

#if canImport(Translation)
import Translation
#endif

protocol TranslationService {
    func translate(text: String) async throws -> String
}

enum TranslationDirection {
    case englishToChinese
    case chineseToEnglish

    var sourceLanguage: Locale.Language {
        switch self {
        case .englishToChinese:
            return Locale.Language(identifier: "en")
        case .chineseToEnglish:
            return Locale.Language(identifier: "zh-Hans")
        }
    }

    var targetLanguage: Locale.Language {
        switch self {
        case .englishToChinese:
            return Locale.Language(identifier: "zh-Hans")
        case .chineseToEnglish:
            return Locale.Language(identifier: "en")
        }
    }
}

enum AppTranslationError: LocalizedError {
    case unsupportedSystem
    case unsupportedLanguage
    case emptyText
    case bridgeUnavailable
    case requestCancelled
    case notImplemented

    var errorDescription: String? {
        switch self {
        case .unsupportedSystem:
            return "当前系统低于 macOS 15，暂不能使用系统翻译框架"
        case .unsupportedLanguage:
            return "V1 仅处理中文和英文互译"
        case .emptyText:
            return "没有可翻译的文本"
        case .bridgeUnavailable:
            return "系统翻译桥接初始化失败"
        case .requestCancelled:
            return "上一条翻译请求已取消"
        case .notImplemented:
            return "翻译服务尚未接入"
        }
    }
}

@MainActor
final class SystemTranslationService: TranslationService {
    private var bridgeContext: AnyObject?

    init() {
        if #available(macOS 15.0, *) {
            bridgeContext = TranslationBridgeContext()
        }
    }

    func translate(text: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AppTranslationError.emptyText
        }

        guard let direction = detectDirection(for: trimmed) else {
            throw AppTranslationError.unsupportedLanguage
        }

        guard #available(macOS 15.0, *) else {
            throw AppTranslationError.unsupportedSystem
        }

        guard let bridgeContext = bridgeContext as? TranslationBridgeContext else {
            throw AppTranslationError.bridgeUnavailable
        }

        return try await bridgeContext.model.translate(
            text: trimmed,
            source: direction.sourceLanguage,
            target: direction.targetLanguage
        )
    }

    private func detectDirection(for text: String) -> TranslationDirection? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let language = recognizer.dominantLanguage else {
            return nil
        }

        switch language {
        case .english:
            return .englishToChinese
        case .simplifiedChinese, .traditionalChinese:
            return .chineseToEnglish
        default:
            return nil
        }
    }

}

@available(macOS 15.0, *)
@MainActor
final class TranslationBridgeContext: NSObject {
    let model = TranslationBridgeModel()
    let window: NSWindow

    override init() {
        let rootView = TranslationBridgeView(model: model)
        let controller = NSHostingController(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: -10_000, y: -10_000, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        window.level = .normal
        window.isOpaque = false
        window.backgroundColor = .clear
        window.alphaValue = 0.001
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.orderFront(nil)

        self.window = window
        super.init()
    }
}

@available(macOS 15.0, *)
@MainActor
final class TranslationBridgeModel: ObservableObject {
    @Published var configuration: TranslationSession.Configuration?

    private var pendingRequest: PendingRequest?

    func translate(text: String, source: Locale.Language, target: Locale.Language) async throws -> String {
        if let pendingRequest {
            pendingRequest.continuation.resume(throwing: AppTranslationError.requestCancelled)
            self.pendingRequest = nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            pendingRequest = PendingRequest(
                text: text,
                continuation: continuation
            )
            configuration = TranslationSession.Configuration(source: source, target: target)
        }
    }

    func performTranslation(using session: TranslationSession) async {
        guard let request = pendingRequest else { return }

        do {
            try await session.prepareTranslation()
            let response = try await session.translate(request.text)
            complete(with: .success(response.targetText))
        } catch {
            complete(with: .failure(error))
        }
    }

    private func complete(with result: Result<String, Error>) {
        guard let request = pendingRequest else {
            configuration = nil
            return
        }

        pendingRequest = nil
        configuration = nil

        switch result {
        case .success(let translated):
            request.continuation.resume(returning: translated)
        case .failure(let error):
            request.continuation.resume(throwing: error)
        }
    }
}

@available(macOS 15.0, *)
private struct PendingRequest {
    let text: String
    let continuation: CheckedContinuation<String, Error>
}

@available(macOS 15.0, *)
private struct TranslationBridgeView: View {
    @ObservedObject var model: TranslationBridgeModel

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .translationTask(model.configuration) { session in
                await model.performTranslation(using: session)
            }
    }
}
