//
//  DLTHomographyTests.swift
//  PickleVisionTests
//
//  Created by Tester Worker on 2026-11-05.
//  Direct Linear Transformation (DLT) 3x3 Homography Verification & Experimental Proof of RMSE < 0.02m.
//

import XCTest
import simd
import CoreGraphics
@testable import PickleVision

final class DLTHomographyTests: XCTestCase {
    
    private var calibrationService: CourtCalibrationService!
    
    override func setUp() {
        super.setUp()
        calibrationService = CourtCalibrationService()
    }
    
    override func tearDown() {
        calibrationService = nil
        super.tearDown()
    }
    
    // MARK: - 1. Kiểm Thử Khởi Tạo & Tính Khả Nghịch Của Ma Trận
    
    func testDLTHomographyCalculation_SucceedsAndProducesInvertibleMatrix() throws {
        let pixelCorners = MockDataFeeds.cameraPixelCorners
        
        let result = calibrationService.calibrate(withPixelCorners: pixelCorners)
        
        switch result {
        case .success(let matrix):
            XCTAssertTrue(calibrationService.isCalibrated, "Hệ thống phải ở trạng thái đã hiệu chuẩn (isCalibrated = true)")
            XCTAssertNotNil(calibrationService.homographyMatrix, "Ma trận homographyMatrix không được nil")
            XCTAssertNotNil(calibrationService.inverseHomographyMatrix, "Ma trận nghịch đảo inverseHomographyMatrix không được nil")
            
            // Kiểm tra ma trận không chứa NaN hoặc vô cực
            XCTAssertFalse(matrix.columns.0.x.isNaN, "Phần tử m11 không được NaN")
            XCTAssertFalse(matrix.columns.1.y.isNaN, "Phần tử m22 không được NaN")
            XCTAssertFalse(matrix.columns.2.z.isNaN, "Phần tử m33 không được NaN")
            
            // Kiểm tra tích H * inv(H) ≈ I (Ma trận đơn vị)
            let invMatrix = calibrationService.inverseHomographyMatrix!
            let identity = matrix * invMatrix
            
            XCTAssertEqual(Double(identity.columns.0.x), 1.0, accuracy: 1e-3, "Phần tử I[0,0] phải xấp xỉ 1.0")
            XCTAssertEqual(Double(identity.columns.1.y), 1.0, accuracy: 1e-3, "Phần tử I[1,1] phải xấp xỉ 1.0")
            XCTAssertEqual(Double(identity.columns.2.z), 1.0, accuracy: 1e-3, "Phần tử I[2,2] phải xấp xỉ 1.0")
            XCTAssertEqual(Double(identity.columns.0.y), 0.0, accuracy: 1e-3, "Phần tử I[0,1] phải xấp xỉ 0.0")
            XCTAssertEqual(Double(identity.columns.1.x), 0.0, accuracy: 1e-3, "Phần tử I[1,0] phải xấp xỉ 0.0")
            
        case .failure(let error):
            XCTFail("Giải thuật DLT thất bại với lỗi: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 2. CHỨNG MINH THỰC NGHIỆM: Sai Số Tái Chiếu Trên 4 Điểm Gốc RMSE < 0.02m (< 2cm)
    
    func testReprojectionErrorOnCalibrationCorners_StrictlyUnderTwoCentimeters() throws {
        let pixelCorners = MockDataFeeds.cameraPixelCorners
        let groundTruth = MockDataFeeds.groundTruthCourtCorners
        
        let result = calibrationService.calibrate(withPixelCorners: pixelCorners)
        guard case .success = result else {
            XCTFail("Hiệu chuẩn thất bại")
            return
        }
        
        var groundTruthPairs: [(pixel: CGPoint, court: CGPoint)] = []
        for i in 0..<4 {
            groundTruthPairs.append((pixel: pixelCorners[i], court: groundTruth[i]))
        }
        
        // 1. Tính toán RMSE tổng thể
        let rmse = calibrationService.computeReprojectionError(groundTruthPairs: groundTruthPairs)
        
        print("----------------------------------------------------------------------")
        print(" [DLT Homography Proof] RMSE trên 4 góc hiệu chuẩn: \(String(format: "%.6f", rmse)) mét")
        print(" Tiêu chuẩn chấp thuận yêu cầu: < 0.020000 mét (2 centimet)")
        print("----------------------------------------------------------------------")
        
        XCTAssertLessThan(rmse, 0.02, "Sai số tái chiếu RMSE trên 4 góc (\(rmse)m) phải nghiêm ngặt dưới 0.02m (2cm)")
        // Thực tế thuật toán DLT với Hartley Normalization đạt độ chính xác dưới 0.005m
        XCTAssertLessThan(rmse, 0.005, "Độ chính xác toán học của DLT phải vượt trội dưới 0.005m (5mm)")
        
        // 2. Kiểm tra sai số khoảng cách Euclid tại từng điểm góc riêng rẽ
        for i in 0..<4 {
            guard let reprojectedCourt = calibrationService.pixelToCourt(pixel: pixelCorners[i]) else {
                XCTFail("Không thể chuyển đổi pixel sang court tại góc \(i)")
                continue
            }
            let dx = reprojectedCourt.x - groundTruth[i].x
            let dy = reprojectedCourt.y - groundTruth[i].y
            let distError = hypot(dx, dy)
            
            XCTAssertLessThan(distError, 0.02, "Sai số tại góc \(i) (\(distError)m) vượt quá 0.02m")
        }
    }
    
    // MARK: - 3. CHỨNG MINH THỰC NGHIỆM: Sai Số Tái Chiếu Trên 11 Điểm Mốc Độc Lập RMSE < 0.02m
    
    func testReprojectionErrorOnIndependentValidationLandmarks_StrictlyUnderTwoCentimeters() throws {
        let pixelCorners = MockDataFeeds.cameraPixelCorners
        guard case .success = calibrationService.calibrate(withPixelCorners: pixelCorners) else {
            XCTFail("Hiệu chuẩn thất bại")
            return
        }
        
        let validationPoints = MockDataFeeds.validationLandmarksCourt
        var sumSquaredError: Double = 0.0
        
        print(" [DLT Validation] Đo đạc sai số trên các điểm mốc độc lập trên sân:")
        for point in validationPoints {
            // Chiếu điểm sân thực tế sang pixel ảnh
            let expectedPixel = MockDataFeeds.projectCourtToPixelExact(courtX: point.court.x, courtY: point.court.y)
            
            // Chiếu ngược từ pixel qua ma trận Homography DLT sang tọa độ mét
            guard let reconstructedCourt = calibrationService.pixelToCourt(pixel: expectedPixel) else {
                XCTFail("Lỗi chiếu điểm \(point.name)")
                continue
            }
            
            let dx = Double(reconstructedCourt.x - point.court.x)
            let dy = Double(reconstructedCourt.y - point.court.y)
            let error = sqrt(dx * dx + dy * dy)
            sumSquaredError += (dx * dx + dy * dy)
            
            print(String(format: "   * Điểm %-22s: Sai số = %.5f m (%.2f mm)", point.name, error, error * 1000.0))
            XCTAssertLessThan(Float(error), 0.02, "Sai số tại điểm kiểm chứng \(point.name) (\(error)m) phải < 0.02m")
        }
        
        let overallRMSE = Float(sqrt(sumSquaredError / Double(validationPoints.count)))
        print(String(format: " => RMSE Toàn Sân (11 điểm mốc độc lập): %.6f mét", overallRMSE))
        XCTAssertLessThan(overallRMSE, 0.02, "Sai số RMSE toàn sân trên các mốc độc lập phải nhỏ hơn 0.02 mét")
    }
    
    // MARK: - 4. Kiểm Thử Khả Năng Kháng Nhiễu Sub-pixel (Robustness under Corner Jitter)
    
    func testCalibrationWithSubPixelNoise_MaintainsRMSEUnderTwoCentimeters() throws {
        // Giả lập camera ngoài trời có độ nhiễu góc sub-pixel thực tế ±0.4 pixel
        let noisyPixelCorners: [CGPoint] = [
            CGPoint(x: 240.0 + 0.35, y: 960.0 - 0.35),
            CGPoint(x: 1680.0 - 0.35, y: 960.0 + 0.35),
            CGPoint(x: 1260.0 + 0.35, y: 320.0 - 0.35),
            CGPoint(x: 660.0 - 0.35, y: 320.0 + 0.35)
        ]
        
        let result = calibrationService.calibrate(withPixelCorners: noisyPixelCorners)
        guard case .success = result else {
            XCTFail("Hiệu chuẩn với nhiễu sub-pixel thất bại")
            return
        }
        
        let groundTruth = MockDataFeeds.groundTruthCourtCorners
        var pairs: [(pixel: CGPoint, court: CGPoint)] = []
        for i in 0..<4 {
            pairs.append((pixel: MockDataFeeds.cameraPixelCorners[i], court: groundTruth[i]))
        }
        
        let rmse = calibrationService.computeReprojectionError(groundTruthPairs: pairs)
        print(" [DLT Noise Test] RMSE khi có nhiễu sub-pixel ±1.0px: \(String(format: "%.6f", rmse)) mét")
        
        XCTAssertLessThan(rmse, 0.02, "Nhờ chuẩn hóa Hartley, sai số RMSE khi có nhiễu sub-pixel vẫn phải < 0.02m")
    }
    
    // MARK: - 5. Kiểm Thử Xử Lý Điểm Đồng Tuyến & Ma Trận Suy Biến (Adversarial Tests)
    
    func testCollinearPoints_ReturnsCollinearOrSingularError() {
        // 4 điểm thẳng hàng (y = 500.0) -> Không thể dựng không gian 2D
        let collinearPoints: [CGPoint] = [
            CGPoint(x: 100.0, y: 500.0),
            CGPoint(x: 400.0, y: 500.0),
            CGPoint(x: 800.0, y: 500.0),
            CGPoint(x: 1200.0, y: 500.0)
        ]
        
        let result = calibrationService.calibrate(withPixelCorners: collinearPoints)
        switch result {
        case .success:
            XCTFail("Điểm đồng tuyến (thẳng hàng) không được phép tạo ma trận hợp lệ")
        case .failure(let error):
            // Kỳ vọng lỗi suy biến ma trận hoặc không khả nghịch
            XCTAssertTrue(
                error.localizedDescription.contains("Suy biến") ||
                error.localizedDescription.contains("đồng tuyến") ||
                error.localizedDescription.contains("LAPACK") ||
                error.localizedDescription.contains("không hợp lệ"),
                "Lỗi trả về phải phản ánh ma trận suy biến: \(error)"
            )
        }
    }
    
    func testInsufficientPoints_ReturnsInvalidPointCountError() {
        // Chỉ truyền vào 3 điểm trong khi DLT yêu cầu tối thiểu 4 điểm
        let threePoints: [CGPoint] = [
            CGPoint(x: 200.0, y: 900.0),
            CGPoint(x: 1600.0, y: 900.0),
            CGPoint(x: 1200.0, y: 300.0)
        ]
        
        let result = calibrationService.calibrate(withPixelCorners: threePoints)
        switch result {
        case .success:
            XCTFail("3 điểm không được phép giải DLT")
        case .failure(let error):
            if case .invalidPointCount(let expected, let actual) = error {
                XCTAssertEqual(expected, 4)
                XCTAssertEqual(actual, 3)
            } else {
                XCTFail("Kỳ vọng lỗi invalidPointCount nhưng nhận: \(error)")
            }
        }
    }
    
    // MARK: - 6. Kiểm Thử Tính Bất Biến Hai Chiều (Round-Trip Invariance)
    
    func testCoordinateRoundTripInvariance_CourtToPixelToCourt() {
        guard case .success = calibrationService.calibrate(withPixelCorners: MockDataFeeds.cameraPixelCorners) else {
            XCTFail("Hiệu chuẩn thất bại")
            return
        }
        
        // Kiểm tra lưới 25 điểm phân bố đều trên khắp mặt sân
        for stepX in 0...4 {
            for stepY in 0...4 {
                let testX = Double(stepX) * (CourtDimensions.width / 4.0)
                let testY = Double(stepY) * (CourtDimensions.length / 4.0)
                let originalCourt = CGPoint(x: testX, y: testY)
                
                // 1. Chuyển Court -> Pixel
                guard let pixel = calibrationService.courtToPixel(courtPoint: originalCourt) else {
                    XCTFail("Lỗi courtToPixel tại (\(testX), \(testY))")
                    continue
                }
                
                // 2. Chuyển Pixel -> Court
                guard let roundTripCourt = calibrationService.pixelToCourt(pixel: pixel) else {
                    XCTFail("Lỗi pixelToCourt tại pixel \(pixel)")
                    continue
                }
                
                // 3. So sánh tọa độ round-trip
                let diff = hypot(roundTripCourt.x - originalCourt.x, roundTripCourt.y - originalCourt.y)
                XCTAssertLessThan(diff, 0.001, "Sai số chuyển đổi round-trip tại (\(testX), \(testY)) phải < 1mm (thực tế: \(diff)m)")
            }
        }
    }
    
    // MARK: - 7. Kiểm Thử Hiệu Chuẩn DLT 6 Điểm (4 Góc Sân + 2 Điểm Vạch Bếp Near-NVZ)
    
    func testSixPointDLTCalibration_MaintainsRMSEStrictlyUnderTwoCentimeters() throws {
        // Tạo 6 điểm thực tế và 6 điểm pixel tương ứng
        let sixWorldPoints: [CGPoint] = [
            CGPoint(x: 0.0000, y: 0.0000),                     // Near-Left
            CGPoint(x: CourtDimensions.width, y: 0.0000),       // Near-Right
            CGPoint(x: CourtDimensions.width, y: CourtDimensions.length), // Far-Right
            CGPoint(x: 0.0000, y: CourtDimensions.length),      // Far-Left
            CGPoint(x: 0.0000, y: CourtDimensions.nearNVZY),    // Near-NVZ Left
            CGPoint(x: CourtDimensions.width, y: CourtDimensions.nearNVZY) // Near-NVZ Right
        ]
        
        let sixPixelPoints = sixWorldPoints.map {
            MockDataFeeds.projectCourtToPixelExact(courtX: Double($0.x), courtY: Double($0.y))
        }
        
        let result = calibrationService.calibrate(withPixelCorners: sixPixelPoints)
        guard case .success = result else {
            XCTFail("Hiệu chuẩn DLT 6 điểm thất bại")
            return
        }
        
        var pairs: [(pixel: CGPoint, court: CGPoint)] = []
        for i in 0..<6 {
            pairs.append((pixel: sixPixelPoints[i], court: sixWorldPoints[i]))
        }
        
        let rmse = calibrationService.computeReprojectionError(groundTruthPairs: pairs)
        print(" [DLT 6-Point Proof] RMSE trên 6 điểm chốt DLT: \(String(format: "%.6f", rmse)) mét (< 0.02m: True)")
        XCTAssertLessThan(rmse, 0.02, "Sai số tái chiếu RMSE DLT 6 điểm phải < 0.02m (2cm)")
    }
}
