import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct AudioDocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.audio], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let parent: AudioDocumentPicker

        init(_ parent: AudioDocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            let fileManager = FileManager.default
            let tempDir = fileManager.temporaryDirectory
            let destination = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)

            var shouldStopAccessing = false
            if url.startAccessingSecurityScopedResource() {
                shouldStopAccessing = true
            }

            defer {
                if shouldStopAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.copyItem(at: url, to: destination)
                DispatchQueue.main.async {
                    self.parent.selectedURL = destination
                }
            } catch {
                print("Failed to copy audio file:", error)
            }
        }
    }
}
