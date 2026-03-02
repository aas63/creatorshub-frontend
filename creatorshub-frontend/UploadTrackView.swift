import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import UIKit

struct UploadTrackView: View {
    enum UploadStage: Int, CaseIterable {
        case audio, cover, title, caption, success

        var label: String {
            switch self {
            case .audio: return "Select Audio"
            case .cover: return "Album Art"
            case .title: return "Track Title"
            case .caption: return "Caption"
            case .success: return "Completed"
            }
        }
    }

    @EnvironmentObject private var session: UserSession
    @State private var stage: UploadStage = .audio

    @State private var selectedFileURL: URL?
    @State private var selectedCoverImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?

    @State private var title = ""
    @State private var caption = ""

    @State private var isUploading = false
    @State private var showFilePicker = false
    @State private var statusMessage: String?
    @State private var uploadedTrackTitle: String?

    private let captionLimit = 150

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if stage != .success {
                        progressHeader
                    }
                    stageContent()
                    if let statusMessage = statusMessage {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 32)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Upload")
            .toolbar {
                if stage != .audio && stage != .success {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back") { goToPreviousStage() }
                    }
                }
            }
        }
        .sheet(isPresented: $showFilePicker) {
            AudioDocumentPicker(selectedURL: $selectedFileURL)
        }
        .onChange(of: selectedFileURL) { newValue in
            guard newValue != nil else { return }
            withAnimation { stage = .cover }
        }
        .onChange(of: selectedPhotoItem) { newValue in
            guard let item = newValue else { selectedCoverImage = nil; return }
            Task { await loadImage(from: item) }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(stage.label)
                .font(.title3).bold()
            ProgressView(value: progressValue)
                .tint(.blue)
        }
    }

    private var progressValue: Double {
        let maxStage = UploadStage.caption.rawValue
        let current = min(stage.rawValue, maxStage)
        return Double(current + 1) / Double(maxStage + 1)
    }

    @ViewBuilder
    private func stageContent() -> some View {
        switch stage {
        case .audio:
            audioStage
        case .cover:
            coverStage
        case .title:
            titleStage
        case .caption:
            captionStage
        case .success:
            successStage
        }
    }

    private var audioStage: some View {
        VStack(spacing: 16) {
            Button {
                showFilePicker = true
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: selectedFileURL == nil ? "square.and.arrow.up" : "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                .cornerRadius(18)
                        )
                    Text(selectedFileURL == nil ? "Upload Audio" : "Replace Audio")
                        .font(.headline)
                        .foregroundColor(.primary)
                    if let url = selectedFileURL {
                        Text(url.lastPathComponent)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    } else {
                        Text("Supported formats: MP3, M4A, WAV")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.05), radius: 20, y: 10)
            }
        }
    }

    private var coverStage: some View {
        VStack(spacing: 20) {
            Group {
                if let image = selectedCoverImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.secondary.opacity(0.1))
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                            Text("Optional album art")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(height: 220)
            .cornerRadius(24)
            .clipped()

            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(selectedCoverImage == nil ? "Add Photo" : "Change Photo", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(selectedCoverImage == nil ? "Skip" : "Continue") {
                    withAnimation { stage = .title }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var titleStage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Give your track a name")
                .font(.headline)
            TextField("Title (required)", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.title3)

            Button {
                withAnimation { stage = .caption }
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var captionStage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Caption (optional)")
                .font(.headline)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)

                TextEditor(text: $caption)
                    .padding()
                    .frame(height: 140)
                    .onChange(of: caption) { newValue in
                        if newValue.count > captionLimit {
                            caption = String(newValue.prefix(captionLimit))
                        }
                    }
            }

            HStack {
                Text("\(caption.count)/\(captionLimit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Button {
                completeUpload()
            } label: {
                HStack {
                    if isUploading { ProgressView() }
                    Text(isUploading ? "Publishing…" : "Complete Post")
                        .bold()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canPublish || isUploading)
        }
    }

    private var successStage: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            Text("Track Live!")
                .font(.largeTitle.bold())
            if let title = uploadedTrackTitle {
                Text("“\(title)” is now visible in the feed.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            Button("Share another track") {
                resetFlow()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(28)
        .shadow(color: Color.black.opacity(0.05), radius: 20, y: 10)
    }

    private var canPublish: Bool {
        guard selectedFileURL != nil else { return false }
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func goToPreviousStage() {
        switch stage {
        case .cover: stage = .audio
        case .title: stage = selectedCoverImage == nil ? .cover : .cover
        case .caption: stage = .title
        default: break
        }
    }

    private func completeUpload() {
        guard let fileURL = selectedFileURL else {
            statusMessage = "Select an audio file first."
            return
        }

        guard let token = session.accessToken else {
            statusMessage = "Log in to upload."
            return
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            statusMessage = "Title is required."
            return
        }

        isUploading = true
        statusMessage = nil

        let coverData = selectedCoverImage?.jpegData(compressionQuality: 0.9)
        APIService.shared.uploadTrack(
            fileURL: fileURL,
            title: trimmedTitle,
            description: "",
            caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
            coverImageData: coverData,
            accessToken: token
        ) { result in
            DispatchQueue.main.async {
                self.isUploading = false
                switch result {
                case .success(let response):
                    self.uploadedTrackTitle = response.title
                    NotificationCenter.default.post(name: .trackUploaded, object: nil)
                    withAnimation {
                        self.stage = .success
                    }
                case .failure(let error):
                    self.statusMessage = "Upload failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func resetFlow() {
        stage = .audio
        selectedFileURL = nil
        selectedCoverImage = nil
        selectedPhotoItem = nil
        title = ""
        caption = ""
        uploadedTrackTitle = nil
        statusMessage = nil
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
                statusMessage = "Failed to load image."
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
