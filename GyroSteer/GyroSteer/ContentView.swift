//
//  ContentView.swift
//  GyroSteer
//
//  Created by Christina Lark on 10/19/24.
//

import SwiftUI
import SwiftData
import CoreMotion
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    private var motionManager = CMMotionManager()
    @State private var gyroX: Double = 0.0
    @State private var gyroY: Double = 0.0
    @State private var gyroZ: Double = 0.0
    @State private var timer: Timer?
    @State private var documentURL: URL?
    
    private var fileURL: URL? {
        let fileManager = FileManager.default
        do {
            let documentsURL = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            return documentsURL.appendingPathComponent("data.csv")
        } catch {
            print("CSV FILE NOT LOCATED OR NOT CREATED")
            return nil
        }
    }
    
    private func createCSVFile(at url: URL) {
        guard let fileURL = documentURL else { return }
                
        let fileContents = "Timestamp, gyroX, gyroY, gyroZ\n"
        do {
            try fileContents.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("ERROR CREATING FILE")
        }
    }
    
    private func appendDataToCSV() {
        guard let fileURL = fileURL else { return }
        
        let timestamp = Date()
        
        let csvRow = "\(timestamp), \(gyroX), \(gyroY), \(gyroZ)\n"
        
        if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
            fileHandle.seekToEndOfFile()
            if let data = csvRow.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } else {
            print("FILE NOT AVAILABLE FOR WRITING")
        }
    }
    
    private func startGyroUpdates() {
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = 0.1 // SET THIS!!
            motionManager.startGyroUpdates(to : OperationQueue.main) { data, error in
                if let gyroData = data {
                    self.gyroX = gyroData.rotationRate.x
                    self.gyroY = gyroData.rotationRate.y
                    self.gyroZ = gyroData.rotationRate.z
                    
                    self.appendDataToCSV()
                } else if let error = error {
                    print("ERROR HERE NOW -- DIDN'T RECEIVE GYRO DATA")
                }
            }
        }
    }
    
    private func stopGyroUpdates() {
        motionManager.stopGyroUpdates()
    }
    
    private func startDataCollection() {
        guard let fileURL = documentURL else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { _ in
            self.appendDataToCSV()
        }
    }

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                    } label: {
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
        
        VStack {
            Text("Gyroscope Data")
                .font(.headline)
                .padding()

            Text("Rotation Rate X: \(gyroX, specifier: "%.2f")")
            Text("Rotation Rate Y: \(gyroY, specifier: "%.2f")")
            Text("Rotation Rate Z: \(gyroZ, specifier: "%.2f")")
            
            DocumentPickerButton(documentURL: $documentURL) {
                guard let fileURL = documentURL else { return }
                createCSVFile(at: fileURL)
                startDataCollection()
            }
            .frame(height: 500) // EDIT ME -- IT'S NOT RENDERING GOOD
            .padding(.top, 20)
            
            if let url = documentURL {
                Text("SAVED AT: \(url.absoluteString)")
            } else {
                Text("NO FILE SELECTED")
            }
        }
        
        List {
            ForEach(items) { item in
                Text("ITEM AT: \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
            }
            .onDelete(perform: deleteItems)
        }
        
        .onAppear {
            if documentURL != nil {
                startDataCollection()
            }
        }
        .onDisappear {
            timer?.invalidate()
            stopGyroUpdates()
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

import SwiftUI
import UIKit

struct DocumentPickerButton: UIViewControllerRepresentable {
    @Binding var documentURL: URL?
    var onFilePicked: () -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // NO UPDATES NEEDED
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPickerButton

        init(_ parent: DocumentPickerButton) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                parent.documentURL = url
                parent.onFilePicked()
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("PICKER CANCELLED")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
