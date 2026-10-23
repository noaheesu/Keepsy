import PhotosUI
import SwiftUI

struct BatchEditor: View {
    let batch: Batch?

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [SortDescriptor(\Location.sortOrder), SortDescriptor(\Location.name)])
    private var locations: FetchedResults<Location>
    @FetchRequest(sortDescriptors: [SortDescriptor(\Item.name)], predicate: NSPredicate(value: false))
    private var previousItems: FetchedResults<Item>
    @State private var draft: BatchDraft
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var showSaveError = false

    init(batch: Batch?, location: Location? = nil) {
        self.batch = batch
        _draft = State(initialValue: batch.map(BatchDraft.init(batch:)) ?? BatchDraft(location: location))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $draft.name)
                    Picker("Location", selection: $draft.location) {
                        Text("None").tag(Location?.none)
                        ForEach(locations.sorted { $0.treeOrder.lexicographicallyPrecedes($1.treeOrder) }) { location in
                            Text(location.path).tag(Optional(location))
                        }
                    }
                }
                if batch == nil && !previousItems.isEmpty {
                    Section("Previously added") {
                        ForEach(previousItems.prefix(5)) { item in
                            Button(item.name ?? "") { draft.fill(from: item) }
                        }
                    }
                }
                Section {
                    Toggle("Expires", isOn: $draft.hasExpiry)
                    if draft.hasExpiry {
                        DatePicker("Expiration date", selection: $draft.expiresAt, displayedComponents: .date)
                    }
                    Stepper("Quantity: \(draft.quantity)", value: $draft.quantity, in: 1...99)
                }
                Section("Remaining") {
                    Picker("Remaining", selection: $draft.level) {
                        ForEach(Level.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                photoSection
                if let batch {
                    Section {
                        Button("Delete", role: .destructive) {
                            context.delete(batch)
                            try? context.save()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(batch == nil ? "Add Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!draft.isValid)
                }
            }
            .onChange(of: draft.name) {
                let name = draft.name.trimmingCharacters(in: .whitespaces)
                previousItems.nsPredicate = name.isEmpty
                    ? NSPredicate(value: false)
                    : NSPredicate(format: "name CONTAINS[cd] %@ AND NOT (name ==[c] %@)", name, name)
            }
            .task(id: pickedPhoto) {
                guard let data = try? await pickedPhoto?.loadTransferable(type: Data.self) else { return }
                draft.photo = data.downscaledJPEG()
            }
            .alert("Couldn't save", isPresented: $showSaveError) {}
        }
    }

    private var photoSection: some View {
        Section("Photo") {
            if let data = draft.photo, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 240)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(Text("Photo"))
                Button("Remove Photo", role: .destructive) {
                    draft.photo = nil
                    pickedPhoto = nil
                }
            }
            PhotosPicker("Choose Photo", selection: $pickedPhoto, matching: .images)
        }
    }

    private func save() {
        do {
            try draft.save(to: batch, in: context)
            dismiss()
        } catch {
            context.rollback()
            showSaveError = true
        }
    }
}

#Preview("Add") {
    BatchEditor(batch: nil)
        .environment(\.managedObjectContext, Persistence.preview.container.viewContext)
}
