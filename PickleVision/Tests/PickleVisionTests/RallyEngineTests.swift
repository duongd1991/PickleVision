//
//  RallyEngineTests.swift
//  PickleVisionTests
//
//  Created by Tester Worker on 2026-11-05.
//  Rally Engine State Machine Transitions, Shot Exchanges, Duration and Side-Out Scoring Verification.
//

import XCTest
import CoreGraphics
@testable import PickleVision

final class RallyEngineTests: XCTestCase {
    
    private var rallyEngine: RallyEngine!
    
    override func setUp() {
        super.setUp()
        rallyEngine = RallyEngine(isDoubles: true)
    }
    
    override func tearDown() {
        rallyEngine = nil
        super.tearDown()
    }
    
    // MARK: - 1. Kiểm Thử Trạng Thái Ban Đầu & Khởi Động Trận Đấu
    
    func testInitialState_IsWaitingForServe() {
        XCTAssertEqual(rallyEngine.state, .waitingForServe, "Trạng thái ban đầu phải là waitingForServe")
        XCTAssertEqual(rallyEngine.telemetry.rallyIndex, 1, "Pha bóng đầu tiên là Pha 1")
        XCTAssertEqual(rallyEngine.telemetry.shotCount, 0, "Số cú đánh ban đầu phải = 0")
        XCTAssertEqual(rallyEngine.telemetry.rallyDuration, 0.0, "Thời gian pha ban đầu phải = 0.0s")
        XCTAssertEqual(rallyEngine.telemetry.effectivePlayTime, 0.0, "Thời gian chơi tích lũy = 0.0s")
        
        // Thể thức đánh đôi bắt đầu ở tỷ số 0-0-2
        XCTAssertEqual(rallyEngine.currentScore.servingTeamScore, 0)
        XCTAssertEqual(rallyEngine.currentScore.receivingTeamScore, 0)
        XCTAssertEqual(rallyEngine.currentScore.serverNumber, 2, "Đánh đôi bắt đầu ở người giao số 2 (0-0-2)")
        XCTAssertEqual(rallyEngine.currentScore.displayString, "0 - 0 - 2")
    }
    
    // MARK: - 2. Chuyển Đổi Trạng Thái: WAITING -> SERVE_IN_FLIGHT -> IN_PROGRESS -> ENDED
    
    func testRallyStateTransitions_FullLifecycle() {
        // Bước 1: Người giao bóng vung vợt -> startRally()
        rallyEngine.startRally()
        
        guard case .serveInFlight = rallyEngine.state else {
            XCTFail("Sau khi startRally(), trạng thái phải là serveInFlight")
            return
        }
        XCTAssertTrue(rallyEngine.state.isLive, "serveInFlight là trạng thái bóng sống (isLive = true)")
        XCTAssertEqual(rallyEngine.telemetry.shotCount, 1, "Cú giao bóng tính là cú đánh đầu tiên (shotCount = 1)")
        
        // Bước 2: Bóng giao nảy hợp lệ vào ô đối phương (ví dụ X=4.5, Y=10.5)
        let legalServeBounce = CGPoint(x: 4.5000, y: 10.5000)
        let verdict = rallyEngine.handleBallBounce(at: legalServeBounce, isServe: true)
        
        XCTAssertEqual(verdict, .inBound, "Điểm nảy giao bóng hợp lệ")
        guard case .inProgress = rallyEngine.state else {
            XCTFail("Sau cú nảy giao bóng hợp lệ, trạng thái phải chuyển sang inProgress")
            return
        }
        XCTAssertEqual(rallyEngine.state.displayText, "ĐANG ĐÁNH")
        
        // Bước 3: Đổi hướng đánh bóng qua lại qua lưới (Shot Exchanges)
        for _ in 1...6 {
            rallyEngine.registerShotExchange()
        }
        XCTAssertEqual(rallyEngine.telemetry.shotCount, 7, "1 cú giao + 6 lượt đổi hướng = 7 cú đánh")
        
        // Bước 4: Pha bóng kết thúc do bóng ra ngoài (OUT)
        rallyEngine.endRally(verdict: .outOfBound)
        
        guard case .ended(let reason, _) = rallyEngine.state else {
            XCTFail("Sau endRally(), trạng thái phải là ended")
            return
        }
        XCTAssertEqual(reason, .ballOut, "Lý do kết thúc phải là ballOut")
        XCTAssertFalse(rallyEngine.state.isLive, "Trạng thái ended không còn là bóng sống")
        XCTAssertGreaterThan(rallyEngine.telemetry.effectivePlayTime, 0.0, "Thời gian chơi thực tế phải được tích lũy")
    }
    
    // MARK: - 3. Lỗi Giao Vào Bếp Kết Thúc Pha Ngay Lập Tức
    
    func testIllegalServeBounce_TransitionsDirectlyToEnded() {
        rallyEngine.startRally()
        
        // Bóng giao rơi trúng vạch bếp xa (Y = 8.8392)
        let faultBounce = CGPoint(x: 4.5, y: CourtDimensions.farNVZY)
        let verdict = rallyEngine.handleBallBounce(at: faultBounce, isServe: true)
        
        XCTAssertEqual(verdict, .faultKitchenServe, "Bóng giao chạm vạch bếp phải trả về faultKitchenServe")
        
        // Kết thúc pha bóng ngay lập tức
        rallyEngine.endRally(verdict: verdict)
        
        guard case .ended(let reason, _) = rallyEngine.state else {
            XCTFail("Pha bóng giao lỗi bếp phải chuyển sang trạng thái ended")
            return
        }
        XCTAssertEqual(reason, .kitchenFaultServe, "Lý do kết thúc phải là kitchenFaultServe")
    }
    
    // MARK: - 4. Kiểm Thử Bóng Nảy 2 Lần Trên Cùng Một Nửa Sân (Double Bounce Fault)
    
    func testDoubleBounceOnSameSide_TriggersTwoBounceFault() {
        rallyEngine.startRally()
        // Nảy lần 1 hợp lệ bên sân xa (Y = 10.5m)
        _ = rallyEngine.handleBallBounce(at: CGPoint(x: 4.5, y: 10.5), isServe: true)
        XCTAssertEqual(rallyEngine.state, .inProgress(startTime: 0.0))
        
        // Nảy lần 2 tiếp tục rơi bên sân xa (Y = 11.2m) do đối thủ không đỡ được bóng
        let secondBounceVerdict = rallyEngine.handleBallBounce(at: CGPoint(x: 4.2, y: 11.2), isServe: false)
        
        XCTAssertEqual(
            secondBounceVerdict,
            .twoBounceFault,
            "Bóng nảy 2 lần liên tiếp trên cùng một nửa sân phải bị xử phạt lỗi Double Bounce!"
        )
    }
    
    // MARK: - 5. Kiểm Thử Thể Thức Tính Điểm Đánh Đôi Side-Out (Doubles Scoring Engine)
    
    func testDoublesSideOutScoring_CompleteRotation() {
        // Trận đấu bắt đầu ở 0-0-2 (Server 2 giao bóng đầu trận)
        XCTAssertEqual(rallyEngine.currentScore.displayString, "0 - 0 - 2")
        
        // Tình huống 1: Đội giao bóng thua pha bóng đầu tiên
        // Vì bắt đầu trận ở Server 2, mất pha này là Side-Out ngay sang đối phương!
        rallyEngine.startRally()
        rallyEngine.endRally(verdict: .outOfBound)
        
        XCTAssertEqual(rallyEngine.currentScore.servingTeam, .farTeam, "Quyền giao bóng chuyển sang Đội Xa (Far Team)")
        XCTAssertEqual(rallyEngine.currentScore.serverNumber, 1, "Đội mới bắt đầu với người giao số 1")
        XCTAssertEqual(rallyEngine.currentScore.displayString, "0 - 0 - 1")
        
        // Tình huống 2: Đội Xa giao bóng và THẮNG pha bóng
        rallyEngine.prepareNextRally()
        rallyEngine.startRally()
        rallyEngine.endRally(verdict: .inBound) // Thắng điểm
        
        XCTAssertEqual(rallyEngine.currentScore.servingTeamScore, 1, "Đội giao ghi được 1 điểm")
        XCTAssertEqual(rallyEngine.currentScore.serverNumber, 1, "Vẫn là người giao số 1")
        XCTAssertEqual(rallyEngine.currentScore.displayString, "1 - 0 - 1")
        
        // Tình huống 3: Server 1 của Đội Xa THUA pha bóng tiếp theo
        // Điểm số giữ nguyên 1-0, quyền giao bóng chuyển sang Server 2 của Đội Xa
        rallyEngine.prepareNextRally()
        rallyEngine.startRally()
        rallyEngine.endRally(verdict: .outOfBound)
        
        XCTAssertEqual(rallyEngine.currentScore.servingTeam, .farTeam, "Vẫn là Đội Xa giao bóng")
        XCTAssertEqual(rallyEngine.currentScore.serverNumber, 2, "Chuyển sang người giao số 2 của Đội Xa")
        XCTAssertEqual(rallyEngine.currentScore.displayString, "1 - 0 - 2")
        
        // Tình huống 4: Server 2 của Đội Xa THUA pha bóng
        // Cả 2 người đã mất lượt -> Side-Out sang Đội Gần (Near Team)!
        // Điểm số đổi góc nhìn: Đội Gần đang có 0 điểm, Đội Xa có 1 điểm -> "0 - 1 - 1"
        rallyEngine.prepareNextRally()
        rallyEngine.startRally()
        rallyEngine.endRally(verdict: .outOfBound)
        
        XCTAssertEqual(rallyEngine.currentScore.servingTeam, .nearTeam, "Quyền giao bóng quay về Đội Gần")
        XCTAssertEqual(rallyEngine.currentScore.servingTeamScore, 0)
        XCTAssertEqual(rallyEngine.currentScore.receivingTeamScore, 1)
        XCTAssertEqual(rallyEngine.currentScore.serverNumber, 1)
        XCTAssertEqual(rallyEngine.currentScore.displayString, "0 - 1 - 1")
    }
    
    // MARK: - 6. Kiểm Thử Thể Thức Tính Điểm Đánh Đơn (Singles Scoring)
    
    func testSinglesSideOutScoring() {
        let singlesEngine = RallyEngine(isDoubles: false)
        XCTAssertEqual(singlesEngine.currentScore.displayString, "0 - 0")
        
        // Người giao bóng thắng pha bóng
        singlesEngine.startRally()
        singlesEngine.endRally(verdict: .inBound)
        XCTAssertEqual(singlesEngine.currentScore.displayString, "1 - 0")
        
        // Người giao bóng thua pha bóng tiếp theo -> Side-out ngay lập tức
        singlesEngine.prepareNextRally()
        singlesEngine.startRally()
        singlesEngine.endRally(verdict: .outOfBound)
        
        XCTAssertEqual(singlesEngine.currentScore.servingTeam, .farTeam)
        XCTAssertEqual(singlesEngine.currentScore.displayString, "0 - 1", "Đổi giao bóng, tỷ số từ góc nhìn server mới là 0 - 1")
    }
    
    // MARK: - 7. Kiểm Thử Reset Trận Đấu
    
    func testResetMatch_RestoresAllInitialParameters() {
        rallyEngine.startRally()
        rallyEngine.endRally(verdict: .inBound)
        rallyEngine.prepareNextRally()
        rallyEngine.startRally()
        rallyEngine.endRally(verdict: .outOfBound)
        
        XCTAssertGreaterThan(rallyEngine.telemetry.rallyIndex, 1)
        
        // Gọi reset trận đấu
        rallyEngine.resetMatch()
        
        XCTAssertEqual(rallyEngine.state, .waitingForServe)
        XCTAssertEqual(rallyEngine.telemetry.rallyIndex, 1)
        XCTAssertEqual(rallyEngine.telemetry.shotCount, 0)
        XCTAssertEqual(rallyEngine.currentScore.servingTeamScore, 0)
        XCTAssertEqual(rallyEngine.currentScore.receivingTeamScore, 0)
        XCTAssertEqual(rallyEngine.currentScore.serverNumber, 2)
    }
}
