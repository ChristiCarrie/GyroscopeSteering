//
//  ContentView.swift
//  GyroSteer
//
//  Created by Christina Lark on 10/19/24.
//

import SwiftUI
import SwiftData
import CoreMotion

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    private var motionManager = CMMotionManager()
    @State private var gyroX: Double = 0.0
    @State private var gyroY: Double = 0.0
    @State private var gyroZ: Double = 0.0
    @State private var timer: Timer?
    @State private var buttonPressed = false
    @State private var accessFile = false
    
    private var fileURL: URL? {
        let fileManager = FileManager.default
        do {
            let documentsURL = try fileManager.url(for: .userDirectory, in: .localDomainMask, appropriateFor: nil, create: true)
            return documentsURL.appendingPathComponent("rotrakData.csv")
        } catch {
            print("Error locating/creating CSV file")
            return nil
        }
    }
    
    private func createCSVFile() {
        guard let fileURL = fileURL else { return }
        let fileContents = "Timestamp, gyroX, gyroY, gyroZ\n"
        do {
            try fileContents.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error creating file")
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
            print("File not available for writing")
        }
    }
    
    private func startGyroUpdates() {
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = 0.1
            motionManager.startGyroUpdates(to: .main) { data, error in
                if let gyroData = data {
                    self.gyroX = gyroData.rotationRate.x
                    self.gyroY = gyroData.rotationRate.y
                    self.gyroZ = gyroData.rotationRate.z
                    self.appendDataToCSV()
                } else if let error = error {
                    print("Error receiving gyro data: \(error)")
                }
            }
        }
    }
    
    private func stopGyroUpdates() {
        motionManager.stopGyroUpdates()
    }
    
    private func startDataCollection() {
        buttonPressed = true
        createCSVFile()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            self.startGyroUpdates()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                self.stopGyroUpdates()
            }
        }
    }
    
    var body: some View {
        VStack {
            VStack {
                Text("Gyroscope Data")
                    .font(.headline)
                    .padding()
                
                Text("Rotation Rate X: \(gyroX, specifier: "%.2f")")
                Text("Rotation Rate Y: \(gyroY, specifier: "%.2f")")
                Text("Rotation Rate Z: \(gyroZ, specifier: "%.2f")")
                
                Button("Start Collection") {
                    startDataCollection()
                }
                .padding()
                
                Button("Stop Collection") {
                    buttonPressed = false
                    accessFile = true
                    stopGyroUpdates()
                    // FILE NOW
                }
                .padding()
                
                if buttonPressed {
                    Text("Writing to file...")
                        .foregroundStyle(.red)
                        .padding()
                }
                
                if accessFile {
                    Text("Access file here...")
                        .foregroundStyle(.green)
                        .padding()
                    // FILE HERE
                }
            }
            .onAppear {
                createCSVFile()
            }
            .onDisappear {
                timer?.invalidate()
                stopGyroUpdates()
            }
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

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
