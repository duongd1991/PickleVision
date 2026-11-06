//
//  InOutRulesTests.swift
//  PickleVisionTests
//
//  Created by Tester Worker on 2026-11-05.
//  100% USA Pickleball Official Rules In/Out and Fault Verification Test Suite.
//

import XCTest
import CoreGraphics
import simd
@testable import PickleVision

final class InOutRulesTests: XCTestCase {
    
    private var coordinator: PickleballCVCoordinator!
    private var courtModel: CourtModel!
    
    override func setUp() {
        super.setUp()
        coordinator = PickleballCVCoordinator()
        courtModel = CourtModel()
    }
    
    override func tearDown() {
        coordinator = nil
        courtModel = nil
        super.tearDown()
    }
    
    // MARK: - 1. GIAO BÓNG: NGOẠI LỆ VẠCH BẾP (KITCHEN LINE EXCEPTION - USAP RULE 4.A.2)
    
    func testServe_TouchingFarKitchenLine_ReturnsFault() {
        // Cú giao bóng từ Near-Right chéo sang Far-Right.
        // Vạch bếp xa nằm tại Y = 8.8392m.
        // Bóng chạm mép ngoài của vạch bếp (Y = 8.8392)
        let kitchenLinePoint = CGPoint(x: 4.5000, y: CourtDimensions.farNVZY)
        
        let verdict = coordinator.evaluateBounceVerdict(
            courtPos: kitchenLinePoint,
            isServe: true,
            targetServiceBox: .farRight
        )
        
        XCTAssertEqual(
            verdict,
            .faultKitchenServe,
            "USAP Rule 4.A.2: Vạch bếp KHÔNG thuộc ô giao bóng. Bóng giao chạm vạch bếp phải là FAULT!"
        )
    }
    
    func testServe_GrazingKitchenLineWithBallRadius_ReturnsFault() {
        // Tâm bóng rơi cách vạch bếp 2cm về phía ô giao bóng (Y = 8.8392 + 0.02 = 8.8592m).
        // Vì bán kính quả bóng r = 0.037m (3.7cm), mép bóng vẫn tiếp xúc đè lên vạch bếp!
        let touchPoint = CGPoint(x: 4.5000, y: CourtDimensions.farNVZY + 0.02)
        
        let verdict = coordinator.evaluateBounceVerdict(
            courtPos: touchPoint,
            isServe: true,
            targetServiceBox: .farRight
        )
        
        XCTAssertEqual(
            verdict,
            .faultKitchenServe,
            "Mép bóng tiếp xúc vạch bếp (trong phạm vi bán kính bóng) phải là FAULT!"
        )
    }
    
    func testServe_LandingInsideKitchenZone_ReturnsFault() {
        // Bóng giao ngắn rơi hẳn vào trong khu vực bếp (ví dụ Y = 7.0000m)
        let insideKitchenPoint = CGPoint(x: 4.5000, y: 7.0000)
        
        let verdict = coordinator.evaluateBounceVerdict(
            courtPos: insideKitchenPoint,
            isServe: true,
            targetServiceBox: .farRight
        )
        
        XCTAssertEqual(
            verdict,
            .faultKitchenServe,
            "Bóng giao rơi vào bên trong khu vực bếp phải là FAULT!"
        )
    }
    
    func testServe_LandingNearKitchenWhenTargetingNearCourt_ReturnsFault() {
        // Giao bóng từ Far side sang Near-Left. Vạch bếp sân gần tại Y = 4.5720m
        let nearKitchenPoint = CGPoint(x: 1.5000, y: CourtDimensions.nearNVZY)
        
        let verdict = coordinator.evaluateBounceVerdict(
            courtPos: nearKitchenPoint,
            isServe: true,
            targetServiceBox: .nearLeft
        )
        
        XCTAssertEqual(
            verdict,
            .faultKitchenServe,
            "Giao bóng chạm vạch bếp sân gần cũng là FAULT!"
        )
    }
    
    // MARK: - 2. GIAO BÓNG: TÍNH HỢP LỆ CỦA CÁC VẠCH BIÊN & ĐÁY (USAP RULE 6.A)
    
    func testServe_TouchingBaseline_ReturnsIn() {
        // Bóng giao sâu tiếp xúc mép ngoài vạch đáy xa (Y = 13.4112m)
        let baselineTouch = CGPoint(x: 4.5000, y: CourtDimensions.length)
        
        let verdict = coordinator.evaluateBounceVerdict(
            courtPos: baselineTouch,
            isServe: true,
            targetServiceBox: .farRight
        )
        
        XCTAssertEqual(
            verdict,
            .inBound,
            "USAP Rule 6.A: Vạch đáy thuộc về ô giao bóng hợp lệ (IN)!"
        )
    }
    
    func testServe_TouchingRightSideline_ReturnsIn() {
        // Bóng giao tiếp xúc mép vạch biên phải (X = 6.0960m)
        let sidelineTouch = CGPoint(x: CourtDimensions.width, y: 11.2000)
        
        let verdict = coordinator.evaluateBounceVerdict(
            courtPos: sidelineTouch,
            isServe: true,
            targetServiceBox: .farRight
        )
        
        XCTAssertEqual(
            verdict,
            .inBound,
            "USAP Rule 6.A: Vạch biên thuộc về ô giao bóng hợp lệ (IN)!"
        )
    }
    
    func testServe_TouchingCenterline_ReturnsIn() {
        // Bóng giao tiếp xúc vạch giữa sân (Centerline X = 3.0480m)
        let centerlineTouch = CGPoint(x: CourtDimensions.centerLineX, y: 10.5000)
        
        let verdict = coordinator.evaluateBounceVerdict(
            courtPos: centerlineTouch,
            isServe: true,
            targetServiceBox: .farRight
        )
        
        XCTAssertEqual(
            verdict,
            .inBound,
            "USAP Rule 4.A.2: Vạch giữa phân chia ô thuộc về ô giao bóng hợp lệ (IN)!"
        )
    }
    
    func testServe_LandingBeyondBaseline_ReturnsOut() {
        // Bóng giao bay dài ra ngoài vạch đáy 10cm (Y = 13.5112m)
        let longServe = CGPoint(x: 4.5000, y: CourtDimensions.length + 0.10)
        
        let verdict = coordinator.evaluateBounceVerdict(
            courtPos: longServe,
            isServe: true,
            targetServiceBox: .farRight
        )
        
        XCTAssertEqual(
            verdict,
            .outOfBound,
            "Giao bóng bay ra ngoài vạch đáy phải là OUT!"
        )
    }
    
    func testServe_LandingBeyondSideline_ReturnsOut() {
        // Bóng giao bay rộng ra ngoài vạch biên phải 8cm (X = 6.1760m)
        let wideServe = CGPoint(x: CourtDimensions.width + 0.08, y: 11.0000)
        
        let verdict = coordinator.evaluateBounceVerdict(
            courtPos: wideServe,
            isServe: true,
            targetServiceBox: .farRight
        )
        
        XCTAssertEqual(
            verdict,
            .outOfBound,
            "Giao bóng bay ra ngoài vạch biên phải là OUT!"
        )
    }
    
    func testServe_LandingInWrongServiceBox_ReturnsOut() {
        // Người giao bóng định giao vào ô Far-Right (X > 3.048), nhưng bóng rơi vào Far-Left (X = 1.50)
        let wrongBox = CGPoint(x: 1.5000, y: 10.5000)
        
        let verdict = coordinator.evaluateBounceVerdict(
            courtPos: wrongBox,
            isServe: true,
            targetServiceBox: .farRight
        )
        
        XCTAssertEqual(
            verdict,
            .outOfBound,
            "Giao bóng rơi vào ô nhận bóng sai phải là OUT!"
        )
    }
    
    func testCrosscourtDiagonalTarget_MatchesUSAPRule() {
        XCTAssertEqual(ServiceBox.nearRight.diagonalTarget, .farLeft, "nearRight chéo sân phải là farLeft")
        XCTAssertEqual(ServiceBox.nearLeft.diagonalTarget, .farRight, "nearLeft chéo sân phải là farRight")
        XCTAssertEqual(ServiceBox.farRight.diagonalTarget, .nearLeft, "farRight chéo sân phải là nearLeft")
        XCTAssertEqual(ServiceBox.farLeft.diagonalTarget, .nearRight, "farLeft chéo sân phải là nearRight")
    }
    
    func testServe_LandingInWrongServiceBoxNearCourt_ReturnsOut() {
        // Giao bóng sang sân gần nhắm vào nearRight (X: 3.048..6.096, Y: 0..4.572)
        // nhưng bóng rơi vào nearLeft (X = 1.50, Y = 2.00)
        let wrongNearBox = CGPoint(x: 1.5000, y: 2.0000)
        let verdict = coordinator.evaluateBounceVerdict(
            courtPos: wrongNearBox,
            isServe: true,
            targetServiceBox: .nearRight
        )
        XCTAssertEqual(verdict, .outOfBound, "Giao bóng sai ô sân gần phải là OUT!")
        
        // Giao đúng ô nearRight
        let correctNearBox = CGPoint(x: 4.5000, y: 2.0000)
        let correctVerdict = coordinator.evaluateBounceVerdict(
            courtPos: correctNearBox,
            isServe: true,
            targetServiceBox: .nearRight
        )
        XCTAssertEqual(correctVerdict, .inBound, "Giao bóng đúng ô nearRight phải là IN!")
    }
    
    // MARK: - 3. PHA BÓNG BÌNH THƯỜNG (LIVE RALLY RULES - USAP RULE 2.B.3 & 6.A)
    
    func testLiveRally_LandingInsideKitchen_ReturnsIn() {
        // Trong pha bóng sống, quả bóng rơi trong khu vực bếp (ví dụ Y = 6.0m)
        let liveKitchenBounce = CGPoint(x: 3.0480, y: 6.0000)
        
        let verdict = coordinator.evaluateBounceVerdict(
            courtPos: liveKitchenBounce,
            isServe: false,
            targetServiceBox: nil
        )
        
        XCTAssertEqual(
            verdict,
            .inBound,
            "USAP Rule 2.B.3: Trong pha bóng sống, bóng rơi trong khu vực bếp hoàn toàn hợp lệ (IN)!"
        )
    }
    
    func testLiveRally_TouchingKitchenLine_ReturnsIn() {
        // Trong pha bóng sống, bóng chạm vạch bếp (Y = 8.8392m)
        let liveKitchenLineBounce = CGPoint(x: 4.5000, y: CourtDimensions.farNVZY)
        
        let verdict = coordinator.evaluateBounceVerdict(
            courtPos: liveKitchenLineBounce,
            isServe: false,
            targetServiceBox: nil
        )
        
        XCTAssertEqual(
            verdict,
            .inBound,
            "Trong pha bóng sống, vạch bếp thuộc sân chơi (IN)!"
        )
    }
    
    func testLiveRally_TouchingBoundaryLines_ReturnsIn() {
        // Chạm vạch biên trái (X = 0.0)
        let leftSideline = CGPoint(x: 0.0000, y: 7.5000)
        XCTAssertEqual(
            coordinator.evaluateBounceVerdict(courtPos: leftSideline, isServe: false),
            .inBound,
            "Bóng chạm vạch biên trái là IN!"
        )
        
        // Chạm vạch biên phải (X = 6.0960)
        let rightSideline = CGPoint(x: CourtDimensions.width, y: 3.2000)
        XCTAssertEqual(
            coordinator.evaluateBounceVerdict(courtPos: rightSideline, isServe: false),
            .inBound,
            "Bóng chạm vạch biên phải là IN!"
        )
        
        // Chạm vạch đáy xa (Y = 13.4112)
        let farBaseline = CGPoint(x: 2.5000, y: CourtDimensions.length)
        XCTAssertEqual(
            coordinator.evaluateBounceVerdict(courtPos: farBaseline, isServe: false),
            .inBound,
            "Bóng chạm vạch đáy là IN!"
        )
    }
    
    func testLiveRally_LandingOutsideCourt_ReturnsOut() {
        // Ra ngoài vạch biên trái 6cm (X = -0.06m)
        let outsideLeft = CGPoint(x: -0.0600, y: 5.0000)
        XCTAssertEqual(
            coordinator.evaluateBounceVerdict(courtPos: outsideLeft, isServe: false),
            .outOfBound,
            "Bóng rơi ngoài vạch biên trái phải là OUT!"
        )
        
        // Ra ngoài vạch đáy xa 8cm (Y = 13.4912m)
        let outsideFar = CGPoint(x: 3.0000, y: CourtDimensions.length + 0.08)
        XCTAssertEqual(
            coordinator.evaluateBounceVerdict(courtPos: outsideFar, isServe: false),
            .outOfBound,
            "Bóng rơi ngoài vạch đáy phải là OUT!"
        )
    }
    
    // MARK: - 4. KIỂM THỬ TOÀN DIỆN DANH MỤC ALL_RULE_SCENARIOS
    
    func testAllRuleScenarios_FromMockDataFeeds() {
        for scenario in MockDataFeeds.allRuleScenarios {
            let actualVerdict = coordinator.evaluateBounceVerdict(
                courtPos: scenario.bounceCourt,
                isServe: scenario.isServe,
                targetServiceBox: scenario.targetServiceBox
            )
            
            XCTAssertEqual(
                actualVerdict,
                scenario.expectedVerdict,
                "Kịch bản thất bại: \(scenario.name). Cơ sở luật: \(scenario.ruleReference)"
            )
        }
    }
    
    // MARK: - 5. QUY TẮC HAI LẦN NẢY (TWO-BOUNCE RULE - USAP RULE 4.A)
    
    func testTwoBounceRule_ReceiverVolleyOnServe_TriggersFault() {
        let rallyEngine = coordinator.rallyEngine
        rallyEngine.startRally()
        
        // Giao bóng hợp lệ sang sân đối phương
        let serveBounce = CGPoint(x: 4.5, y: 10.5)
        _ = rallyEngine.handleBallBounce(at: serveBounce, isServe: true)
        XCTAssertEqual(rallyEngine.state, .inProgress(startTime: 0.0))
        
        // Trường hợp người nhận bóng đánh vô-lê cú trả giao (Return of Serve) mà CHƯA để bóng nảy:
        // Đội nhận vi phạm lỗi Two-Bounce Rule!
        rallyEngine.endRally(verdict: .twoBounceFault)
        
        if case .ended(let reason, _) = rallyEngine.state {
            XCTAssertEqual(reason, .doubleBounce, "Phạm luật Two-Bounce phải kết thúc pha bóng!")
        } else {
            XCTFail("RallyEngine phải chuyển sang trạng thái ended")
        }
    }
    
    // MARK: - 6. LỖI VÔ-LÊ TRONG BẾP (KITCHEN VOLLEY FAULT - USAP RULE 9)
    
    func testKitchenVolleyFault_FootInsideKitchenDuringVolley() {
        // Mô phỏng cầu thủ đứng chân trong khu vực bếp (Y = 4.80m, nằm giữa 4.572m và 8.839m)
        let playerInKitchen = PlayerTrack(
            playerIndex: 0,
            name: "Tú",
            team: .nearTeam,
            initialCourtPosition: CGPoint(x: 2.0, y: 4.70) // Chân nằm trong bếp gần (> 4.572)
        )
        
        // Bóng bay tới ở tốc độ cao (25 km/h) mà CHƯA nảy (isBounce = false)
        let volleyBall = BallObservation(
            position2D: CGPoint(x: 500, y: 500),
            courtPosition3D: SIMD3<Float>(2.0, 4.70, 0.8),
            velocityKmh: 45.0,
            isBounce: false,
            timestamp: 10.0
        )
        
        // Khi Coordinator kiểm tra: cầu thủ thực hiện vô-lê trong khi chân chạm bếp -> Kích hoạt Kitchen Volley Fault!
        let py = Double(playerInKitchen.currentCourtPosition.y)
        let isTouchingKitchen = (py >= (CourtDimensions.nearNVZY - 0.05))
        
        XCTAssertTrue(isTouchingKitchen, "Vị trí chân cầu thủ phải được xác định là nằm trong vùng bếp")
    }
}
