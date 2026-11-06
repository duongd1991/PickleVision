//
//  PickleVisionApp.swift
//  PickleVision
//
//  Created by Frontend Coder on 2026-11-05.
//  Application entry point and lifecycle coordinator for PickleVision Native iOS.
//

import SwiftUI
import AVFoundation

@main
struct PickleVisionApp: App {
    
    // MARK: - State Objects
    
    /// Bộ điều phối trung tâm Computer Vision pipeline
    @StateObject private var cvCoordinator = PickleballCVCoordinator()
    
    /// Bộ quản lý camera thu nhận video 1080p @ 60/120fps
    @StateObject private var cameraManager = CameraManager()
    
    // MARK: - App Lifecycle
    
    init() {
        configureAudioVideoSession()
    }
    
    var body: some Scene {
        WindowGroup {
            LiveMatchContainerView()
                .environmentObject(cvCoordinator)
                .environmentObject(cvCoordinator.rallyEngine)
                .environmentObject(cvCoordinator.courtCalibrationService)
                .environmentObject(cameraManager)
                .preferredColorScheme(.dark)
                .onAppear {
                    setupCameraAndPipeline()
                }
        }
    }
    
    // MARK: - Configuration Helpers
    
    /// Cấu hình AVAudioSession để không xung đột với thu nhận video tốc độ cao
    private func configureAudioVideoSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("[PickleVisionApp] Cảnh báo cấu hình AVAudioSession: \(error.localizedDescription)")
        }
    }
    
    /// Khởi động camera và liên kết luồng sampleBuffer vào Computer Vision coordinator
    private func setupCameraAndPipeline() {
        cameraManager.delegate = cvCoordinator
        cameraManager.setupCamera(preferredFPS: 120.0) { result in
            switch result {
            case .success(let actualFPS):
                print("[PickleVisionApp] Camera sẵn sàng ở \(actualFPS) FPS (1080p)")
                self.cameraManager.startSession()
            case .failure(let error):
                print("[PickleVisionApp] Lỗi khởi tạo camera: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - CameraManagerDelegate Extension

extension PickleballCVCoordinator: CameraManagerDelegate {
    public func cameraManager(
        _ manager: CameraManager,
        didOutput sampleBuffer: CMSampleBuffer,
        pixelBuffer: CVPixelBuffer
    ) {
        // Chuyển tiếp khung hình vào pipeline Computer Vision
        self.processFrame(sampleBuffer: sampleBuffer)
    }
}
