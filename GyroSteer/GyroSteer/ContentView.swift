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
    // @State private var timer: Timer?
    @State private var alertTimer : Timer?
    @State private var buttonPressed = false
    @State private var accessFile = false
    @State private var danger = false
    @State private var counter = 0
    
    private var fileURL: URL? {
        let fileManager = FileManager.default
        do {
            let documentsURL = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
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
            motionManager.gyroUpdateInterval = 0.5 // ADJUST AS NEEDED
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
        alertTimer?.invalidate()
        alertTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            danger = false
            alert()
        }
    }
    
    private func stopGyroUpdates() {
        self.gyroX = 0.0
        self.gyroY = 0.0
        self.gyroZ = 0.0
        accessFile = true
        motionManager.stopGyroUpdates()
    }
    
    private func alert() {
        if abs(gyroX) > 4 || abs(gyroY) > 4 || abs(gyroZ) > 2 || (abs(gyroX) + abs(gyroY)) > 6 {
            // DIAL TO DETERMINE WHAT TURNING MAGNITUDE IS "DANGEROUS"
            danger = true
            counter = counter + 1
        }
    }
    
    private func startDataCollection() {
        buttonPressed = true
        createCSVFile()
        self.startGyroUpdates()
    }
    
    var body: some View {
        ZStack {
            if (danger) {
                Color.red
                .ignoresSafeArea()
            }
            
            VStack {
                Text("Gyroscope Data")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
                
                Text("Rotation Rate X: \(gyroX, specifier: "%.2f")")
                    .foregroundStyle(.white)
                Text("Rotation Rate Y: \(gyroY, specifier: "%.2f")")
                    .foregroundStyle(.white)
                Text("Rotation Rate Z: \(gyroZ, specifier: "%.2f")")
                    .foregroundStyle(.white)
                
                Button("Start Collection") {
                    startDataCollection()
                }
                .padding()
                
                Button("Stop Collection") {
                    buttonPressed = false
                    accessFile = true
                    stopGyroUpdates()
                }
                .padding()
                
                if buttonPressed {
                    Text("Writing to file...")
                        .foregroundStyle(.yellow)
                        .padding()
                }
                
                if accessFile {
                    Text("File sent!")
                        .foregroundStyle(.green)
                        .padding()
                }
                
                Text("Danger Counter: \(counter)")
                    .foregroundStyle(.red)
                    .padding()
            }
            .onAppear {
                createCSVFile()
            }
            .onDisappear {
                alertTimer?.invalidate()
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
