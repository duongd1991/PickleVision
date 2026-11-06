//
//  CourtCalibrationService.swift
//  PickleVision
//
//  Created by Backend Coder on 2026-11-05.
//  Direct Linear Transformation (DLT) 3x3 Homography Solver with Hartley Normalization via Accelerate LAPACK.
//

import Foundation
import CoreGraphics
import Accelerate
import simd

/// Các lỗi có thể xảy ra trong quá trình hiệu chuẩn sân
public enum CalibrationError: LocalizedError {
    case invalidPointCount(expected: Int, actual: Int)
    case collinearPoints
    case lapackSVDError(info: Int32)
    case singularMatrix
    case reprojectionErrorExceeded(error: Float)
    
    public var errorDescription: String? {
        switch self {
        case .invalidPointCount(let expected, let actual):
            return "Số lượng điểm hiệu chuẩn không hợp lệ: Yêu cầu tối thiểu \(expected), nhận được \(actual)."
        case .collinearPoints:
            return "Các điểm hiệu chuẩn bị đồng tuyến (thẳng hàng), không thể dựng ma trận phối cảnh."
        case .lapackSVDError(let info):
            return "Lỗi phân rã ma trận LAPACK dgesvd_ (mã lỗi: \(info))."
        case .singularMatrix:
            return "Ma trận suy biến (Singular Matrix), không thể tính ma trận nghịch đảo."
        case .reprojectionErrorExceeded(let error):
            return "Sai số tái chiếu vượt quá ngưỡng cho phép (< 0.02m): \(String(format: "%.4f", error))m."
        }
    }
}

/// Interface Protocol cho dịch vụ hiệu chuẩn sân
public protocol CourtCalibrating: AnyObject {
    var homographyMatrix: simd_float3x3? { get }
    var inverseHomographyMatrix: simd_float3x3? { get }
    var isCalibrated: Bool { get }
    func calibrate(withPixelCorners corners: [CGPoint]) -> Result<simd_float3x3, CalibrationError>
    func pixelToCourt(pixel: CGPoint) -> CGPoint?
    func courtToPixel(courtPoint: CGPoint) -> CGPoint?
    func computeReprojectionError(groundTruthPairs: [(pixel: CGPoint, court: CGPoint)]) -> Float
}

/// Dịch vụ giải thuật DLT Homography 3x3 độ chính xác cao (< 0.02 mét)
public final class CourtCalibrationService: CourtCalibrating, ObservableObject {
    
    // MARK: - Properties
    
    @Published public private(set) var homographyMatrix: simd_float3x3?
    @Published public private(set) var inverseHomographyMatrix: simd_float3x3?
    @Published public private(set) var isCalibrated: Bool = false
    @Published public private(set) var lastReprojectionError: Float = 0.0
    
    public init() {}
    
    // MARK: - Public Calibration Method
    
    /// Hiệu chuẩn sân từ các điểm chốt mốc trên khung hình (Hỗ trợ 10 điểm, 6 điểm hoặc 4 điểm):
    /// Thứ tự 10 điểm hiệu chuẩn:
    /// - 4 góc sân ngoài:
    ///   1. Near-Left Baseline: (0.0000, 0.0000)
    ///   2. Near-Right Baseline: (6.0960, 0.0000)
    ///   3. Far-Right Baseline: (6.0960, 13.4112)
    ///   4. Far-Left Baseline: (0.0000, 13.4112)
    /// - 4 điểm vạch bếp (Non-Volley Zone):
    ///   5. Near-Kitchen Left: (0.0000, 4.5720)
    ///   6. Near-Kitchen Right: (6.0960, 4.5720)
    ///   7. Far-Kitchen Right: (6.0960, 8.8392)
    ///   8. Far-Kitchen Left: (0.0000, 8.8392)
    /// - 2 điểm chân cột lưới (Net Posts):
    ///   9. Net Left Post: (0.0000, 6.7056)
    ///   10. Net Right Post: (6.0960, 6.7056)
    public func calibrate(withPixelCorners corners: [CGPoint]) -> Result<simd_float3x3, CalibrationError> {
        guard corners.count >= 4 else {
            return .failure(.invalidPointCount(expected: 4, actual: corners.count))
        }
        
        let worldPoints: [CGPoint]
        let inputPoints: [CGPoint]
        
        if corners.count >= 10 {
            // Hỗ trợ DLT 10 điểm (4 góc sân + 4 điểm vạch bếp + 2 điểm cột lưới)
            worldPoints = [
                CGPoint(x: 0.0000, y: 0.0000),                               // 1. Near-Left Baseline
                CGPoint(x: CourtDimensions.width, y: 0.0000),                 // 2. Near-Right Baseline
                CGPoint(x: CourtDimensions.width, y: CourtDimensions.length), // 3. Far-Right Baseline
                CGPoint(x: 0.0000, y: CourtDimensions.length),                // 4. Far-Left Baseline
                CGPoint(x: 0.0000, y: CourtDimensions.nearNVZY),              // 5. Near-NVZ Left
                CGPoint(x: CourtDimensions.width, y: CourtDimensions.nearNVZY),// 6. Near-NVZ Right
                CGPoint(x: CourtDimensions.width, y: CourtDimensions.farNVZY), // 7. Far-NVZ Right
                CGPoint(x: 0.0000, y: CourtDimensions.farNVZY),               // 8. Far-NVZ Left
                CGPoint(x: 0.0000, y: CourtDimensions.netY),                  // 9. Net Left Post
                CGPoint(x: CourtDimensions.width, y: CourtDimensions.netY)    // 10. Net Right Post
            ]
            inputPoints = Array(corners.prefix(10))
        } else if corners.count >= 6 {
            // Hỗ trợ DLT 6 điểm (4 góc sân + 2 điểm vạch bếp Near-NVZ)
            worldPoints = [
                CGPoint(x: 0.0000, y: 0.0000),                               // Near-Left
                CGPoint(x: CourtDimensions.width, y: 0.0000),                 // Near-Right
                CGPoint(x: CourtDimensions.width, y: CourtDimensions.length), // Far-Right
                CGPoint(x: 0.0000, y: CourtDimensions.length),                // Far-Left
                CGPoint(x: 0.0000, y: CourtDimensions.nearNVZY),              // Near-NVZ Left
                CGPoint(x: CourtDimensions.width, y: CourtDimensions.nearNVZY) // Near-NVZ Right
            ]
            inputPoints = Array(corners.prefix(6))
        } else {
            // 4 điểm góc sân truyền thống
            worldPoints = [
                CGPoint(x: 0.0000, y: 0.0000),                               // Near-Left
                CGPoint(x: CourtDimensions.width, y: 0.0000),                 // Near-Right
                CGPoint(x: CourtDimensions.width, y: CourtDimensions.length), // Far-Right
                CGPoint(x: 0.0000, y: CourtDimensions.length)                // Far-Left
            ]
            inputPoints = Array(corners.prefix(4))
        }
        
        // Giải bài toán DLT với chuẩn hóa Hartley
        return calibrate(imagePoints: inputPoints, worldPoints: worldPoints)
    }
    
    /// Hiệu chuẩn với các điểm tùy chỉnh (imagePoints và worldPoints tương ứng, tối thiểu 4 điểm)
    public func calibrate(
        imagePoints: [CGPoint],
        worldPoints: [CGPoint]
    ) -> Result<simd_float3x3, CalibrationError> {
        guard imagePoints.count >= 4, imagePoints.count == worldPoints.count else {
            return .failure(.invalidPointCount(expected: 4, actual: imagePoints.count))
        }
        
        switch computeHomographyDLT(imagePoints: imagePoints, worldPoints: worldPoints) {
        case .success(let matrix):
            let invMatrix = matrix.inverse
            
            // Kiểm tra ma trận có khả nghịch hợp lệ không
            guard !invMatrix.columns.0.x.isNaN && !invMatrix.columns.1.y.isNaN else {
                return .failure(.singularMatrix)
            }
            
            self.homographyMatrix = matrix
            self.inverseHomographyMatrix = invMatrix
            self.isCalibrated = true
            
            // Tính toán sai số tái chiếu trên các điểm mốc
            var pairs: [(pixel: CGPoint, court: CGPoint)] = []
            for i in 0..<imagePoints.count {
                pairs.append((pixel: imagePoints[i], court: worldPoints[i]))
            }
            let error = computeReprojectionError(groundTruthPairs: pairs)
            self.lastReprojectionError = error
            
            return .success(matrix)
            
        case .failure(let error):
            return .failure(error)
        }
    }
    
    // MARK: - Coordinate Transformations
    
    /// Chuyển đổi tọa độ pixel (u, v) sang tọa độ sân thực tế (X, Y mét)
    public func pixelToCourt(pixel: CGPoint) -> CGPoint? {
        guard let h = homographyMatrix else { return nil }
        let p = SIMD3<Float>(Float(pixel.x), Float(pixel.y), 1.0)
        let projected = h * p
        guard abs(projected.z) > 1e-7 else { return nil }
        return CGPoint(x: CGFloat(projected.x / projected.z), y: CGFloat(projected.y / projected.z))
    }
    
    /// Chuyển đổi tọa độ sân thực tế (X, Y mét) sang tọa độ pixel (u, v) trên khung hình
    public func courtToPixel(courtPoint: CGPoint) -> CGPoint? {
        guard let invH = inverseHomographyMatrix else { return nil }
        let p = SIMD3<Float>(Float(courtPoint.x), Float(courtPoint.y), 1.0)
        let projected = invH * p
        guard abs(projected.z) > 1e-7 else { return nil }
        return CGPoint(x: CGFloat(projected.x / projected.z), y: CGFloat(projected.y / projected.z))
    }
    
    /// Tính sai số tái chiếu Root Mean Square Error (RMSE) tính bằng mét
    public func computeReprojectionError(groundTruthPairs: [(pixel: CGPoint, court: CGPoint)]) -> Float {
        guard !groundTruthPairs.isEmpty else { return 0.0 }
        var sumSquaredError: Double = 0.0
        
        for pair in groundTruthPairs {
            guard let reprojectedCourt = pixelToCourt(pixel: pair.pixel) else {
                return Float.greatestFiniteMagnitude
            }
            let dx = Double(reprojectedCourt.x - pair.court.x)
            let dy = Double(reprojectedCourt.y - pair.court.y)
            sumSquaredError += (dx * dx + dy * dy)
        }
        
        let rmse = sqrt(sumSquaredError / Double(groundTruthPairs.count))
        return Float(rmse)
    }
    
    // MARK: - Thuật Toán DLT SVD với Chuẩn Hóa Hartley (Accelerate LAPACK)
    
    private func computeHomographyDLT(
        imagePoints: [CGPoint],
        worldPoints: [CGPoint]
    ) -> Result<simd_float3x3, CalibrationError> {
        let n = imagePoints.count
        guard n >= 4 else {
            return .failure(.invalidPointCount(expected: 4, actual: n))
        }
        
        // 1. Chuẩn hóa tọa độ Hartley (Isotropic Normalization)
        let (tImg, normImgPts) = normalizePointsHartley(points: imagePoints)
        let (tWorld, normWorldPts) = normalizePointsHartley(points: worldPoints)
        
        // 2. Xây dựng ma trận A kích thước (2N x 9) theo quy ước Column-Major của Fortran/LAPACK
        let mRows = 2 * n
        let nCols = 9
        var aMatrix = [Double](repeating: 0.0, count: mRows * nCols)
        
        for i in 0..<n {
            let u = normImgPts[i].x
            let v = normImgPts[i].y
            let x = normWorldPts[i].x
            let y = normWorldPts[i].y
            
            let r1 = 2 * i
            let r2 = 2 * i + 1
            
            // Hàng r1: [u, v, 1, 0, 0, 0, -x*u, -x*v, -x]
            // Hàng r2: [0, 0, 0, u, v, 1, -y*u, -y*v, -y]
            // Column-major: index = col * mRows + row
            aMatrix[0 * mRows + r1] = u
            aMatrix[1 * mRows + r1] = v
            aMatrix[2 * mRows + r1] = 1.0
            aMatrix[3 * mRows + r1] = 0.0
            aMatrix[4 * mRows + r1] = 0.0
            aMatrix[5 * mRows + r1] = 0.0
            aMatrix[6 * mRows + r1] = -x * u
            aMatrix[7 * mRows + r1] = -x * v
            aMatrix[8 * mRows + r1] = -x
            
            aMatrix[0 * mRows + r2] = 0.0
            aMatrix[1 * mRows + r2] = 0.0
            aMatrix[2 * mRows + r2] = 0.0
            aMatrix[3 * mRows + r2] = u
            aMatrix[4 * mRows + r2] = v
            aMatrix[5 * mRows + r2] = 1.0
            aMatrix[6 * mRows + r2] = -y * u
            aMatrix[7 * mRows + r2] = -y * v
            aMatrix[8 * mRows + r2] = -y
        }
        
        // 3. Phân rã SVD bằng hàm LAPACK dgesvd_ trong Accelerate
        var jobu: Int8 = 78   // 'N'
        var jobvt: Int8 = 65  // 'A' (Tính toàn bộ ma trận V^T 9x9)
        var m = __CLPK_integer(mRows)
        var nInt = __CLPK_integer(nCols)
        var lda = m
        var s = [Double](repeating: 0.0, count: min(nCols, mRows))
        var u = [Double](repeating: 0.0, count: 1)
        var ldu: __CLPK_integer = 1
        var vt = [Double](repeating: 0.0, count: nCols * nCols)
        var ldvt = __CLPK_integer(nCols)
        
        // Workspace Query
        var workQuery = [Double](repeating: 0.0, count: 1)
        var lwork: __CLPK_integer = -1
        var info: __CLPK_integer = 0
        
        dgesvd_(&jobu, &jobvt, &m, &nInt, &aMatrix, &lda, &s, &u, &ldu, &vt, &ldvt, &workQuery, &lwork, &info)
        guard info == 0 else {
            return .failure(.lapackSVDError(info: info))
        }
        
        let optimalLwork = max(1, Int(workQuery[0]))
        var work = [Double](repeating: 0.0, count: optimalLwork)
        lwork = __CLPK_integer(optimalLwork)
        
        dgesvd_(&jobu, &jobvt, &m, &nInt, &aMatrix, &lda, &s, &u, &ldu, &vt, &ldvt, &work, &lwork, &info)
        guard info == 0 else {
            return .failure(.lapackSVDError(info: info))
        }
        
        // Nghiệm tối ưu h chính là vector kỳ dị phải ứng với giá trị kỳ dị nhỏ nhất (hàng cuối cùng của V^T)
        // Trong ma trận V^T (9x9) lưu theo Column-Major:
        // Hàng 8 (chỉ số 0..8): phần tử ở cột c là vt[c * 9 + 8]
        var hNorm = [Double](repeating: 0.0, count: 9)
        for col in 0..<9 {
            hNorm[col] = vt[col * 9 + 8]
        }
        
        // Ma trận H_norm dạng 3x3 (row-major)
        let hNormMat = simd_double3x3(rows: [
            SIMD3<Double>(hNorm[0], hNorm[1], hNorm[2]),
            SIMD3<Double>(hNorm[3], hNorm[4], hNorm[5]),
            SIMD3<Double>(hNorm[6], hNorm[7], hNorm[8])
        ])
        
        // 4. Khử chuẩn hóa: H = inv(T_world) * H_norm * T_img
        let tWorldInv = tWorld.inverse
        let hDouble = tWorldInv * hNormMat * tImg
        
        // Chuẩn hóa sao cho h33 = 1.0 (hoặc nếu h33 rất nhỏ thì chuẩn hóa theo norm)
        let scale = abs(hDouble.columns.2.z) > 1e-9 ? hDouble.columns.2.z : 1.0
        let hNormalized = simd_double3x3(
            hDouble.columns.0 / scale,
            hDouble.columns.1 / scale,
            hDouble.columns.2 / scale
        )
        
        let finalMatrix = simd_float3x3(
            SIMD3<Float>(Float(hNormalized.columns.0.x), Float(hNormalized.columns.0.y), Float(hNormalized.columns.0.z)),
            SIMD3<Float>(Float(hNormalized.columns.1.x), Float(hNormalized.columns.1.y), Float(hNormalized.columns.1.z)),
            SIMD3<Float>(Float(hNormalized.columns.2.x), Float(hNormalized.columns.2.y), Float(hNormalized.columns.2.z))
        )
        
        return .success(finalMatrix)
    }
    
    /// Chuẩn hóa Hartley đưa tập điểm về trọng tâm (0,0) và khoảng cách trung bình đến gốc bằng sqrt(2)
    private func normalizePointsHartley(points: [CGPoint]) -> (simd_double3x3, [SIMD2<Double>]) {
        let count = Double(points.count)
        guard count > 0 else {
            return (matrix_identity_double3x3, [])
        }
        
        var meanX: Double = 0.0
        var meanY: Double = 0.0
        for pt in points {
            meanX += Double(pt.x)
            meanY += Double(pt.y)
        }
        meanX /= count
        meanY /= count
        
        var meanDist: Double = 0.0
        for pt in points {
            let dx = Double(pt.x) - meanX
            let dy = Double(pt.y) - meanY
            meanDist += sqrt(dx * dx + dy * dy)
        }
        meanDist /= count
        
        let scale = sqrt(2.0) / (meanDist > 1e-8 ? meanDist : 1.0)
        
        // Ma trận chuẩn hóa T = [[scale, 0, -scale * meanX],
        //                        [0, scale, -scale * meanY],
        //                        [0, 0, 1]]
        let t = simd_double3x3(rows: [
            SIMD3<Double>(scale, 0.0, -scale * meanX),
            SIMD3<Double>(0.0, scale, -scale * meanY),
            SIMD3<Double>(0.0, 0.0, 1.0)
        ])
        
        let normalizedPoints = points.map { pt in
            SIMD2<Double>(scale * (Double(pt.x) - meanX), scale * (Double(pt.y) - meanY))
        }
        
        return (t, normalizedPoints)
    }
}
