import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await capture() }
    }

    private func capture() async {
        var chunks: [String] = []
        for item in extensionContext?.inputItems as? [NSExtensionItem] ?? [] {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier), let value = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier), let text = value as? String { chunks.append(text) }
                else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier), let value = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier), let url = value as? URL { chunks.append(url.absoluteString) }
            }
        }
        if !chunks.isEmpty {
            let defaults = UserDefaults(suiteName: appGroupID)
            var pending = defaults?.stringArray(forKey: "shared-inbox") ?? []
            pending.append(chunks.joined(separator: "\n")); defaults?.set(pending, forKey: "shared-inbox")
        }
        extensionContext?.completeRequest(returningItems: nil)
    }
}
