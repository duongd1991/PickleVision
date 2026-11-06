//
//  VideoStabilizer.swift
//  PickleVision
//
//  Created by Backend Coder on 2026-11-05.
//  Cinematic Extended Stabilization and Homography Anchor Tracking for Tripod Vibration Compensation.
//

import Foundation
import AVFoundation
import Vision
import CoreGraphics
import simd

/// Điểm neo quang học trên sân để theo dõi dịch chuyển rung lắc
public struct AnchorPoint {
    public var originalPixel: CGPoint
    public var currentPixel: CGPoint
    public var courtPoint: CourtPoint
    public var isTracked: Bool
    
    public init(originalPixel: CGPoint, courtPoint: CourtPoint) {
        self.originalPixel = originalPixel
        self.currentPixel = originalPixel
        self.courtPoint = courtPoint
        self.isTracked = true
    }
}

/// Hệ thống chống rung kép: Phần cứng Cinematic Extended + Thuật toán Homography Anchor Tracking
public final class VideoStabilizer: ObservableObject {
    
    // MARK: - Properties
    
    /// Ma trận Homography chuẩn ban đầu (khi tripod đứng yên)
    public private(set) var baseHomography: simd_float3x3 = matrix_identity_float3x3
    
    /// Ma trận Homography tức thời đã được bù góc rung lắc
    @Published public private(set) var currentStabilizedHomography: simd_float3x3 = matrix_identity_float3x3
    
    /// Ma trận vi sai tích lũy ΔH (smoothed delta homography)
    public private(set) var smoothedDeltaH: simd_float3x3 = matrix_identity_float3x3
    
    /// Danh sách các điểm mốc chốt neo sân
    @Published public private(set) var anchorPoints: [AnchorPoint] = []
    
    /// Hệ số lọc thông thấp cho ma trận vi sai (alpha = 0.15)
    public let smoothingAlpha: Float = 0.15
    
    /// Ngưỡng phát hiện rung lắc để kích hoạt bù góc (pixel)
    public let vibrationThresholdPixels: CGFloat = 1.0
    
    private var lastPixelBuffer: CVPixelBuffer?
    private let sequenceHandler = VNSequenceRequestHandler()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - 1. Cinematic Extended Hardware Stabilization
    
    /// Kích hoạt chế độ chống rung mở rộng Cinematic Extended trên kết nối AVCaptureConnection
    @discardableResult
    public func enableCinematicExtended(on connection: AVCaptureConnection) -> Bool {
        guard connection.isVideoStabilizationSupported else {
            print("[VideoStabilizer] Thiết bị không hỗ trợ Video Stabilization trên kết nối này.")
            return false
        }
        
        connection.preferredVideoStabilizationMode = .cinematicExtended
        return connection.activeVideoStabilizationMode == .cinematicExtended ||
               connection.preferredVideoStabilizationMode == .cinematicExtended
    }
    
    // MARK: - 2. Homography Anchor Tracking Setup
    
    /// Thiết lập các điểm mốc neo cố định của sân dựa trên ma trận Homography chuẩn ban đầu
    public func initializeAnchors(with pixelCorners: [CGPoint], referenceHomography: simd_float3x3) {
        self.baseHomography = referenceHomography
        self.currentStabilizedHomography = referenceHomography
        self.smoothedDeltaH = matrix_identity_float3x3
        self.anchorPoints.removeAll()
        
        // 4 góc chuẩn sân: P1 (Near Left), P3 (Near Right), P12 (Far Right), P10 (Far Left)
        let landmarkKeys = ["P1_NearBLLeft", "P3_NearBLRight", "P12_FarBLRight", "P10_FarBLLeft"]
        for (index, pixel) in pixelCorners.enumerated() {
            guard index < landmarkKeys.count, let courtPt = CourtLandmarks.baselineOrigin[landmarkKeys[index]] else {
                continue
            }
            anchorPoints.append(AnchorPoint(originalPixel: pixel, courtPoint: courtPt))
        }
    }
    
    // MARK: - 3. Optical Flow & Differential Homography Estimation
    
    /// Theo dõi các điểm mốc neo trên khung hình mới và cập nhật ma trận Homography tức thời
    public func updateStabilizedHomography(with pixelBuffer: CVPixelBuffer) -> simd_float3x3 {
        guard !anchorPoints.isEmpty else {
            return baseHomography
        }
        
        guard let previousBuffer = lastPixelBuffer else {
            self.lastPixelBuffer = pixelBuffer
            return currentStabilizedHomography
        }
        
        // Sử dụng Vision Optical Flow để theo dõi độ dịch chuyển của các anchor
        let opticalFlowRequest = VNTrackOpticalFlowRequest()
        opticalFlowRequest.computationAccuracy = .high
        opticalFlowRequest.outputPixelFormat = kCVPixelFormatType_TwoComponent32Float
        
        var trackedNewPoints: [CGPoint] = []
        var validTranslations: [CGPoint] = []
        
        do {
            try sequenceHandler.perform([opticalFlowRequest], on: pixelBuffer)
            
            // Lấy kết quả dịch chuyển quang học
            if let observation = opticalFlowRequest.results?.first as? VNPixelBufferObservation {
                let flowBuffer = observation.pixelBuffer
                
                CVPixelBufferLockBaseAddress(flowBuffer, .readOnly)
                defer { CVPixelBufferUnlockBaseAddress(flowBuffer, .readOnly) }
                
                guard let baseAddress = CVPixelBufferGetBaseAddress(flowBuffer) else {
                    return currentStabilizedHomography
                }
                
                let flowWidth = CVPixelBufferGetWidth(flowBuffer)
                let flowHeight = CVPixelBufferGetHeight(flowBuffer)
                let bytesPerRow = CVPixelBufferGetBytesPerRow(flowBuffer)
                let floatPtr = baseAddress.assumingMemoryBound(to: Float.self)
                let floatsPerRow = bytesPerRow / MemoryLayout<Float>.size
                
                let bufferWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
                let bufferHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
                
                for i in 0..<anchorPoints.count {
                    let pt = anchorPoints[i].currentPixel
                    // Tọa độ chuẩn hóa trên flow buffer (0..1)
                    let normX = pt.x / bufferWidth
                    let normY = pt.y / bufferHeight
                    
                    let fx = Int(normX * CGFloat(flowWidth))
                    let fy = Int(normY * CGFloat(flowHeight))
                    
                    if fx >= 0 && fx < flowWidth && fy >= 0 && fy < flowHeight {
                        let offset = fy * floatsPerRow + fx * 2
                        let dx = CGFloat(floatPtr[offset])
                        let dy = CGFloat(floatPtr[offset + 1])
                        
                        let newX = pt.x + dx
                        let newY = pt.y + dy
                        trackedNewPoints.append(CGPoint(x: newX, y: newY))
                        validTranslations.append(CGPoint(x: dx, y: dy))
                    } else {
                        trackedNewPoints.append(pt)
                    }
                }
            }
        } catch {
            // Nếu optical flow lỗi, giữ nguyên ma trận hiện tại
            return currentStabilizedHomography
        }
        
        self.lastPixelBuffer = pixelBuffer
        
        // Cập nhật tọa độ anchor
        for i in 0..<min(anchorPoints.count, trackedNewPoints.count) {
            anchorPoints[i].currentPixel = trackedNewPoints[i]
        }
        
        // 4. Tính toán độ lệch trung bình (Mean Translation vector)
        guard !validTranslations.isEmpty else { return currentStabilizedHomography }
        
        var meanDx: CGFloat = 0.0
        var meanDy: CGFloat = 0.0
        for trans in validTranslations {
            meanDx += trans.x
            meanDy += trans.y
        }
        meanDx /= CGFloat(validTranslations.count)
        meanDy /= CGFloat(validTranslations.count)
        
        let shiftMagnitude = sqrt(meanDx * meanDx + meanDy * meanDy)
        guard shiftMagnitude >= vibrationThresholdPixels else {
            // Rung lắc nhỏ dưới 1 pixel -> Giữ nguyên ma trận ổn định
            return currentStabilizedHomography
        }
        
        // 5. Ước lượng ma trận vi sai tịnh tiến:
        // Delta H = [[1, 0, dx],
        //            [0, 1, dy],
        //            [0, 0, 1]]
        let instantDeltaH = simd_float3x3(
            SIMD3<Float>(1.0, 0.0, 0.0),
            SIMD3<Float>(0.0, 1.0, 0.0),
            SIMD3<Float>(Float(meanDx), Float(meanDy), 1.0)
        )
        
        // 6. Bộ lọc thông thấp (Low-pass filter):
        // smoothedDeltaH = alpha * instantDeltaH + (1 - alpha) * smoothedDeltaH
        smoothedDeltaH = instantDeltaH * smoothingAlpha + smoothedDeltaH * (1.0 - smoothingAlpha)
        
        // 7. Cập nhật ma trận phối cảnh tức thời:
        // H_t = H_0 * inv(smoothedDeltaH)
        let invDelta = smoothedDeltaH.inverse
        currentStabilizedHomography = baseHomography * invDelta
        
        return currentStabilizedHomography
    }
    
    /// Reset bộ chống rung về trạng thái ban đầu
    public func reset() {
        self.lastPixelBuffer = nil
        self.smoothedDeltaH = matrix_identity_float3x3
        self.currentStabilizedHomography = baseHomography
        for i in 0..<anchorPoints.count {
            anchorPoints[i].currentPixel = anchorPoints[i].originalPixel
            anchorPoints[i].isTracked = true
        }
    }
}
