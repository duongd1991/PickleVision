//
//  CameraManager.swift
//  PickleVision
//
//  Created by Backend Coder on 2026-11-05.
//  AVCaptureSession high-speed 1080p @ 60fps/120fps video ingestion and sample buffer dispatch.
//

import Foundation
import AVFoundation
import CoreMedia
import Combine

/// Protocol tiếp nhận luồng khung hình từ CameraManager
public protocol CameraManagerDelegate: AnyObject {
    func cameraManager(
        _ manager: CameraManager,
        didOutput sampleBuffer: CMSampleBuffer,
        pixelBuffer: CVPixelBuffer
    )
}

/// Lỗi cấu hình Camera
public enum CameraConfigurationError: LocalizedError {
    case deviceNotFound
    case formatNotSupported(fps: Double)
    case cannotAddInput
    case cannotAddOutput
    case unauthorized
    
    public var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "Không tìm thấy cảm biến camera phù hợp trên thiết bị."
        case .formatNotSupported(let fps):
            return "Định dạng 1080p @ \(fps)fps không được hỗ trợ trên thiết bị này."
        case .cannotAddInput:
            return "Không thể gắn đầu vào video vào AVCaptureSession."
        case .cannotAddOutput:
            return "Không thể gắn đầu ra AVCaptureVideoDataOutput vào session."
        case .unauthorized:
            return "Người dùng chưa cấp quyền truy cập Camera."
        }
    }
}

/// Quản lý AVCaptureSession tốc độ cao (1080p @ 60/120fps) cho phân tích bóng pickleball
public final class CameraManager: NSObject, ObservableObject {
    
    // MARK: - Properties
    
    public let captureSession = AVCaptureSession()
    public private(set) var activeCameraDevice: AVCaptureDevice?
    public private(set) var videoDataOutput = AVCaptureVideoDataOutput()
    
    public weak var delegate: CameraManagerDelegate?
    
    /// Combine Publisher phát khung hình cho các module đăng ký
    public let framePublisher = PassthroughSubject<(sampleBuffer: CMSampleBuffer, pixelBuffer: CVPixelBuffer), Never>()
    
    @Published public private(set) var isSessionRunning: Bool = false
    @Published public private(set) var currentConfiguredFPS: Double = 60.0
    @Published public private(set) var isParametersLocked: Bool = false
    
    private let sessionQueue = DispatchQueue(label: "com.picklevision.camera.session", qos: .userInitiated)
    private let videoOutputQueue = DispatchQueue(label: "com.picklevision.camera.output", qos: .userInteractive)
    
    private var videoConnection: AVCaptureConnection?
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
    }
    
    // MARK: - Setup & Configuration
    
    /// Kiểm tra quyền truy cập Camera và khởi tạo Session
    public func setupCamera(preferredFPS: Double = 120.0, completion: @escaping (Result<Double, Error>) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                self.configureSession(preferredFPS: preferredFPS, completion: completion)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    if granted {
                        self.sessionQueue.async {
                            self.configureSession(preferredFPS: preferredFPS, completion: completion)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(.failure(CameraConfigurationError.unauthorized))
                        }
                    }
                }
            case .denied, .restricted:
                DispatchQueue.main.async {
                    completion(.failure(CameraConfigurationError.unauthorized))
                }
            @unknown default:
                DispatchQueue.main.async {
                    completion(.failure(CameraConfigurationError.unauthorized))
                }
            }
        }
    }
    
    private func configureSession(preferredFPS: Double, completion: @escaping (Result<Double, Error>) -> Void) {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .inputPriority // Cho phép cấu hình activeFormat độ phân giải và framerate riêng
        
        // 1. Tìm camera sau (Back wide angle camera)
        let deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .back
        )
        
        guard let device = discoverySession.devices.first else {
            captureSession.commitConfiguration()
            DispatchQueue.main.async { completion(.failure(CameraConfigurationError.deviceNotFound)) }
            return
        }
        self.activeCameraDevice = device
        
        // 2. Gắn Device Input
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            } else {
                captureSession.commitConfiguration()
                DispatchQueue.main.async { completion(.failure(CameraConfigurationError.cannotAddInput)) }
                return
            }
        } catch {
            captureSession.commitConfiguration()
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }
        
        // 3. Cấu hình Format 1080p và High FPS (60fps hoặc 120fps)
        var selectedFPS = 60.0
        do {
            selectedFPS = try configureDeviceForHighSpeed(device: device, preferredFPS: preferredFPS)
        } catch {
            captureSession.commitConfiguration()
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }
        
        // 4. Cấu hình Video Output
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoDataOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        } else {
            captureSession.commitConfiguration()
            DispatchQueue.main.async { completion(.failure(CameraConfigurationError.cannotAddOutput)) }
            return
        }
        
        // 5. Kết nối Video và hướng khung hình (Mặc định quay ngang Landscape cho sân thi đấu)
        if let connection = videoDataOutput.connection(with: .video) {
            self.videoConnection = connection
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .landscapeRight
            }
        }
        
        captureSession.commitConfiguration()
        
        DispatchQueue.main.async {
            self.currentConfiguredFPS = selectedFPS
            completion(.success(selectedFPS))
        }
    }
    
    /// Cấu hình format 1080p và framerate cao nhất có thể
    private func configureDeviceForHighSpeed(device: AVCaptureDevice, preferredFPS: Double) throws -> Double {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        
        var bestFormat: AVCaptureDevice.Format?
        var bestFrameRateRange: AVFrameRateRange?
        
        for format in device.formats {
            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            // Lọc đúng độ phân giải 1080p (1920x1080)
            guard (dims.width == 1920 && dims.height == 1080) || (dims.width == 1080 && dims.height == 1920) else {
                continue
            }
            
            for range in format.videoSupportedFrameRateRanges {
                if range.maxFrameRate >= preferredFPS {
                    bestFormat = format
                    bestFrameRateRange = range
                    break
                } else if bestFormat == nil || range.maxFrameRate > (bestFrameRateRange?.maxFrameRate ?? 0) {
                    bestFormat = format
                    bestFrameRateRange = range
                }
            }
        }
        
        if bestFormat == nil {
            bestFormat = device.activeFormat
            bestFrameRateRange = device.activeFormat.videoSupportedFrameRateRanges.first
        }
        
        guard let selectedFormat = bestFormat, let selectedRange = bestFrameRateRange else {
            throw CameraConfigurationError.formatNotSupported(fps: preferredFPS)
        }
        
        device.activeFormat = selectedFormat
        let targetFPS = min(preferredFPS, selectedRange.maxFrameRate)
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
        
        device.activeVideoMinFrameDuration = frameDuration
        device.activeVideoMaxFrameDuration = frameDuration
        
        return targetFPS
    }
    
    // MARK: - Session Control
    
    /// Bắt đầu thu nhận khung hình
    public func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.captureSession.isRunning
            }
        }
    }
    
    /// Dừng thu nhận khung hình
    public func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }
    
    // MARK: - Lock Parameters (Focus & Exposure)
    
    /// Khóa tiêu cự và phơi sáng để không bị hunting khi bóng bay lại gần
    public func lockFocusAndExposure() {
        guard let device = activeCameraDevice else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                
                if device.isFocusModeSupported(.locked) {
                    device.focusMode = .locked
                }
                if device.isExposureModeSupported(.locked) {
                    device.exposureMode = .locked
                }
                if device.isWhiteBalanceModeSupported(.locked) {
                    device.whiteBalanceMode = .locked
                }
                DispatchQueue.main.async {
                    self.isParametersLocked = true
                }
            } catch {
                print("[CameraManager] Không thể khóa thông số quang học: \(error)")
            }
        }
    }
    
    /// Mở khóa tiêu cự và phơi sáng tự động liên tục
    public func unlockFocusAndExposure() {
        guard let device = activeCameraDevice else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }
                DispatchQueue.main.async {
                    self.isParametersLocked = false
                }
            } catch {
                print("[CameraManager] Không thể mở khóa thông số quang học: \(error)")
            }
        }
    }
    
    /// Thay đổi hướng quay video của camera (Landscape Right / Landscape Left / Portrait)
    public func setVideoOrientation(_ orientation: AVCaptureVideoOrientation) {
        sessionQueue.async { [weak self] in
            guard let self = self, let connection = self.videoConnection else { return }
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = orientation
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // 1. Gửi qua delegate
        delegate?.cameraManager(self, didOutput: sampleBuffer, pixelBuffer: pixelBuffer)
        
        // 2. Gửi qua Combine publisher
        framePublisher.send((sampleBuffer: sampleBuffer, pixelBuffer: pixelBuffer))
    }
    
    public func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Ghi nhận khung hình bị drop để giám sát hiệu năng
    }
}
