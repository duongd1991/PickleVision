//
//  FullPipelineIntegrationTests.swift
//  PickleVisionTests
//
//  Created by Tester Worker on 2026-11-05.
//  Full Pipeline End-to-End Integration Verification: Calibration -> Player Tracking -> Ball Tracking -> In/Out -> Rally Engine.
//

import XCTest
import CoreGraphics
import CoreMedia
import simd
@testable import PickleVision

final class FullPipelineIntegrationTests: XCTestCase {
    
    private var coordinator: PickleballCVCoordinator!
    private var calibrationService: CourtCalibrationService!
    private var rallyEngine: RallyEngine!
    
    override func setUp() {
        super.setUp()
        calibrationService = CourtCalibrationService()
        rallyEngine = RallyEngine(isDoubles: true)
        
        coordinator = PickleballCVCoordinator(
            courtCalibrationService: calibrationService,
            rallyEngine: rallyEngine
        )
    }
    
    override func tearDown() {
        coordinator = nil
        calibrationService = nil
        rallyEngine = nil
        super.tearDown()
    }
    
    // MARK: - 1. Pipeline Tích Hợp Toàn Diện: Từ Hiệu Chuẩn Sân Đến Kết Thúc Trận Đấu
    
    func testFullMatchRallyLifecycle_EndToEnd() {
        // GIAI ĐOẠN 1: HIỆU CHUẨN SÂN (COURT CALIBRATION)
        let pixelCorners = MockDataFeeds.cameraPixelCorners
        let calibResult = calibrationService.calibrate(withPixelCorners: pixelCorners)
        
        guard case .success(let homography) = calibResult else {
            XCTFail("Bước 1 - Hiệu chuẩn sân thất bại")
            return
        }
        XCTAssertTrue(calibrationService.isCalibrated)
        XCTAssertLessThan(calibrationService.lastReprojectionError, 0.02, "Sai số hiệu chuẩn sân phải < 2cm")
        
        // GIAI ĐOẠN 2: KHỞI TẠO ĐỘI HÌNH 4 CẦU THỦ (PLAYER INITIALIZATION)
        let playerTracker = coordinator.playerTrackerService
        playerTracker.initializeDefaultPlayers(names: ["Tú", "Cường", "Nam", "Thành"])
        XCTAssertEqual(playerTracker.activeTracks.count, 4, "Phải khởi tạo đủ 4 cầu thủ cho trận đánh đôi")
        
        // GIAI ĐOẠN 3: BẮT ĐẦU PHA BÓNG (SERVE START)
        XCTAssertEqual(rallyEngine.state, .waitingForServe)
        rallyEngine.startRally()
        
        guard case .serveInFlight = rallyEngine.state else {
            XCTFail("Sau khi phát bóng, trạng thái phải là serveInFlight")
            return
        }
        XCTAssertEqual(rallyEngine.telemetry.shotCount, 1)
        
        // GIAI ĐOẠN 4: ĐIỂM NẢY GIAO BÓNG HỢP LỆ (LEGAL SERVE BOUNCE)
        // Cú giao bóng chéo sân bay từ Near-Right (X=4.5, Y=1.0) sang Far-Right (X=4.5, Y=10.5)
        // Vượt qua lưới (Y=6.7056m) và vượt qua vạch bếp xa (Y=8.8392m)
        let legalServeBounce = CGPoint(x: 4.5000, y: 10.5000)
        let serveVerdict = coordinator.evaluateBounceVerdict(
            courtPos: legalServeBounce,
            isServe: true,
            targetServiceBox: .farRight
        )
        XCTAssertEqual(serveVerdict, .inBound, "Cú giao bóng chéo sân vào ô Far-Right là IN hợp lệ")
        
        let engineVerdict = rallyEngine.handleBallBounce(at: legalServeBounce, isServe: true)
        XCTAssertEqual(engineVerdict, .inBound)
        
        guard case .inProgress = rallyEngine.state else {
            XCTFail("Sau cú nảy giao bóng hợp lệ, trạng thái phải chuyển sang inProgress")
            return
        }
        
        // GIAI ĐOẠN 5: TUÂN THỦ LUẬT HAI LẦN NẢY (TWO-BOUNCE RULE SATISFACTION)
        // Lần nảy 1: Đội nhận giao bóng (Far Team) để bóng nảy 1 lần rồi mới đánh trả (Return of Serve)
        rallyEngine.registerShotExchange() // Shot 2 (Cú trả giao bóng bay về Near Court)
        
        // Lần nảy 2: Đội giao bóng (Near Team) để bóng nảy 1 lần trên sân mình (Y = 2.0m)
        let thirdShotBounce = CGPoint(x: 3.0480, y: 2.0000)
        let bounce2Verdict = rallyEngine.handleBallBounce(at: thirdShotBounce, isServe: false)
        XCTAssertEqual(bounce2Verdict, .inBound)
        
        rallyEngine.registerShotExchange() // Shot 3 (Cú đánh thứ ba của Near Team bay sang)
        // Từ cú đánh thứ 4 trở đi, cả hai đội được tự do đánh vô-lê hoặc đánh bóng nảy!
        
        // GIAI ĐOẠN 6: CHUỖI CÁC PHA ĐỔI HƯỚNG & CẦU THỦ DI CHUYỂN
        // Mô phỏng 6 cú đánh bóng qua lại qua lưới
        for _ in 1...6 {
            rallyEngine.registerShotExchange()
            
            // Cập nhật vị trí di chuyển cho Cầu thủ 0 (Tú)
            let deltaMove: Float = 0.8 // Di chuyển 0.8m mỗi cú đánh (> 0.05m jitter)
            rallyEngine.recordPlayerMovement(playerId: playerTracker.activeTracks[0].id, deltaDistance: deltaMove)
        }
        
        XCTAssertEqual(rallyEngine.telemetry.shotCount, 9, "Tổng số cú đánh tích lũy trong pha phải là 9")
        
        // GIAI ĐOẠN 7: CÚ ĐÁNH GHI ĐIỂM QUYẾT ĐỊNH (WINNING SMASH IN BOUNDS)
        // Cầu thủ đội giao bóng tung cú đập bóng ghi điểm chạm mép vạch đáy xa đối phương (Y = 13.4112m)
        let winningSmash = CGPoint(x: 4.5000, y: CourtDimensions.length)
        let finalVerdict = coordinator.evaluateBounceVerdict(courtPos: winningSmash, isServe: false)
        XCTAssertEqual(finalVerdict, .inBound, "Cú đập bóng chạm vạch đáy là IN")
        
        rallyEngine.endRally(verdict: finalVerdict)
        
        guard case .ended(let reason, _) = rallyEngine.state else {
            XCTFail("RallyEngine phải chuyển sang trạng thái ended")
            return
        }
        XCTAssertEqual(reason, .manualStop)
        
        // GIAI ĐOẠN 8: XÁC MINH CẬP NHẬT TỶ SỐ VÀ CHỈ SỐ TELEMETRY
        // Vì đội nhận đánh bóng ra ngoài (OUT) -> Đội giao bóng ghi 1 điểm!
        XCTAssertEqual(rallyEngine.currentScore.servingTeamScore, 1, "Đội giao bóng ghi điểm lên 1")
        XCTAssertEqual(rallyEngine.currentScore.serverNumber, 2, "Người giao số 2 tiếp tục giao bóng")
        XCTAssertEqual(rallyEngine.currentScore.displayString, "1 - 0 - 2")
    }
    
    // MARK: - 2. Pipeline Tích Hợp Kịch Bản Lỗi Giao Bóng Vào Bếp (Kitchen Serve Fault Integration)
    
    func testKitchenServeFaultPipeline_EndsRallyAndSwitchesServer() {
        // Khởi động pha giao bóng
        rallyEngine.startRally()
        XCTAssertEqual(rallyEngine.state, .serveInFlight(startTime: 0.0))
        
        // Bóng giao chạm trúng vạch bếp xa (Y = 8.8392m)
        let kitchenFaultPoint = CGPoint(x: 4.5000, y: CourtDimensions.farNVZY)
        let verdict = coordinator.evaluateBounceVerdict(
            courtPos: kitchenFaultPoint,
            isServe: true,
            targetServiceBox: .farRight
        )
        XCTAssertEqual(verdict, .faultKitchenServe, "Cú giao bóng chạm vạch bếp phải là FAULT")
        
        // Xử lý nảy bóng qua RallyEngine
        let engineVerdict = rallyEngine.handleBallBounce(at: kitchenFaultPoint, isServe: true)
        XCTAssertEqual(engineVerdict, .faultKitchenServe)
        
        // Kết thúc pha
        rallyEngine.endRally(verdict: engineVerdict)
        
        guard case .ended(let reason, _) = rallyEngine.state else {
            XCTFail("Pha bóng phải kết thúc ngay khi giao bóng phạm quy")
            return
        }
        XCTAssertEqual(reason, .kitchenFaultServe)
        
        // Ban đầu Server 2 giao bóng, khi thua pha này -> Side-Out ngay sang Đội Xa (Far Team)!
        XCTAssertEqual(rallyEngine.currentScore.servingTeam, .farTeam, "Đổi quyền giao bóng sang Đội Xa")
        XCTAssertEqual(rallyEngine.currentScore.serverNumber, 1, "Đội mới bắt đầu với Server 1")
        XCTAssertEqual(rallyEngine.currentScore.displayString, "0 - 0 - 1")
    }
    
    // MARK: - 3. Pipeline Tích Hợp Lỗi Vô-lê Trong Bếp (Kitchen Volley Integration)
    
    func testKitchenVolleyFaultPipeline() {
        rallyEngine.startRally()
        // Giao bóng và trả giao hợp lệ
        _ = rallyEngine.handleBallBounce(at: CGPoint(x: 4.5, y: 10.5), isServe: true)
        rallyEngine.registerShotExchange()
        
        // Cầu thủ lên lưới thực hiện vô-lê nhưng chân giẫm vào khu vực bếp
        rallyEngine.endRally(verdict: .kitchenVolleyFault)
        
        guard case .ended(let reason, _) = rallyEngine.state else {
            XCTFail("Lỗi Kitchen Volley phải kết thúc pha bóng")
            return
        }
        XCTAssertEqual(reason, .kitchenVolleyFault)
    }
    
    // MARK: - 4. Kiểm Thử Đồng Bộ Dữ Liệu Viễn Trắc (Telemetry Consistency)
    
    func testTelemetryStream_ContainsConsistentMetadata() {
        rallyEngine.startRally()
        _ = rallyEngine.handleBallBounce(at: CGPoint(x: 4.5, y: 10.5), isServe: true)
        
        let telemetry = rallyEngine.telemetry
        XCTAssertEqual(telemetry.rallyIndex, 1)
        XCTAssertEqual(telemetry.shotCount, 1)
        XCTAssertEqual(telemetry.currentScore.displayString, "0 - 0 - 2")
        XCTAssertEqual(telemetry.state.displayText, "ĐANG ĐÁNH")
    }
}
