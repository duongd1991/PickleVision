//
//  CourtModel.swift
//  PickleVision
//
//  Created by Backend Coder on 2026-11-05.
//  Official USA Pickleball Court Dimensions and Geometric Coordinate Model.
//

import Foundation
import CoreGraphics
import simd

/// Kích thước hình học tiêu chuẩn của sân thi đấu theo USA Pickleball Rulebook
public struct CourtDimensions {
    /// Chiều dài tổng thể của sân: 13.4112 mét (44 feet)
    public static let length: Double = 13.4112
    /// Chiều rộng tổng thể của sân: 6.0960 mét (20 feet)
    public static let width: Double = 6.0960
    
    /// Chiều dài khu vực Bếp (Non-Volley Zone) tính từ mép lưới mỗi bên: 2.1336 mét (7 feet)
    public static let nvzLength: Double = 2.1336
    /// Tổng chiều dài của cả 2 bên bếp: 4.2672 mét (14 feet)
    public static let totalNVZLength: Double = 4.2672
    
    /// Chiều cao lưới tại 2 cột biên (Sideline / Posts): 0.9144 mét (36 inches)
    public static let netHeightPosts: Double = 0.9144
    /// Chiều cao lưới tại tâm sân (Center Net): 0.8636 mét (34 inches)
    public static let netHeightCenter: Double = 0.8636
    
    /// Vị trí trục Y của lưới trên sân (chính giữa sân): 6.7056 mét
    public static let netY: Double = 6.7056
    
    /// Vị trí trục Y của vạch bếp sân gần (Near NVZ Line): 4.5720 mét (6.7056 - 2.1336)
    public static let nearNVZY: Double = 4.5720
    /// Vị trí trục Y của vạch bếp sân xa (Far NVZ Line): 8.8392 mét (6.7056 + 2.1336)
    public static let farNVZY: Double = 8.8392
    
    /// Vị trí trục X của vạch giữa sân (Centerline): 3.0480 mét (6.0960 / 2)
    public static let centerLineX: Double = 3.0480
    
    /// Bề rộng tiêu chuẩn của các vạch kẻ sân: 0.0508 mét (2 inches)
    public static let lineWidth: Double = 0.0508
    /// Bán kính tiêu chuẩn của quả bóng nhựa Pickleball: 0.0370 mét (~3.7 cm, đường kính ~7.4 cm)
    public static let ballRadius: Double = 0.0370
}

/// Điểm trong không gian 2D/3D của sân tính bằng mét
public struct CourtPoint: Codable, Equatable {
    public var x: Double
    public var y: Double
    public var z: Double
    
    public init(x: Double, y: Double, z: Double = 0.0) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    public var cgPoint: CGPoint {
        return CGPoint(x: x, y: y)
    }
    
    public var simd3: SIMD3<Float> {
        return SIMD3<Float>(Float(x), Float(y), Float(z))
    }
    
    public func distance(to other: CourtPoint) -> Double {
        let dx = self.x - other.x
        let dy = self.y - other.y
        let dz = self.z - other.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    }
    
    public func distance2D(to other: CourtPoint) -> Double {
        let dx = self.x - other.x
        let dy = self.y - other.y
        return sqrt(dx * dx + dy * dy)
    }
}

/// Giới hạn hình chữ nhật trên mặt phẳng sân (mét)
public struct CourtBounds: Codable, Equatable {
    public var minX: Double
    public var maxX: Double
    public var minY: Double
    public var maxY: Double
    
    public init(minX: Double, maxX: Double, minY: Double, maxY: Double) {
        self.minX = minX
        self.maxX = maxX
        self.minY = minY
        self.maxY = maxY
    }
    
    public func contains(x: Double, y: Double, margin: Double = 0.0) -> Bool {
        return (x >= minX - margin && x <= maxX + margin &&
                y >= minY - margin && y <= maxY + margin)
    }
    
    public func contains(point: CourtPoint, margin: Double = 0.0) -> Bool {
        return contains(x: point.x, y: point.y, margin: margin)
    }
    
    public func contains(cgPoint: CGPoint, margin: Double = 0.0) -> Bool {
        return contains(x: Double(cgPoint.x), y: Double(cgPoint.y), margin: margin)
    }
}

/// Đa giác hình học biểu diễn các vùng trên sân (Polygon)
public struct CourtPolygon: Equatable {
    public var vertices: [CourtPoint]
    
    public init(vertices: [CourtPoint]) {
        self.vertices = vertices
    }
    
    /// Thuật toán Ray-Casting kiểm tra một điểm có nằm trong đa giác hay không
    public func contains(point: CourtPoint) -> Bool {
        guard vertices.count >= 3 else { return false }
        var inside = false
        var j = vertices.count - 1
        
        for i in 0..<vertices.count {
            let pi = vertices[i]
            let pj = vertices[j]
            
            let intersect = ((pi.y > point.y) != (pj.y > point.y)) &&
                (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y + 1e-12) + pi.x)
            if intersect {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}

/// Danh mục 12 điểm mốc chốt sân (Key Landmarks) theo 2 hệ tọa độ chuẩn
public struct CourtLandmarks {
    
    // MARK: - Hệ Tọa Độ 1: Baseline Corner Origin
    // Gốc (0,0,0) tại góc đáy trái sân gần camera (Near-Left Baseline)
    // X: 0.0 -> 6.096m (Trái sang Phải), Y: 0.0 -> 13.4112m (Gần sang Xa), Z: Hướng lên
    public static let baselineOrigin: [String: CourtPoint] = [
        "P1_NearBLLeft": CourtPoint(x: 0.0000, y: 0.0000, z: 0.0000),
        "P2_NearBLCenter": CourtPoint(x: CourtDimensions.centerLineX, y: 0.0000, z: 0.0000),
        "P3_NearBLRight": CourtPoint(x: CourtDimensions.width, y: 0.0000, z: 0.0000),
        "P4_NearNVZLeft": CourtPoint(x: 0.0000, y: CourtDimensions.nearNVZY, z: 0.0000),
        "P5_NearNVZCenter": CourtPoint(x: CourtDimensions.centerLineX, y: CourtDimensions.nearNVZY, z: 0.0000),
        "P6_NearNVZRight": CourtPoint(x: CourtDimensions.width, y: CourtDimensions.nearNVZY, z: 0.0000),
        "P_NetLeft": CourtPoint(x: 0.0000, y: CourtDimensions.netY, z: CourtDimensions.netHeightPosts),
        "P_NetCenter": CourtPoint(x: CourtDimensions.centerLineX, y: CourtDimensions.netY, z: CourtDimensions.netHeightCenter),
        "P_NetRight": CourtPoint(x: CourtDimensions.width, y: CourtDimensions.netY, z: CourtDimensions.netHeightPosts),
        "P7_FarNVZLeft": CourtPoint(x: 0.0000, y: CourtDimensions.farNVZY, z: 0.0000),
        "P8_FarNVZCenter": CourtPoint(x: CourtDimensions.centerLineX, y: CourtDimensions.farNVZY, z: 0.0000),
        "P9_FarNVZRight": CourtPoint(x: CourtDimensions.width, y: CourtDimensions.farNVZY, z: 0.0000),
        "P10_FarBLLeft": CourtPoint(x: 0.0000, y: CourtDimensions.length, z: 0.0000),
        "P11_FarBLCenter": CourtPoint(x: CourtDimensions.centerLineX, y: CourtDimensions.length, z: 0.0000),
        "P12_FarBLRight": CourtPoint(x: CourtDimensions.width, y: CourtDimensions.length, z: 0.0000)
    ]
    
    // MARK: - Hệ Tọa Độ 2: Center-of-Court Origin
    // Gốc (0,0,0) tại mặt đất ngay dưới tâm lưới
    // X: -3.048m -> +3.048m, Y: -6.7056m -> +6.7056m, Z: Hướng lên
    public static let centerOrigin: [String: CourtPoint] = [
        "P1_NearBLLeft": CourtPoint(x: -CourtDimensions.centerLineX, y: -CourtDimensions.netY, z: 0.0000),
        "P2_NearBLCenter": CourtPoint(x: 0.0000, y: -CourtDimensions.netY, z: 0.0000),
        "P3_NearBLRight": CourtPoint(x: CourtDimensions.centerLineX, y: -CourtDimensions.netY, z: 0.0000),
        "P4_NearNVZLeft": CourtPoint(x: -CourtDimensions.centerLineX, y: -CourtDimensions.nvzLength, z: 0.0000),
        "P5_NearNVZCenter": CourtPoint(x: 0.0000, y: -CourtDimensions.nvzLength, z: 0.0000),
        "P6_NearNVZRight": CourtPoint(x: CourtDimensions.centerLineX, y: -CourtDimensions.nvzLength, z: 0.0000),
        "P_NetLeft": CourtPoint(x: -CourtDimensions.centerLineX, y: 0.0000, z: CourtDimensions.netHeightPosts),
        "P_NetCenter": CourtPoint(x: 0.0000, y: 0.0000, z: CourtDimensions.netHeightCenter),
        "P_NetRight": CourtPoint(x: CourtDimensions.centerLineX, y: 0.0000, z: CourtDimensions.netHeightPosts),
        "P7_FarNVZLeft": CourtPoint(x: -CourtDimensions.centerLineX, y: CourtDimensions.nvzLength, z: 0.0000),
        "P8_FarNVZCenter": CourtPoint(x: 0.0000, y: CourtDimensions.nvzLength, z: 0.0000),
        "P9_FarNVZRight": CourtPoint(x: CourtDimensions.centerLineX, y: CourtDimensions.nvzLength, z: 0.0000),
        "P10_FarBLLeft": CourtPoint(x: -CourtDimensions.centerLineX, y: CourtDimensions.netY, z: 0.0000),
        "P11_FarBLCenter": CourtPoint(x: 0.0000, y: CourtDimensions.netY, z: 0.0000),
        "P12_FarBLRight": CourtPoint(x: CourtDimensions.centerLineX, y: CourtDimensions.netY, z: 0.0000)
    ]
}

/// 4 Ô giao bóng tiêu chuẩn
public enum ServiceBox: String, CaseIterable, Codable {
    case nearLeft   // Sân gần, ô bên trái (Server lẻ hoặc Receiver chẵn)
    case nearRight  // Sân gần, ô bên phải (Server chẵn)
    case farLeft    // Sân xa, ô bên trái (Từ góc nhìn camera: X: 0..3.048, Y: 8.8392..13.4112)
    case farRight   // Sân xa, ô bên phải (Từ góc nhìn camera: X: 3.048..6.096, Y: 8.8392..13.4112)
    
    /// Giới hạn hình học của ô giao bóng (hệ tọa độ Baseline Origin)
    public var bounds: CourtBounds {
        switch self {
        case .nearLeft:
            return CourtBounds(minX: 0.0, maxX: CourtDimensions.centerLineX, minY: 0.0, maxY: CourtDimensions.nearNVZY)
        case .nearRight:
            return CourtBounds(minX: CourtDimensions.centerLineX, maxX: CourtDimensions.width, minY: 0.0, maxY: CourtDimensions.nearNVZY)
        case .farLeft:
            return CourtBounds(minX: 0.0, maxX: CourtDimensions.centerLineX, minY: CourtDimensions.farNVZY, maxY: CourtDimensions.length)
        case .farRight:
            return CourtBounds(minX: CourtDimensions.centerLineX, maxX: CourtDimensions.width, minY: CourtDimensions.farNVZY, maxY: CourtDimensions.length)
        }
    }
    
    /// Ô giao bóng chéo đối diện tương ứng (Luật USA Pickleball: giao chéo sân)
    public var diagonalTarget: ServiceBox {
        switch self {
        case .nearRight: return .farLeft
        case .nearLeft:  return .farRight
        case .farRight:  return .nearLeft
        case .farLeft:   return .nearRight
        }
    }
    
    /// Vạch bếp của ô giao bóng này nằm ở đâu trên trục Y
    public var kitchenLineY: Double {
        switch self {
        case .nearLeft, .nearRight:
            return CourtDimensions.nearNVZY
        case .farLeft, .farRight:
            return CourtDimensions.farNVZY
        }
    }
}

/// Mô hình sân tích hợp ma trận Homography chuyển đổi và các hàm kiểm tra vùng sân
public struct CourtModel: Equatable {
    
    /// Kích thước toàn diện của sân
    public let bounds: CourtBounds
    
    /// Giới hạn vùng Bếp sân gần
    public let nearKitchenBounds: CourtBounds
    /// Giới hạn vùng Bếp sân xa
    public let farKitchenBounds: CourtBounds
    /// Toàn bộ khu vực Bếp (cả 2 bên)
    public let totalKitchenBounds: CourtBounds
    
    /// Ma trận Homography 3x3 chuyển đổi Pixel (u, v, 1) -> Court (X, Y, 1)
    public var homographyMatrix: simd_float3x3
    /// Ma trận nghịch đảo chuyển đổi Court (X, Y, 1) -> Pixel (u, v, 1)
    public var inverseHomographyMatrix: simd_float3x3
    
    public init(homographyMatrix: simd_float3x3 = matrix_identity_float3x3) {
        self.bounds = CourtBounds(
            minX: 0.0,
            maxX: CourtDimensions.width,
            minY: 0.0,
            maxY: CourtDimensions.length
        )
        
        self.nearKitchenBounds = CourtBounds(
            minX: 0.0,
            maxX: CourtDimensions.width,
            minY: CourtDimensions.nearNVZY,
            maxY: CourtDimensions.netY
        )
        
        self.farKitchenBounds = CourtBounds(
            minX: 0.0,
            maxX: CourtDimensions.width,
            minY: CourtDimensions.netY,
            maxY: CourtDimensions.farNVZY
        )
        
        self.totalKitchenBounds = CourtBounds(
            minX: 0.0,
            maxX: CourtDimensions.width,
            minY: CourtDimensions.nearNVZY,
            maxY: CourtDimensions.farNVZY
        )
        
        self.homographyMatrix = homographyMatrix
        self.inverseHomographyMatrix = homographyMatrix.inverse
    }
    
    /// Cập nhật ma trận phối cảnh Homography mới
    public mutating func updateHomography(_ newMatrix: simd_float3x3) {
        self.homographyMatrix = newMatrix
        self.inverseHomographyMatrix = newMatrix.inverse
    }
    
    // MARK: - Chuyển đổi Tọa độ Hình học
    
    /// Chuyển đổi điểm pixel (u, v) trên khung hình camera sang tọa độ mét thực tế (X, Y) trên sân
    public func pixelToCourt(pixel: CGPoint) -> CGPoint? {
        let u = Float(pixel.x)
        let v = Float(pixel.y)
        let p = SIMD3<Float>(u, v, 1.0)
        
        let projected = homographyMatrix * p
        guard abs(projected.z) > 1e-7 else { return nil }
        
        let courtX = CGFloat(projected.x / projected.z)
        let courtY = CGFloat(projected.y / projected.z)
        return CGPoint(x: courtX, y: courtY)
    }
    
    /// Chuyển đổi điểm tọa độ sân (X, Y mét) sang tọa độ pixel (u, v) trên khung hình camera
    public func courtToPixel(courtPoint: CGPoint) -> CGPoint? {
        let x = Float(courtPoint.x)
        let y = Float(courtPoint.y)
        let p = SIMD3<Float>(x, y, 1.0)
        
        let projected = inverseHomographyMatrix * p
        guard abs(projected.z) > 1e-7 else { return nil }
        
        let pixelX = CGFloat(projected.x / projected.z)
        let pixelY = CGFloat(projected.y / projected.z)
        return CGPoint(x: pixelX, y: pixelY)
    }
    
    // MARK: - Kiểm Tra Vùng Hình Học Luật USA Pickleball
    
    /// Kiểm tra điểm có nằm trong phạm vi sân thi đấu (tính cả vạch biên ngoài cùng và bán kính bóng)
    public func isInsideCourt(point: CGPoint, tolerance: Double = CourtDimensions.ballRadius) -> Bool {
        let x = Double(point.x)
        let y = Double(point.y)
        return (x >= -tolerance && x <= CourtDimensions.width + tolerance &&
                y >= -tolerance && y <= CourtDimensions.length + tolerance)
    }
    
    /// Kiểm tra điểm có nằm trong khu vực Bếp (Non-Volley Zone) hay không
    public func isInKitchen(point: CGPoint, tolerance: Double = 0.0) -> Bool {
        let y = Double(point.y)
        return (y >= (CourtDimensions.nearNVZY - tolerance) &&
                y <= (CourtDimensions.farNVZY + tolerance))
    }
    
    /// Kiểm tra điểm chạm bóng có liếm vào vạch Bếp (NVZ Line) hay không
    public func isTouchingKitchenLine(point: CGPoint, ballRadius: Double = CourtDimensions.ballRadius) -> Bool {
        let y = Double(point.y)
        let nearDiff = abs(y - CourtDimensions.nearNVZY)
        let farDiff = abs(y - CourtDimensions.farNVZY)
        
        // Vạch bếp dày 0.0508m, bóng có bán kính 0.037m
        let halfLineWidth = CourtDimensions.lineWidth / 2.0
        let effectiveMargin = halfLineWidth + ballRadius
        
        return nearDiff <= effectiveMargin || farDiff <= effectiveMargin
    }
    
    /// Xác định ô giao bóng mà điểm rơi thuộc về
    public func serviceBox(for point: CGPoint) -> ServiceBox? {
        let courtPt = CourtPoint(x: Double(point.x), y: Double(point.y))
        for box in ServiceBox.allCases {
            if box.bounds.contains(point: courtPt) {
                return box
            }
        }
        return nil
    }
}
