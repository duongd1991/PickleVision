//
//  PlayerMetricsBarView.swift
//  PickleVision
//
//  Created by Frontend Coder on 2026-11-05.
//  Bottom Player Telemetry Cards, Workout Intensity Meter, Video Scrubber & VAR Controls.
//

import SwiftUI

/// Thanh hiển thị chỉ số thể lực 4 cầu thủ kèm bộ điều khiển phát lại video và VAR
public struct PlayerMetricsBarView: View {
    
    // MARK: - Properties
    
    public let metrics: [PlayerRallyMetric]
    @Binding public var isLivePlayback: Bool
    @Binding public var scrubberProgress: Double // 0.0 -> 1.0
    public var onScrubberChanged: ((Double) -> Void)? = nil
    public var onVARTapped: (() -> Void)? = nil
    public var onSummaryTapped: (() -> Void)? = nil
    public var onPlayPauseToggled: (() -> Void)? = nil
    
    public init(
        metrics: [PlayerRallyMetric],
        isLivePlayback: Binding<Bool> = .constant(true),
        scrubberProgress: Binding<Double> = .constant(1.0),
        onScrubberChanged: ((Double) -> Void)? = nil,
        onVARTapped: (() -> Void)? = nil,
        onSummaryTapped: (() -> Void)? = nil,
        onPlayPauseToggled: (() -> Void)? = nil
    ) {
        self.metrics = metrics
        self._isLivePlayback = isLivePlayback
        self._scrubberProgress = scrubberProgress
        self.onScrubberChanged = onScrubberChanged
        self.onVARTapped = onVARTapped
        self.onSummaryTapped = onSummaryTapped
        self.onPlayPauseToggled = onPlayPauseToggled
    }
    
    // MARK: - Fallback Players if telemetry is empty
    
    private var displayMetrics: [PlayerRallyMetric] {
        if !metrics.isEmpty {
            return metrics
        }
        // Bộ hiển thị mặc định 4 cầu thủ
        return [
            PlayerRallyMetric(
                id: UUID(),
                playerIndex: 0,
                name: "Tú",
                team: .nearTeam,
                courtPosition: CGPoint(x: 1.5, y: 1.0),
                rallyDistanceMeters: 18.5,
                totalMatchDistanceMeters: 420.0,
                currentSpeedKmh: 14.2,
                workoutIntensity: 0.75
            ),
            PlayerRallyMetric(
                id: UUID(),
                playerIndex: 1,
                name: "Cường",
                team: .nearTeam,
                courtPosition: CGPoint(x: 4.5, y: 1.0),
                rallyDistanceMeters: 15.2,
                totalMatchDistanceMeters: 385.0,
                currentSpeedKmh: 11.8,
                workoutIntensity: 0.62
            ),
            PlayerRallyMetric(
                id: UUID(),
                playerIndex: 2,
                name: "Nam",
                team: .farTeam,
                courtPosition: CGPoint(x: 1.5, y: 12.4),
                rallyDistanceMeters: 22.1,
                totalMatchDistanceMeters: 460.0,
                currentSpeedKmh: 16.5,
                workoutIntensity: 0.88
            ),
            PlayerRallyMetric(
                id: UUID(),
                playerIndex: 3,
                name: "Thành",
                team: .farTeam,
                courtPosition: CGPoint(x: 4.5, y: 12.4),
                rallyDistanceMeters: 12.8,
                totalMatchDistanceMeters: 310.0,
                currentSpeedKmh: 9.4,
                workoutIntensity: 0.48
            )
        ]
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 8) {
            
            // 1. Thanh điều khiển Scrubber và Nút Thao Tác Nhanh
            HStack(spacing: 12) {
                // Nút Play / Pause
                Button(action: {
                    onPlayPauseToggled?()
                }) {
                    Image(systemName: isLivePlayback ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                // Nút Trực tiếp (Live indicator)
                Button(action: {
                    isLivePlayback = true
                    scrubberProgress = 1.0
                    onScrubberChanged?(1.0)
                }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isLivePlayback ? Color.red : Color.gray)
                            .frame(width: 6, height: 6)
                        Text("LIVE")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(isLivePlayback ? .white : .white.opacity(0.5))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(isLivePlayback ? Color.red.opacity(0.3) : Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                // Thanh trượt tua lại Video (Scrubber)
                Slider(
                    value: $scrubberProgress,
                    in: 0.0...1.0,
                    onEditingChanged: { editing in
                        if !editing {
                            if scrubberProgress < 0.98 {
                                isLivePlayback = false
                            } else {
                                isLivePlayback = true
                            }
                            onScrubberChanged?(scrubberProgress)
                        }
                    }
                )
                .tint(.yellow)
                
                // Nút Kích Hoạt VAR Replay
                Button(action: {
                    onVARTapped?()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "video.badge.waveform.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("VAR REPLAY")
                            .font(.system(size: 9, weight: .black))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(colors: [Color.orange, Color.red], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: .orange.opacity(0.4), radius: 4)
                }
                .buttonStyle(.plain)
                
                // Nút Tổng Kết Trận Đấu
                Button(action: {
                    onSummaryTapped?()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 11, weight: .bold))
                        Text("TỔNG KẾT")
                            .font(.system(size: 9, weight: .black))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.12))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            
            // 2. Danh sách 4 thẻ cầu thủ xếp ngang đều
            HStack(spacing: 8) {
                ForEach(displayMetrics) { player in
                    PlayerCardView(metric: player)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.38), radius: 14, x: 0, y: 7)
    }
}

// MARK: - Individual Player Card View

private struct PlayerCardView: View {
    let metric: PlayerRallyMetric
    
    private var playerThemeColor: Color {
        switch metric.playerIndex {
        case 0: return Color(red: 0.22, green: 0.52, blue: 0.98) // Xanh dương
        case 1: return Color(red: 0.58, green: 0.38, blue: 0.98) // Tím
        case 2: return Color(red: 0.98, green: 0.46, blue: 0.12) // Cam
        case 3: return Color(red: 0.94, green: 0.28, blue: 0.28) // Đỏ
        default: return .cyan
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            
            // Header: Tên và Đội
            HStack(spacing: 4) {
                Circle()
                    .fill(playerThemeColor)
                    .frame(width: 7, height: 7)
                
                Text(metric.name)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                Text(metric.team == .nearTeam ? "GẦN" : "XA")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(playerThemeColor)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(playerThemeColor.opacity(0.2))
                    .clipShape(Capsule())
            }
            
            // Quãng đường cả trận
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(String(format: "%.0f", metric.totalMatchDistanceMeters))
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                Text("m cả trận")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
            
            // Quãng đường pha hiện tại & Tốc độ tức thời
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", metric.rallyDistanceMeters))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
                Text("m pha")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                
                Spacer()
                
                Text(String(format: "%.0f km/h", metric.currentSpeedKmh))
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            
            // Thanh đo cường độ vận động (Workout Intensity Bar)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 3.5)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.green, .yellow, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geo.size.width * CGFloat(min(max(Double(metric.workoutIntensity), 0.0), 1.0)),
                            height: 3.5
                        )
                }
            }
            .frame(height: 3.5)
            .padding(.top, 1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(playerThemeColor.opacity(0.35), lineWidth: 1)
                )
        )
    }
}
