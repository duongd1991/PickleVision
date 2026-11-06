//
//  PlayerTrackerService.swift
//  PickleVision
//
//  Created by Backend Coder on 2026-11-05.
//  Vision Body Pose Ankle Tracking, ByteTrack Metric Kalman Association, and HSV Torso Re-ID.
//

import Foundation
import Vision
import CoreGraphics
import CoreVideo
import simd

/// Phát hiện người chơi tức thời từ một frame camera
public struct PlayerDetection {
    public let screenGround: CGPoint
    public let screenBBox: CGRect
    public let leftAnkle: CGPoint?
    public let rightAnkle: CGPoint?
    public let courtPosition: CGPoint
    public let confidence: Float
    public let colorHist: [Float]
    
    public init(
        screenGround: CGPoint,
        screenBBox: CGRect,
        leftAnkle: CGPoint?,
        rightAnkle: CGPoint?,
        courtPosition: CGPoint,
        confidence: Float,
        colorHist: [Float]
    ) {
        self.screenGround = screenGround
        self.screenBBox = screenBBox
        self.leftAnkle = leftAnkle
        self.rightAnkle = rightAnkle
        self.courtPosition = courtPosition
        self.confidence = confidence
        self.colorHist = colorHist
    }
}

extension VNHumanBodyPoseObservation {
    /// Bounding box bao quanh toàn bộ các điểm khớp xương được nhận diện
    var boundingBox: CGRect {
        guard let points = try? recognizedPoints(.all) else {
            return CGRect(x: 0, y: 0, width: 0.1, height: 0.1)
        }
        let validLocations = points.values.filter { $0.confidence > 0.1 }.map { $0.location }
        guard !validLocations.isEmpty else {
            return CGRect(x: 0, y: 0, width: 0.1, height: 0.1)
        }
        let minX: CGFloat = validLocations.map { $0.x }.min() ?? 0.0
        let maxX: CGFloat = validLocations.map { $0.x }.max() ?? 1.0
        let minY: CGFloat = validLocations.map { $0.y }.min() ?? 0.0
        let maxY: CGFloat = validLocations.map { $0.y }.max() ?? 1.0
        let w: CGFloat = max(CGFloat(0.05), maxX - minX)
        let h: CGFloat = max(CGFloat(0.05), maxY - minY)
        return CGRect(x: minX, y: minY, width: w, height: h)
    }
}

/// Interface protocol cho module theo dõi cầu thủ
public protocol PlayerTracking: AnyObject {
    func update(with pixelBuffer: CVPixelBuffer, homography: simd_float3x3) -> [PlayerTrack]
    func reset()
}

/// Dịch vụ theo dõi cầu thủ dựa trên Vision Human Body Pose, ByteTrack và Re-ID màu áo
public final class PlayerTrackerService: PlayerTracking, ObservableObject {
    
    // MARK: - Properties
    
    @Published public private(set) var activeTracks: [PlayerTrack] = []
    @Published public private(set) var latestDetections: [PlayerDetection] = []
    
    private let visionHandler = VNSequenceRequestHandler()
    private var lastProcessTimestamp: TimeInterval = 0.0
    private var nextTrackId: Int = 0
    
    // Ngưỡng phát hiện khớp xương cổ chân
    public let minJointConfidence: Float = 0.30
    // Ngưỡng chi phí liên kết ByteTrack (mét trên mặt sân)
    public let maxAssociationDistanceMeters: Float = 4.5
    // Trọng số chi phí không gian vs màu sắc Re-ID
    public let distanceWeight: Float = 0.65
    public let colorWeight: Float = 0.35
    
    public init() {
        initializeDefaultPlayers()
    }
    
    /// Khởi tạo 4 cầu thủ mặc định cho trận đánh đôi
    public func initializeDefaultPlayers(names: [String] = ["A1", "A2", "B1", "B2"]) {
        activeTracks.removeAll()
        
        let initialPositions: [(team: PlayerTeam, pos: CGPoint)] = [
            (.nearTeam, CGPoint(x: 1.5, y: 1.0)),   // Cầu thủ 0: Đội gần bên trái
            (.nearTeam, CGPoint(x: 4.5, y: 1.0)),   // Cầu thủ 1: Đội gần bên phải
            (.farTeam,  CGPoint(x: 1.5, y: 12.4)),  // Cầu thủ 2: Đội xa bên trái
            (.farTeam,  CGPoint(x: 4.5, y: 12.4))   // Cầu thủ 3: Đội xa bên phải
        ]
        
        for i in 0..<min(names.count, initialPositions.count) {
            let track = PlayerTrack(
                playerIndex: i,
                name: names[i],
                team: initialPositions[i].team,
                initialCourtPosition: initialPositions[i].pos
            )
            activeTracks.append(track)
        }
    }
    
    /// Cập nhật tên của một cầu thủ theo index
    public func updatePlayerName(at index: Int, newName: String) {
        guard index >= 0 && index < activeTracks.count else { return }
        activeTracks[index].name = newName
    }
    
    /// Cập nhật danh sách tên của toàn bộ 4 cầu thủ
    public func setAllPlayerNames(_ names: [String]) {
        for i in 0..<min(names.count, activeTracks.count) {
            activeTracks[i].name = names[i]
        }
    }
    
    // MARK: - Main Update Loop
    
    /// Tiếp nhận pixelBuffer từ Camera, nhận diện khớp cổ chân và liên kết bám vết cầu thủ
    public func update(with pixelBuffer: CVPixelBuffer, homography: simd_float3x3) -> [PlayerTrack] {
        let timestamp = ProcessInfo.processInfo.systemUptime
        let dt = lastProcessTimestamp > 0 ? (timestamp - lastProcessTimestamp) : (1.0 / 60.0)
        lastProcessTimestamp = timestamp
        
        let imageWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        
        // 1. Chạy Vision Human Body Pose Request
        let poseRequest = VNDetectHumanBodyPoseRequest()
        poseRequest.revision = VNDetectHumanBodyPoseRequestRevision1
        
        do {
            try visionHandler.perform([poseRequest], on: pixelBuffer)
        } catch {
            print("[PlayerTrackerService] Lỗi chạy Vision Pose: \(error)")
            return activeTracks
        }
        
        guard let observations = poseRequest.results as? [VNHumanBodyPoseObservation], !observations.isEmpty else {
            // Không thấy người trong frame: chạy predict của Kalman để duy trì vị trí mượt
            for track in activeTracks {
                _ = track.kalmanFilter.predict(dt: dt)
            }
            return activeTracks
        }
        
        // 2. Trích xuất Detection: Vị trí tiếp đất cổ chân và Bounding Box
        var detections: [PlayerDetection] = []
        
        for obs in observations {
            let (groundPt, leftAnkle, rightAnkle, conf) = extractGroundContact(
                from: obs,
                imageWidth: imageWidth,
                imageHeight: imageHeight
            )
            
            // Chiếu tọa độ pixel qua ma trận Homography ra mét trên sân
            let u = Float(groundPt.x)
            let v = Float(groundPt.y)
            let p = SIMD3<Float>(u, v, 1.0)
            let proj = homography * p
            
            guard abs(proj.z) > 1e-7 else { continue }
            let courtX = CGFloat(proj.x / proj.z)
            let courtY = CGFloat(proj.y / proj.z)
            let courtPt = CGPoint(x: courtX, y: courtY)
            
            // Lấy Bounding Box chuẩn hóa sang tọa độ pixel
            let bboxNorm = obs.boundingBox
            // Chú ý: Vision sử dụng gốc tọa độ ở góc dưới bên trái (Y hướng lên)
            let bbox = CGRect(
                x: bboxNorm.origin.x * imageWidth,
                y: (1.0 - bboxNorm.origin.y - bboxNorm.height) * imageHeight,
                width: bboxNorm.width * imageWidth,
                height: bboxNorm.height * imageHeight
            )
            
            // Trích xuất histogram màu áo Re-ID từ vùng thân trên
            let colorHist = extractTorsoColorHistogram(
                from: pixelBuffer,
                observation: obs,
                imageWidth: imageWidth,
                imageHeight: imageHeight
            )
            
            detections.append(PlayerDetection(
                screenGround: groundPt,
                screenBBox: bbox,
                leftAnkle: leftAnkle,
                rightAnkle: rightAnkle,
                courtPosition: courtPt,
                confidence: conf,
                colorHist: colorHist
            ))
        }
        
        self.latestDetections = detections
        
        // 3. Liên kết ByteTrack 2 tầng (High-Confidence và Low-Confidence)
        associateDetectionsToTracks(detections: detections, timestamp: timestamp, dt: dt)
        
        return activeTracks
    }
    
    // MARK: - Trích Xuất Khớp Cổ Chân & Tọa Độ Tiếp Đất
    
    private func extractGroundContact(
        from obs: VNHumanBodyPoseObservation,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> (ground: CGPoint, leftAnkle: CGPoint?, rightAnkle: CGPoint?, confidence: Float) {
        var leftAnklePt: CGPoint?
        var rightAnklePt: CGPoint?
        var totalConf: Float = 0.0
        var validJoints = 0
        
        if let leftJoint = try? obs.recognizedPoint(.leftAnkle), leftJoint.confidence >= minJointConfidence {
            let px = leftJoint.location.x * imageWidth
            let py = (1.0 - leftJoint.location.y) * imageHeight
            leftAnklePt = CGPoint(x: px, y: py)
            totalConf += leftJoint.confidence
            validJoints += 1
        }
        
        if let rightJoint = try? obs.recognizedPoint(.rightAnkle), rightJoint.confidence >= minJointConfidence {
            let px = rightJoint.location.x * imageWidth
            let py = (1.0 - rightJoint.location.y) * imageHeight
            rightAnklePt = CGPoint(x: px, y: py)
            totalConf += rightJoint.confidence
            validJoints += 1
        }
        
        let avgConf = validJoints > 0 ? (totalConf / Float(validJoints)) : 0.0
        
        // Tọa độ tiếp đất = Trung điểm 2 cổ chân
        if let left = leftAnklePt, let right = rightAnklePt {
            let midX = (left.x + right.x) / 2.0
            let midY = (left.y + right.y) / 2.0
            return (CGPoint(x: midX, y: midY), leftAnklePt, rightAnklePt, avgConf)
        } else if let left = leftAnklePt {
            return (left, leftAnklePt, nil, avgConf)
        } else if let right = rightAnklePt {
            return (right, nil, rightAnklePt, avgConf)
        } else {
            // Fallback khi cả 2 cổ chân bị che khuất: sử dụng đáy bounding box
            let bbox = obs.boundingBox
            let fallbackX = (bbox.origin.x + bbox.width / 2.0) * imageWidth
            let fallbackY = (1.0 - bbox.origin.y) * imageHeight
            return (CGPoint(x: fallbackX, y: fallbackY), nil, nil, 0.2)
        }
    }
    
    // MARK: - Trích Xuất Histogram Màu Áo Re-ID (HSV Color Histogram)
    
    private func extractTorsoColorHistogram(
        from pixelBuffer: CVPixelBuffer,
        observation: VNHumanBodyPoseObservation,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> [Float] {
        // Trích xuất vùng thân giữa vai và hông
        guard let leftShoulder = try? observation.recognizedPoint(.leftShoulder),
              let rightShoulder = try? observation.recognizedPoint(.rightShoulder),
              let root = (try? observation.recognizedPoint(.root)) ?? (try? observation.recognizedPoint(.leftHip)) else {
            return [Float](repeating: 0.0, count: 24)
        }
        
        let minX = min(leftShoulder.location.x, rightShoulder.location.x) * imageWidth
        let maxX = max(leftShoulder.location.x, rightShoulder.location.x) * imageWidth
        let topY = (1.0 - max(leftShoulder.location.y, rightShoulder.location.y)) * imageHeight
        let bottomY = (1.0 - root.location.y) * imageHeight
        
        let torsoRect = CGRect(
            x: max(0, minX),
            y: max(0, topY),
            width: max(1, maxX - minX),
            height: max(1, bottomY - topY)
        )
        
        // Tạo histogram 16 bin Hue và 8 bin Saturation
        var hist = [Float](repeating: 0.0, count: 24)
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return hist }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bufferPtr = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        let startX = Int(torsoRect.minX)
        let endX = min(Int(torsoRect.maxX), Int(imageWidth) - 1)
        let startY = Int(torsoRect.minY)
        let endY = min(Int(torsoRect.maxY), Int(imageHeight) - 1)
        
        var totalSamples: Float = 0.0
        let step = 4 // Lấy mẫu cách mỗi 4 pixel để tăng tốc độ
        
        for y in stride(from: startY, to: endY, by: step) {
            let rowOffset = y * bytesPerRow
            for x in stride(from: startX, to: endX, by: step) {
                let pixelOffset = rowOffset + x * 4 // BGRA format
                let b = Float(bufferPtr[pixelOffset]) / 255.0
                let g = Float(bufferPtr[pixelOffset + 1]) / 255.0
                let r = Float(bufferPtr[pixelOffset + 2]) / 255.0
                
                // Chuyển RGB sang HSV
                let maxC = max(r, max(g, b))
                let minC = min(r, min(g, b))
                let delta = maxC - minC
                
                var h: Float = 0.0
                let s: Float = maxC > 0 ? (delta / maxC) : 0.0
                
                if delta > 1e-4 {
                    if maxC == r {
                        h = 60.0 * (fmod(((g - b) / delta), 6.0))
                    } else if maxC == g {
                        h = 60.0 * (((b - r) / delta) + 2.0)
                    } else {
                        h = 60.0 * (((r - g) / delta) + 4.0)
                    }
                    if h < 0 { h += 360.0 }
                }
                
                // Phân bổ vào 16 bin Hue (0..360) và 8 bin Saturation (0..1)
                let hueBin = min(15, Int(h / (360.0 / 16.0)))
                let satBin = min(7, Int(s * 8.0))
                
                hist[hueBin] += 1.0
                hist[16 + satBin] += 1.0
                totalSamples += 1.0
            }
        }
        
        // Chuẩn hóa L2 norm
        if totalSamples > 0 {
            var sumSq: Float = 0.0
            for val in hist { sumSq += val * val }
            let norm = sqrt(sumSq)
            if norm > 1e-6 {
                for i in 0..<hist.count { hist[i] /= norm }
            }
        }
        
        return hist
    }
    
    // MARK: - ByteTrack Association (Hungarian / Greedy Matrix)
    
    private func associateDetectionsToTracks(
        detections: [PlayerDetection],
        timestamp: TimeInterval,
        dt: Double
    ) {
        guard !activeTracks.isEmpty else { return }
        
        var matchedDetectionIndices = Set<Int>()
        var matchedTrackIndices = Set<Int>()
        
        // Tính ma trận khoảng cách giữa từng cặp (Track, Detection)
        struct CostPair {
            let trackIndex: Int
            let detectionIndex: Int
            let cost: Float
        }
        
        var costs: [CostPair] = []
        
        for (tIdx, track) in activeTracks.enumerated() {
            // Vị trí dự đoán từ Kalman
            let predictedPos = track.kalmanFilter.predict(dt: dt)
            
            for (dIdx, det) in detections.enumerated() {
                // 1. Khoảng cách không gian sân thực (mét)
                let dx = Float(predictedPos.x - det.courtPosition.x)
                let dy = Float(predictedPos.y - det.courtPosition.y)
                let spatialDist = hypot(dx, dy)
                
                guard spatialDist <= maxAssociationDistanceMeters else { continue }
                
                // 2. Khoảng cách màu sắc Re-ID (Cosine Distance)
                var colorDist: Float = 0.5
                if !track.jerseyColorHistogram.isEmpty && !det.colorHist.isEmpty {
                    var dotProd: Float = 0.0
                    for i in 0..<min(track.jerseyColorHistogram.count, det.colorHist.count) {
                        dotProd += track.jerseyColorHistogram[i] * det.colorHist[i]
                    }
                    colorDist = 1.0 - max(0.0, dotProd)
                }
                
                let combinedCost = spatialDist * distanceWeight + colorDist * colorWeight
                costs.append(CostPair(trackIndex: tIdx, detectionIndex: dIdx, cost: combinedCost))
            }
        }
        
        // Sắp xếp chi phí tăng dần để ghép cặp tham lam (Greedy Match)
        costs.sort { $0.cost < $1.cost }
        
        for pair in costs {
            if !matchedTrackIndices.contains(pair.trackIndex) &&
               !matchedDetectionIndices.contains(pair.detectionIndex) {
                
                matchedTrackIndices.insert(pair.trackIndex)
                matchedDetectionIndices.insert(pair.detectionIndex)
                
                let track = activeTracks[pair.trackIndex]
                let det = detections[pair.detectionIndex]
                
                track.update(
                    rawCourtPosition: det.courtPosition,
                    timestamp: timestamp,
                    boundingBox: det.screenBBox,
                    leftAnkle: det.leftAnkle,
                    rightAnkle: det.rightAnkle,
                    colorHistogram: det.colorHist
                )
            }
        }
        
        // 4. BOOTSTRAP AUTO-ASSOCIATION: Tự động gán người chuyển động mới vào các track chưa khởi tạo
        for (dIdx, det) in detections.enumerated() {
            guard !matchedDetectionIndices.contains(dIdx) else { continue }
            
            // Tìm track chưa từng khởi tạo hoặc mất track trong cùng nửa sân
            let isNearCourt = det.courtPosition.y < 6.7056
            var candidateIndices = isNearCourt ? [0, 1] : [2, 3]
            // Ưu tiên theo bên trái / phải của sân
            if det.courtPosition.x > 3.048 {
                candidateIndices.reverse()
            }
            
            for candidateIdx in candidateIndices {
                guard candidateIdx < activeTracks.count else { continue }
                let candTrack = activeTracks[candidateIdx]
                if !matchedTrackIndices.contains(candidateIdx) && (!candTrack.isInitializedWithDetection || candTrack.confidence < 0.25) {
                    matchedTrackIndices.insert(candidateIdx)
                    matchedDetectionIndices.insert(dIdx)
                    candTrack.forceAssign(
                        rawCourtPosition: det.courtPosition,
                        boundingBox: det.screenBBox,
                        leftAnkle: det.leftAnkle,
                        rightAnkle: det.rightAnkle,
                        colorHistogram: det.colorHist
                    )
                    break
                }
            }
        }
        
        // Với các track chưa ghép được: giữ nguyên vị trí mượt từ Kalman prediction
        for (tIdx, track) in activeTracks.enumerated() {
            if !matchedTrackIndices.contains(tIdx) {
                track.confidence = max(0.0, track.confidence - 0.05)
            } else {
                track.confidence = min(1.0, track.confidence + 0.1)
            }
        }
    }
    
    // MARK: - Thủ Công Gán Cầu Thủ Khi Chạm Vào Màn Hình
    
    /// Gán cầu thủ index vào người đang di chuyển tại tọa độ pixel màn hình
    public func assignPlayer(index: Int, atScreenPoint point: CGPoint) -> Bool {
        guard index >= 0 && index < activeTracks.count else { return false }
        
        var bestDet: PlayerDetection? = nil
        var minDist: CGFloat = 100.0 // Bán kính chạm rộng 100pt
        
        for det in latestDetections {
            let expandedBox = det.screenBBox.insetBy(dx: -30, dy: -30)
            if expandedBox.contains(point) {
                bestDet = det
                break
            }
            let d = hypot(det.screenGround.x - point.x, det.screenGround.y - point.y)
            if d < minDist {
                minDist = d
                bestDet = det
            }
        }
        
        guard let targetDet = bestDet else { return false }
        
        let track = activeTracks[index]
        track.forceAssign(
            rawCourtPosition: targetDet.courtPosition,
            boundingBox: targetDet.screenBBox,
            leftAnkle: targetDet.leftAnkle,
            rightAnkle: targetDet.rightAnkle,
            colorHistogram: targetDet.colorHist
        )
        return true
    }
    
    // MARK: - Reset State
    
    public func reset() {
        self.lastProcessTimestamp = 0.0
        for track in activeTracks {
            track.resetRallyDistance()
        }
    }
    
    /// Cập nhật tên của 4 cầu thủ
    public func updatePlayerNames(_ names: [String]) {
        for (index, name) in names.enumerated() {
            if index < activeTracks.count {
                activeTracks[index].name = name
            }
        }
    }
}
