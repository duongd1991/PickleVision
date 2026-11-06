//
//  VideoExportEngine.swift
//  PickleVision
//
//  Created by Frontend Coder on 2026-11-05.
//  Dual-Stream Video Export Engine with AVAssetWriter: Clean Feed & Burn-in Broadcast HUD (16:9 & 9:16).
//

import Foundation
import AVFoundation
import CoreGraphics
import CoreVideo
import CoreMedia
import UIKit
import SwiftUI

/// Tùy chọn tỷ lệ khung hình xuất video
public enum ExportAspectMode: Equatable {
    case landscape16x9 // 1920 x 1080 (Broadcast, YouTube, TV)
    case portrait9x16  // 1080 x 1920 (TikTok, Instagram Reels, Shorts)
    
    public var targetDimensions: CGSize {
        switch self {
        case .landscape16x9:
            return CGSize(width: 1920, height: 1080)
        case .portrait9x16:
            return CGSize(width: 1080, height: 1920)
        }
    }
}

/// Loại luồng video xuất ra
public enum ExportStreamType: Equatable {
    case cleanVideo         // Video gốc chất lượng cao không gắn HUD overlay
    case burnInBroadcast    // Video truyền hình hoàn chỉnh gắn HUD, Minimap và Telemetry
}

/// Khung dữ liệu viễn trắc theo Presentation Time Stamp (PTS)
public struct RallyTelemetryFrame: Equatable {
    public let timestamp: CMTime
    public let ballPositionCourtM: CGPoint?
    public let ballPositionPixel: CGPoint?
    public let playerPositionsM: [Int: CGPoint]
    public let rallyIndex: Int
    public let shotCount: Int
    public let rallyDuration: TimeInterval
    public let scoreText: String
    public let rallyStateText: String
    
    public init(
        timestamp: CMTime,
        ballPositionCourtM: CGPoint? = nil,
        ballPositionPixel: CGPoint? = nil,
        playerPositionsM: [Int: CGPoint] = [:],
        rallyIndex: Int = 1,
        shotCount: Int = 0,
        rallyDuration: TimeInterval = 0.0,
        scoreText: String = "0 - 0 - 2",
        rallyStateText: String = "ĐANG ĐÁNH"
    ) {
        self.timestamp = timestamp
        self.ballPositionCourtM = ballPositionCourtM
        self.ballPositionPixel = ballPositionPixel
        self.playerPositionsM = playerPositionsM
        self.rallyIndex = rallyIndex
        self.shotCount = shotCount
        self.rallyDuration = rallyDuration
        self.scoreText = scoreText
        self.rallyStateText = rallyStateText
    }
}

/// Động cơ xuất video phân tích Pickleball chất lượng cao 1080p bằng AVAssetWriter
public final class VideoExportEngine {
    
    // MARK: - Properties
    
    private let exportQueue = DispatchQueue(label: "com.picklevision.videoexport.queue", qos: .userInitiated)
    
    public init() {}
    
    // MARK: - Export Single Stream
    
    /// Xuất video đơn lẻ (Clean Feed hoặc Burn-in Broadcast HUD)
    public func exportVideo(
        sourceAsset: AVAsset,
        telemetryLog: [RallyTelemetryFrame],
        streamType: ExportStreamType,
        aspectMode: ExportAspectMode,
        outputURL: URL,
        progressHandler: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // Xóa file cũ nếu đã tồn tại
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        Task {
            do {
                // 1. Nạp Video Track từ source asset
                guard let videoTrack = try await sourceAsset.loadTracks(withMediaType: .video).first else {
                    throw NSError(
                        domain: "VideoExportEngine",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy track video trong source asset."]
                    )
                }
                
                let sourceDuration = try await sourceAsset.load(.duration)
                let totalDurationSeconds = CMTimeGetSeconds(sourceDuration)
                
                // 2. Thiết lập AVAssetReader
                let reader = try AVAssetReader(asset: sourceAsset)
                let readerOutputSettings: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                ]
                let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerOutputSettings)
                readerOutput.alwaysCopiesSampleData = false
                guard reader.canAdd(readerOutput) else {
                    throw NSError(
                        domain: "VideoExportEngine",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Không thể gắn reader output."]
                    )
                }
                reader.add(readerOutput)
                
                // 3. Thiết lập AVAssetWriter
                let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
                let targetSize = aspectMode.targetDimensions
                
                let writerOutputSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: Int(targetSize.width),
                    AVVideoHeightKey: Int(targetSize.height),
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: 16_000_000, // 16 Mbps cho chất lượng 1080p sắc nét
                        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                        AVVideoExpectedSourceFrameRateKey: 60
                    ]
                ]
                
                let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: writerOutputSettings)
                writerInput.expectsMediaDataInRealTime = false
                
                let pixelBufferAttributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                    kCVPixelBufferWidthKey as String: Int(targetSize.width),
                    kCVPixelBufferHeightKey as String: Int(targetSize.height),
                    kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
                    kCVPixelBufferCGImageCompatibilityKey as String: true
                ]
                
                let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: writerInput,
                    sourcePixelBufferAttributes: pixelBufferAttributes
                )
                
                guard writer.canAdd(writerInput) else {
                    throw NSError(
                        domain: "VideoExportEngine",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "Không thể gắn writer input."]
                    )
                }
                writer.add(writerInput)
                
                // 4. Bắt đầu phiên Reader & Writer
                guard reader.startReading() else {
                    throw reader.error ?? NSError(
                        domain: "VideoExportEngine",
                        code: -4,
                        userInfo: [NSLocalizedDescriptionKey: "Không thể bắt đầu đọc video asset."]
                    )
                }
                
                writer.startWriting()
                writer.startSession(atSourceTime: .zero)
                
                // 5. Vòng lặp compositing và ghi video từng khung hình
                writerInput.requestMediaDataWhenReady(on: self.exportQueue) {
                    while writerInput.isReadyForMoreMediaData {
                        guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else {
                            // Kết thúc video feed
                            writerInput.markAsFinished()
                            writer.finishWriting {
                                if writer.status == .completed {
                                    DispatchQueue.main.async {
                                        progressHandler(1.0)
                                        completion(.success(outputURL))
                                    }
                                } else {
                                    DispatchQueue.main.async {
                                        completion(.failure(writer.error ?? NSError(domain: "VideoExportEngine", code: -5, userInfo: nil)))
                                    }
                                }
                            }
                            return
                        }
                        
                        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        guard let sourcePixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                            continue
                        }
                        
                        // Tìm telemetry tương ứng với timestamp
                        let telemetry = self.findTelemetry(for: pts, in: telemetryLog)
                        
                        // Tạo pixel buffer đích từ adaptor pool
                        if let pool = adaptor.pixelBufferPool {
                            var destinationPixelBuffer: CVPixelBuffer?
                            let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &destinationPixelBuffer)
                            
                            if status == kCVReturnSuccess, let destBuffer = destinationPixelBuffer {
                                self.renderCompositedFrame(
                                    sourceBuffer: sourcePixelBuffer,
                                    destinationBuffer: destBuffer,
                                    streamType: streamType,
                                    aspectMode: aspectMode,
                                    telemetry: telemetry
                                )
                                adaptor.append(destBuffer, withPresentationTime: pts)
                            }
                        }
                        
                        // Cập nhật tiến độ
                        let currentSec = CMTimeGetSeconds(pts)
                        if totalDurationSeconds > 0 {
                            let progress = min(max(currentSec / totalDurationSeconds, 0.0), 0.99)
                            DispatchQueue.main.async {
                                progressHandler(progress)
                            }
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Export Dual Streams Simultaneously
    
    /// Xuất đồng thời 2 luồng video: Clean Feed và Burn-in Broadcast
    public func exportDualStreams(
        sourceAsset: AVAsset,
        telemetryLog: [RallyTelemetryFrame],
        aspectMode: ExportAspectMode,
        cleanOutputURL: URL,
        broadcastOutputURL: URL,
        progressHandler: @escaping (Double) -> Void,
        completion: @escaping (Result<(cleanURL: URL, broadcastURL: URL), Error>) -> Void
    ) {
        // Bước 1: Xuất Clean Video
        exportVideo(
            sourceAsset: sourceAsset,
            telemetryLog: telemetryLog,
            streamType: .cleanVideo,
            aspectMode: aspectMode,
            outputURL: cleanOutputURL,
            progressHandler: { p in
                progressHandler(p * 0.5) // 0% -> 50%
            }
        ) { cleanResult in
            switch cleanResult {
            case .success(let cleanURL):
                // Bước 2: Xuất Burn-in Broadcast Video
                self.exportVideo(
                    sourceAsset: sourceAsset,
                    telemetryLog: telemetryLog,
                    streamType: .burnInBroadcast,
                    aspectMode: aspectMode,
                    outputURL: broadcastOutputURL,
                    progressHandler: { p in
                        progressHandler(0.5 + p * 0.5) // 50% -> 100%
                    }
                ) { broadcastResult in
                    switch broadcastResult {
                    case .success(let broadcastURL):
                        completion(.success((cleanURL: cleanURL, broadcastURL: broadcastURL)))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Frame Compositing & Overlay Renderer
    
    private func renderCompositedFrame(
        sourceBuffer: CVPixelBuffer,
        destinationBuffer: CVPixelBuffer,
        streamType: ExportStreamType,
        aspectMode: ExportAspectMode,
        telemetry: RallyTelemetryFrame?
    ) {
        CVPixelBufferLockBaseAddress(destinationBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(destinationBuffer, []) }
        
        let destWidth = CVPixelBufferGetWidth(destinationBuffer)
        let destHeight = CVPixelBufferGetHeight(destinationBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(destinationBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(destinationBuffer) else { return }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        
        guard let context = CGContext(
            data: baseAddress,
            width: destWidth,
            height: destHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return
        }
        
        // 1. Chuyển đổi Source CVPixelBuffer sang CGImage
        CVPixelBufferLockBaseAddress(sourceBuffer, .readOnly)
        guard let sourceBaseAddr = CVPixelBufferGetBaseAddress(sourceBuffer) else {
            CVPixelBufferUnlockBaseAddress(sourceBuffer, .readOnly)
            return
        }
        let srcWidth = CVPixelBufferGetWidth(sourceBuffer)
        let srcHeight = CVPixelBufferGetHeight(sourceBuffer)
        let srcBytesPerRow = CVPixelBufferGetBytesPerRow(sourceBuffer)
        
        let srcContext = CGContext(
            data: sourceBaseAddr,
            width: srcWidth,
            height: srcHeight,
            bitsPerComponent: 8,
            bytesPerRow: srcBytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )
        let sourceCGImage = srcContext?.makeImage()
        CVPixelBufferUnlockBaseAddress(sourceBuffer, .readOnly)
        
        guard let image = sourceCGImage else { return }
        
        // 2. Vẽ Video Frame vào Destination Context theo Aspect Ratio
        if aspectMode == .landscape16x9 {
            // 16:9 Landscape: Phủ toàn bộ khung hình 1920x1080
            context.draw(image, in: CGRect(x: 0, y: 0, width: destWidth, height: destHeight))
        } else {
            // 9:16 Portrait: Smart Center Dynamic Crop
            // Crop tập trung vào trung tâm hoạt động hoặc tâm bóng
            let ballNormX = (telemetry?.ballPositionPixel?.x ?? CGFloat(srcWidth / 2)) / CGFloat(srcWidth)
            let ballNormY = (telemetry?.ballPositionPixel?.y ?? CGFloat(srcHeight / 2)) / CGFloat(srcHeight)
            
            let cropWidth = CGFloat(srcHeight) * (9.0 / 16.0)
            let idealCropX = CGFloat(srcWidth) * ballNormX - (cropWidth / 2.0)
            let cropX = max(0.0, min(idealCropX, CGFloat(srcWidth) - cropWidth))
            
            let cropRect = CGRect(x: cropX, y: 0, width: cropWidth, height: CGFloat(srcHeight))
            if let croppedImage = image.cropping(to: cropRect) {
                context.draw(croppedImage, in: CGRect(x: 0, y: 0, width: destWidth, height: destHeight))
            } else {
                context.draw(image, in: CGRect(x: 0, y: 0, width: destWidth, height: destHeight))
            }
        }
        
        // Nếu là luồng Clean Video Feed -> Dừng lại ở đây, không vẽ đồ họa HUD
        guard streamType == .burnInBroadcast else { return }
        
        // 3. Ghép cứng đồ họa truyền hình (Burn-in Broadcast HUD)
        drawBurnInHUDOverlay(
            context: context,
            canvasSize: CGSize(width: destWidth, height: destHeight),
            aspectMode: aspectMode,
            telemetry: telemetry
        )
    }
    
    // MARK: - Graphics Burn-In Overlay
    
    private func fillRoundedRect(_ rect: CGRect, cornerRadius: CGFloat, in context: CGContext) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath
        context.addPath(path)
        context.fillPath()
    }
    
    private func strokeRoundedRect(_ rect: CGRect, cornerRadius: CGFloat, in context: CGContext) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath
        context.addPath(path)
        context.strokePath()
    }
    
    private func drawBurnInHUDOverlay(
        context: CGContext,
        canvasSize: CGSize,
        aspectMode: ExportAspectMode,
        telemetry: RallyTelemetryFrame?
    ) {
        context.saveGState()
        
        // A. Thanh Trạng Thái Đỉnh (Top Status Bar)
        let topBarRect = CGRect(x: 40, y: canvasSize.height - 110, width: canvasSize.width - 80, height: 70)
        context.setFillColor(UIColor.black.withAlphaComponent(0.75).cgColor)
        fillRoundedRect(topBarRect, cornerRadius: 18, in: context)
        
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.25).cgColor)
        context.setLineWidth(1.5)
        strokeRoundedRect(topBarRect, cornerRadius: 18, in: context)
        
        // Vẽ Text HUD
        let rallyIdx = telemetry?.rallyIndex ?? 1
        let shotCount = telemetry?.shotCount ?? 0
        let score = telemetry?.scoreText ?? "0 - 0 - 2"
        let status = telemetry?.rallyStateText ?? "ĐANG ĐÁNH"
        
        drawText(
            "PICKLEVISION LIVE",
            at: CGPoint(x: 70, y: canvasSize.height - 75),
            fontSize: 22,
            bold: true,
            color: .yellow,
            context: context
        )
        
        drawText(
            "TỶ SỐ: \(score)",
            at: CGPoint(x: 360, y: canvasSize.height - 75),
            fontSize: 20,
            bold: true,
            color: .white,
            context: context
        )
        
        drawText(
            "PHA SỐ: \(rallyIdx)  |  LƯỢT ĐỔI HƯỚNG: \(shotCount)",
            at: CGPoint(x: 580, y: canvasSize.height - 75),
            fontSize: 18,
            bold: false,
            color: .cyan,
            context: context
        )
        
        drawText(
            status,
            at: CGPoint(x: canvasSize.width - 240, y: canvasSize.height - 75),
            fontSize: 18,
            bold: true,
            color: UIColor(red: 0.15, green: 0.88, blue: 0.45, alpha: 1.0),
            context: context
        )
        
        // B. Minimap 2D Sân Pickleball đặt ở góc phải
        let minimapWidth: CGFloat = 220
        let minimapHeight: CGFloat = 340
        let minimapX = canvasSize.width - minimapWidth - 40
        let minimapY = canvasSize.height - minimapHeight - 140
        
        let minimapRect = CGRect(x: minimapX, y: minimapY, width: minimapWidth, height: minimapHeight)
        context.setFillColor(UIColor.black.withAlphaComponent(0.80).cgColor)
        fillRoundedRect(minimapRect, cornerRadius: 16, in: context)
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor)
        strokeRoundedRect(minimapRect, cornerRadius: 16, in: context)
        
        // Nền sân Minimap
        let courtInnerRect = minimapRect.insetBy(dx: 12, dy: 12)
        context.setFillColor(UIColor(red: 0.12, green: 0.28, blue: 0.44, alpha: 1.0).cgColor)
        context.fill(courtInnerRect)
        
        // Vùng Bếp NVZ
        let nvzHeightRatio = CGFloat(CourtDimensions.totalNVZLength / CourtDimensions.length)
        let nvzHeight = courtInnerRect.height * nvzHeightRatio
        let nvzY = courtInnerRect.midY - (nvzHeight / 2.0)
        let nvzRect = CGRect(x: courtInnerRect.minX, y: nvzY, width: courtInnerRect.width, height: nvzHeight)
        context.setFillColor(UIColor(red: 0.16, green: 0.48, blue: 0.38, alpha: 1.0).cgColor)
        context.fill(nvzRect)
        
        // Vạch trắng trên minimap
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.9).cgColor)
        context.setLineWidth(1.5)
        context.stroke(courtInnerRect)
        context.stroke(nvzRect)
        
        // Vị trí cầu thủ trên Minimap
        if let players = telemetry?.playerPositionsM {
            for (pIdx, posM) in players {
                let px = courtInnerRect.minX + (posM.x / CGFloat(CourtDimensions.width)) * courtInnerRect.width
                let py = courtInnerRect.minY + (posM.y / CGFloat(CourtDimensions.length)) * courtInnerRect.height
                
                context.setFillColor(playerColorForIndex(pIdx).cgColor)
                context.fillEllipse(in: CGRect(x: px - 5, y: py - 5, width: 10, height: 10))
                context.strokeEllipse(in: CGRect(x: px - 5, y: py - 5, width: 10, height: 10))
            }
        }
        
        // Vị trí bóng trên Minimap
        if let ballM = telemetry?.ballPositionCourtM {
            let bx = courtInnerRect.minX + (ballM.x / CGFloat(CourtDimensions.width)) * courtInnerRect.width
            let by = courtInnerRect.minY + (ballM.y / CGFloat(CourtDimensions.length)) * courtInnerRect.height
            context.setFillColor(UIColor.yellow.cgColor)
            context.fillEllipse(in: CGRect(x: bx - 4, y: by - 4, width: 8, height: 8))
        }
        
        // C. Thanh Đáy 4 Thẻ Cầu Thủ (Player Metrics Bar)
        let bottomBarRect = CGRect(x: 40, y: 30, width: canvasSize.width - 80, height: 65)
        context.setFillColor(UIColor.black.withAlphaComponent(0.75).cgColor)
        fillRoundedRect(bottomBarRect, cornerRadius: 16, in: context)
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.2).cgColor)
        strokeRoundedRect(bottomBarRect, cornerRadius: 16, in: context)
        
        let cardWidth = (bottomBarRect.width - 50) / 4.0
        let names = ["Tú (Gần)", "Cường (Gần)", "Nam (Xa)", "Thành (Xa)"]
        
        for i in 0..<4 {
            let cardX = bottomBarRect.minX + 10 + CGFloat(i) * (cardWidth + 10)
            let cardRect = CGRect(x: cardX, y: bottomBarRect.minY + 8, width: cardWidth, height: 49)
            
            context.setFillColor(UIColor.white.withAlphaComponent(0.08).cgColor)
            fillRoundedRect(cardRect, cornerRadius: 10, in: context)
            
            drawText(names[i], at: CGPoint(x: cardRect.minX + 8, y: cardRect.maxY - 18), fontSize: 13, bold: true, color: playerColorForIndex(i), context: context)
            drawText("Quãng đường: 18.5 m", at: CGPoint(x: cardRect.minX + 8, y: cardRect.maxY - 36), fontSize: 11, bold: false, color: .white, context: context)
        }
        
        context.restoreGState()
    }
    
    // MARK: - Helpers
    
    private func findTelemetry(for pts: CMTime, in log: [RallyTelemetryFrame]) -> RallyTelemetryFrame? {
        guard !log.isEmpty else { return nil }
        let currentSeconds = CMTimeGetSeconds(pts)
        
        // Tìm frame gần nhất theo thời gian
        var closest = log[0]
        var minDiff = abs(CMTimeGetSeconds(closest.timestamp) - currentSeconds)
        
        for frame in log {
            let diff = abs(CMTimeGetSeconds(frame.timestamp) - currentSeconds)
            if diff < minDiff {
                minDiff = diff
                closest = frame
            }
        }
        return closest
    }
    
    private func playerColorForIndex(_ index: Int) -> UIColor {
        switch index {
        case 0: return UIColor(red: 0.22, green: 0.52, blue: 0.98, alpha: 1.0)
        case 1: return UIColor(red: 0.58, green: 0.38, blue: 0.98, alpha: 1.0)
        case 2: return UIColor(red: 0.98, green: 0.46, blue: 0.12, alpha: 1.0)
        case 3: return UIColor(red: 0.94, green: 0.28, blue: 0.28, alpha: 1.0)
        default: return .white
        }
    }
    
    private func drawText(
        _ text: String,
        at point: CGPoint,
        fontSize: CGFloat,
        bold: Bool,
        color: UIColor,
        context: CGContext
    ) {
        let font = bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)
        
        context.textPosition = point
        CTLineDraw(line, context)
    }
}
