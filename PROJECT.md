# Project: PickleVision Native iOS Application

## Architecture
PickleVision is a native iOS application (iPhone/iPad, iOS 17+) designed for real-time live Pickleball match analysis using Computer Vision, Accelerate LAPACK, Apple Vision Pose, ByteTrack, Metal HUD overlays, and SwiftUI.

### Architecture Boundaries & Data Flow
1. **Camera & Ingestion Layer**: `CameraManager` (AVCaptureSession 1080p @ 60/120fps) -> `VideoStabilizer` (Cinematic Extended + Homography Anchor Tracking).
2. **Vision & Math Layer**: 
   - `CourtCalibrationService`: 3x3 Homography DLT solver with Hartley normalization via Apple Accelerate LAPACK (`dgesvd_`), achieving <0.02m error.
   - `PlayerTrackerService`: Apple Vision Pose (`VNDetectHumanBodyPoseRequest`) ankle midpoint detection, ByteTrack + Kalman Filter in metric court coordinates + 2D HSV Torso Histogram Re-ID, 0.05m jitter filter.
   - `BallTrackerService`: Frame differencing + color filter + TrackNet, parabolic trajectory fitting ($y = at^2 + bt + c$), vertical acceleration bounce detection ($d^2y/dt^2 > 0$ at $Z \approx 0$), instantaneous speed ($v = \Delta d / \Delta t \times 3.6$ km/h).
   - `PickleballCVCoordinator`: Glues vision pipelines, executes USA Pickleball In/Out rules engine (Serve: kitchen line/NVZ is FAULT; Live: kitchen is IN, sidelines/baselines are IN).
3. **Engine Layer**:
   - `RallyEngine`: State machine (`WAITING_FOR_SERVE` -> `IN_PLAY` -> `RALLY_END`), shot counter, real-time and match distance accumulation.
   - `VideoExportEngine`: Dual stream export (Clean video + Burn-in broadcast video with Metal overlay, 16:9 and 9:16 formats).
4. **Presentation Layer (SwiftUI + Metal)**:
   - `LiveMatchContainerView`: Root live view.
   - `CameraPreviewView`: Zero-copy Metal texture rendering.
   - `TopStatusBarView`: Rally time, rally count, shot exchanges, match state.
   - `CourtMiniMapView`: 2D top-down court projection with real-time player dots, trajectory tails, and ball bounces.
   - `PlayerMetricsBarView`: 4 player cards with rally distance, total match distance, workout intensity bar.
   - `InstantReplayVARView`: Magnifying loupe 4x zoom on bounce contact with IN green / OUT red badge and 5s slow-mo clip.
   - `MatchSummaryReportView`: Post-match heatmap KDE, peak speed, court control percentage.
5. **Testing & Verification Layer**:
   - Independent XCTest suite with synthetic mock data feeds, testing all algorithms independently.

---

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | USA Pickleball Court Model | 13.4112m x 6.096m, NVZ 2.1336m, 12 key landmark coordinates | M1 | Survey / Coach |
| 2 | Telemetry & Player Tracking Models | `PlayerTrack`, `CourtModel`, `RallyTelemetry` structs | M1 | Survey / Backend |
| 3 | Camera Session 60/120fps | AVCaptureSession 1080p high framerate feed | M2 | Survey / Backend |
| 4 | Camera Stabilization & Anchor Tracking | Cinematic Extended + Lucas-Kanade Homography Anchor Tracking | M2 | Survey / Backend |
| 5 | DLT Homography 3x3 Solver | Accelerate LAPACK `dgesvd_` with Hartley normalization (<0.02m error) | M2 | Survey / Backend |
| 6 | Semi-automatic Touch Calibration | 4-point court touch calibration & perspective projection | M2 | Survey / Backend |
| 7 | Vision Ankle Pose Tracking | Apple Vision Pose ankle midpoint ground contact extraction | M2 | Survey / Backend |
| 8 | ByteTrack + Kalman + Re-ID | Player tracking with HSV histogram Re-ID and 0.05m jitter filter | M2 | Survey / Backend |
| 9 | Ball Parabolic Fit & Speed | $y = at^2 + bt + c$, velocity in km/h, vertical bounce detection | M2 | Survey / Backend |
| 10 | USA Pickleball In/Out Engine | Automatic In/Out decision logic (Serve vs Live rally rules) | M2 | Survey / Backend |
| 11 | Rally State Machine | `WAITING_FOR_SERVE` -> `IN_PLAY` -> `RALLY_END` state management | M2 | Survey / Backend |
| 12 | App Entry & Live Match Container | SwiftUI App lifecycle & root layout container | M3 | Survey / Frontend |
| 13 | Metal Camera Preview & Overlay | Zero-copy `MTKView` video feed & graphics overlay | M3 | Survey / Frontend |
| 14 | Top Status Bar HUD | 5 key telemetry metrics: rally time, rally #, shots, live state | M3 | Survey / Frontend |
| 15 | 2D Court Minimap | 2D top-down perspective court with player positions & ball trace | M3 | Survey / Frontend |
| 16 | Bottom Player Metrics Bar | 4 player metric cards with distances and intensity bars | M3 | Survey / Frontend |
| 17 | Instant Replay VAR Loupe | 4x magnifying loupe zoom on bounce contact with IN/OUT badge | M3 | Survey / Frontend |
| 18 | Match Summary Report & Heatmap | Post-match analysis, KDE player heatmap, peak speed | M3 | Survey / Frontend |
| 19 | Dual-Stream Video Export | Clean video & Burn-in broadcast video (16:9 & 9:16) | M3 | Survey / Frontend |
| 20 | DLT Homography Test Suite | Verify <0.02m accuracy with mock court landmarks | M4 | Survey / Testing |
| 21 | USA Pickleball In/Out Test Suite | 100% rule coverage tests for serve, kitchen, boundaries | M4 | Survey / Testing |
| 22 | Rally Engine State Machine Tests | State transition, shot exchanges, distance accumulation | M4 | Survey / Testing |
| 23 | Player Distance & Jitter Tests | Test 0.05m jitter filter and metric distance accumulation | M4 | Survey / Testing |
| 24 | Ball Parabola & Speed Tests | Trajectory fitting, bounce detection, km/h validation | M4 | Survey / Testing |
| 25 | Code Review & Architecture Audit | Architecture compliance, 60/120fps performance, zero stubs | M5 | R1 / Reviewer |
| 26 | Forensic Integrity Audit | Static analysis, authenticity verification, zero cheating | M6 | Integrity Rules |

---

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Models & Athletic Rules Foundation | `Models/` (CourtModel, PlayerTrack, RallyTelemetry) | none | DONE |
| M2 | Backend Core CV & Algorithms | `Core/Camera/`, `Core/Vision/`, `Core/Engine/RallyEngine.swift` | M1 | DONE |
| M3 | Frontend UI, Metal HUD & Video Export | `App/`, `UI/Live/`, `UI/Review/`, `Core/Engine/VideoExportEngine.swift` | M1, M2 | DONE |
| M4 | Independent XCTest Suite & Mock Feeds | `Tests/PickleVisionTests/` with 5 independent test suites | M1, M2 | DONE |
| M5 | Code Review & Performance Audit | Review entire codebase for architecture, performance & zero stubs | M2, M3, M4 | DONE |
| M6 | Forensic Integrity Audit | Forensic integrity verification by teamwork_auditor | M5 | DONE |

---

## Interface Contracts

### `CourtCalibrationService` ↔ `PickleballCVCoordinator`
```swift
public protocol CourtCalibrating: AnyObject {
    var homographyMatrix: simd_float3x3? { get }
    var inverseHomographyMatrix: simd_float3x3? { get }
    var isCalibrated: Bool { get }
    func calibrate(withPixelCorners corners: [CGPoint]) -> Result<simd_float3x3, CalibrationError>
    func pixelToCourt(pixel: CGPoint) -> CGPoint? // meters (X: 0..6.096, Y: 0..13.4112)
    func courtToPixel(courtPoint: CGPoint) -> CGPoint?
    func computeReprojectionError(groundTruthPairs: [(pixel: CGPoint, court: CGPoint)]) -> Float
}
```

### `PlayerTrackerService` ↔ `PickleballCVCoordinator`
```swift
public protocol PlayerTracking: AnyObject {
    func update(with pixelBuffer: CVPixelBuffer, homography: simd_float3x3) -> [PlayerTrack]
    func reset()
}
```

### `BallTrackerService` ↔ `PickleballCVCoordinator`
```swift
public protocol BallTracking: AnyObject {
    func update(with pixelBuffer: CVPixelBuffer, timestamp: TimeInterval, homography: simd_float3x3) -> BallObservation?
    func reset()
}
```

### `RallyEngine` ↔ `PickleballCVCoordinator` & `LiveMatchContainerView`
```swift
public protocol RallyEngineProtocol: ObservableObject {
    var state: RallyState { get }
    var telemetry: RallyTelemetry { get }
    var currentServeNumber: Int { get }
    func handleBallBounce(at courtPoint: CGPoint, isServe: Bool) -> InOutVerdict
    func recordPlayerMovement(playerId: UUID, deltaDistance: Float)
    func startRally()
    func endRally(verdict: InOutVerdict)
    func resetMatch()
}
```

---

## Code Layout
Project root: `c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PickleVision`
```
PickleVision/
├── App/
│   └── PickleVisionApp.swift
├── Core/
│   ├── Camera/
│   │   ├── CameraManager.swift
│   │   └── VideoStabilizer.swift
│   ├── Vision/
│   │   ├── CourtCalibrationService.swift
│   │   ├── PlayerTrackerService.swift
│   │   ├── BallTrackerService.swift
│   │   └── PickleballCVCoordinator.swift
│   └── Engine/
│       ├── RallyEngine.swift
│       └── VideoExportEngine.swift
├── Models/
│   ├── CourtModel.swift
│   ├── PlayerTrack.swift
│   └── RallyTelemetry.swift
├── UI/
│   ├── Live/
│   │   ├── LiveMatchContainerView.swift
│   │   ├── CameraPreviewView.swift
│   │   ├── TopStatusBarView.swift
│   │   ├── CourtMiniMapView.swift
│   │   └── PlayerMetricsBarView.swift
│   └── Review/
│       ├── InstantReplayVARView.swift
│       └── MatchSummaryReportView.swift
└── Tests/
    └── PickleVisionTests/
        ├── MockDataFeeds.swift
        ├── DLTHomographyTests.swift
        ├── InOutRulesTests.swift
        ├── RallyEngineTests.swift
        ├── PlayerDistanceFilterTests.swift
        ├── BallParabolaSpeedTests.swift
        └── FullPipelineIntegrationTests.swift
```
