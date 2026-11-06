//
//  PickleVisionApp.swift
//  PickleVision
//
//  Created by Frontend Coder on 2026-11-05.
//  Application entry point and lifecycle coordinator for PickleVision Native iOS.
//

import SwiftUI
import AVFoundation

/// Trạng thái luồng điều hướng màn hình chính của PickleVision
public enum AppFlowScreen {
    case home
    case playerSetup
    case courtCalibration
    case liveMatch
}

/// Khóa cứng hướng màn hình là NẰM NGANG (Landscape Only) dù có cầm máy dọc
final class PickleVisionAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return .landscape
    }
}

@main
struct PickleVisionApp: App {
    
    @UIApplicationDelegateAdaptor(PickleVisionAppDelegate.self) var appDelegate
    
    // MARK: - State Objects
    
    /// Bộ điều phối trung tâm Computer Vision pipeline
    @StateObject private var cvCoordinator = PickleballCVCoordinator()
    
    /// Bộ quản lý camera thu nhận video 1080p @ 60/120fps
    @StateObject private var cameraManager = CameraManager()
    
    // MARK: - App Navigation States
    
    @State private var currentScreen: AppFlowScreen = .home
    @State private var currentFrameBuffer: CVPixelBuffer?
    @State private var playerNames: [String] = ["A1", "A2", "B1", "B2"]
    @State private var initialServerIndex: Int = 0
    @State private var calibratedCorners: [CGPoint] = CourtCalibrationSetupView.default10Points
    
    // MARK: - App Lifecycle
    
    init() {
        configureAudioVideoSession()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                switch currentScreen {
                case .home:
                    HomeView(
                        onStartTapped: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                currentScreen = .playerSetup
                            }
                        }
                    )
                    .transition(.opacity)
                    
                case .playerSetup:
                    MatchSetupView(
                        initialNames: playerNames,
                        initialServerIndex: initialServerIndex,
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                currentScreen = .home
                            }
                        },
                        onNext: { names, server in
                            self.playerNames = names
                            self.initialServerIndex = server
                            self.cvCoordinator.setAllPlayerNames(names)
                            withAnimation(.easeInOut(duration: 0.25)) {
                                currentScreen = .courtCalibration
                            }
                        }
                    )
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    
                case .courtCalibration:
                    CourtCalibrationSetupView(
                        currentFrameBuffer: $currentFrameBuffer,
                        initialCorners: calibratedCorners,
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                currentScreen = .playerSetup
                            }
                        },
                        onNext: { corners in
                            self.calibratedCorners = corners
                            self.applyCourtCalibration(corners: corners)
                            withAnimation(.easeInOut(duration: 0.25)) {
                                currentScreen = .liveMatch
                            }
                        }
                    )
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    
                case .liveMatch:
                    LiveMatchContainerView(
                        onExitToHome: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                currentScreen = .home
                            }
                        }
                    )
                    .transition(.opacity)
                }
            }
            .environmentObject(cvCoordinator)
            .environmentObject(cvCoordinator.rallyEngine)
            .environmentObject(cvCoordinator.courtCalibrationService)
            .environmentObject(cameraManager)
            .preferredColorScheme(.dark)
            .onAppear {
                setupCameraAndPipeline()
            }
            .onReceive(cameraManager.framePublisher) { frame in
                self.currentFrameBuffer = frame.pixelBuffer
            }
        }
    }
    
    // MARK: - Configuration Helpers
    
    private func applyCourtCalibration(corners: [CGPoint]) {
        guard corners.count >= 4 else { return }
        let pixelCorners = corners.map { CGPoint(x: $0.x * 1920.0, y: $0.y * 1080.0) }
        _ = cvCoordinator.courtCalibrationService.calibrate(withPixelCorners: pixelCorners)
        if let h = cvCoordinator.courtCalibrationService.homographyMatrix {
            cvCoordinator.updateCourtHomography(h)
        }
    }
    
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
