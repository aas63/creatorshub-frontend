import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import UIKit

struct UploadTrackView: View {
    @EnvironmentObject private var session: UserSession
    @State private var title = ""
    @State private var description = ""
    @State private var selectedFileURL: URL?
    @State private var selectedCoverImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var resultText = ""
    @State private var showFilePicker = false
    @State private var isUploading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Upload Track")
                .font(.headline)

            TextField("Track Title", text: $title)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("Description (optional)", text: $description, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    showFilePicker = true
                } label: {
                    HStack {
                        Image(systemName: "music.note")
                        Text(selectedFileURL?.lastPathComponent ?? "Pick Audio File")
                    }
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo")
                        Text(selectedCoverImage == nil ? "Pick Cover Image (optional)" : "Change Cover Image")
                    }
                }
                .onChange(of: selectedPhotoItem) { newValue in
                    guard let item = newValue else {
                        selectedCoverImage = nil
                        return
                    }

                    Task {
                        await loadImage(from: item)
                    }
                }

                if let image = selectedCoverImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 150)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.secondary, lineWidth: 1)
                        )
                }
            }

            Button {
                uploadTrack()
            } label: {
                HStack {
                    if isUploading {
                        ProgressView()
                    }
                    Text(isUploading ? "Uploading..." : "Upload Track")
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(isUploading)
            .padding()
            .background(isUploading ? Color.gray.opacity(0.4) : Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)

            Text(resultText)
                .font(.subheadline)
                .foregroundColor(.secondary)

        }
        .sheet(isPresented: $showFilePicker) {
            DocumentPicker(selectedURL: $selectedFileURL)
        }
    }

    private func uploadTrack() {
        guard let fileURL = selectedFileURL else {
            resultText = "Please pick an audio file first."
            return
        }

        guard let token = session.accessToken else {
            resultText = "Log in to upload tracks."
            return
        }

        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            resultText = "Title is required."
            return
        }

        isUploading = true
        resultText = ""

        let coverData = selectedCoverImage?.jpegData(compressionQuality: 0.85)

        APIService.shared.uploadTrack(
            fileURL: fileURL,
            title: title,
            description: description,
            coverImageData: coverData,
            accessToken: token
        ) { result in
            DispatchQueue.main.async {
                isUploading = false
                switch result {
                case .success(let track):
                    resultText = "Uploaded: \(track.title) (ID: \(track.trackId))"
                    resetForm()
                case .failure(let error):
                    resultText = "Upload failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func resetForm() {
        title = ""
        description = ""
        selectedFileURL = nil
        selectedCoverImage = nil
        selectedPhotoItem = nil
    }

    private func loadImage(from item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedCoverImage = image
                }
            }
        } catch {
            await MainActor.run {
                resultText = "Failed to load cover image."
            }
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.audio], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.selectedURL = urls.first
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}

struct UploadTrackView_Previews: PreviewProvider {
    static var previews: some View {
        UploadTrackView()
            .environmentObject(UserSession.shared)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
