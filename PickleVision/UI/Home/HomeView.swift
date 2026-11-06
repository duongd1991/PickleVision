//
//  HomeView.swift
//  PickleVision
//
//  Created by Frontend Coder on 2026-11-06.
//  Home / Welcome Screen with Pickleball court styling, Start, Info, Exit buttons and version tag v1.0.0.
//

import SwiftUI

/// Màn hình Trang Chủ của ứng dụng PickleVision
public struct HomeView: View {
    
    // MARK: - Callbacks
    
    public var onStartTapped: () -> Void
    public var onExitTapped: (() -> Void)? = nil
    
    // MARK: - Local States
    
    @State private var showInfoModal: Bool = false
    @State private var showExitAlert: Bool = false
    @State private var isAnimatingBall: Bool = false
    
    public init(
        onStartTapped: @escaping () -> Void,
        onExitTapped: (() -> Void)? = nil
    ) {
        self.onStartTapped = onStartTapped
        self.onExitTapped = onExitTapped
    }
    
    public var body: some View {
        ZStack {
            // 1. HÌNH NỀN TRANG TRÍ PHÙ HỢP MÔN PICKLEBALL
            PickleballCourtBackground()
                .ignoresSafeArea()
            
            // 2. NỘI DUNG CHÍNH (TIÊU ĐỀ & CÁC NÚT ĐIỀU HƯỚNG)
            VStack(spacing: 24) {
                Spacer()
                
                // Logo & Tiêu đề chính
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "figure.tennis")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundColor(.yellow)
                            .shadow(color: .yellow.opacity(0.8), radius: 12)
                        
                        Text("PickleVision")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.8), radius: 10, x: 0, y: 4)
                    }
                    
                    Text("HỆ THỐNG QUAY & PHÂN TÍCH THI ĐẤU PICKLEBALL TRỰC TIẾP")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(.yellow)
                        .tracking(1.5)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                }
                
                // Cụm nút hành động chính (Bắt đầu, Thông tin, Thoát)
                VStack(spacing: 14) {
                    
                    // Nút BẮT ĐẦU
                    Button(action: onStartTapped) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 22, weight: .bold))
                            Text("BẮT ĐẦU")
                                .font(.system(size: 18, weight: .black))
                        }
                        .foregroundColor(.black)
                        .frame(width: 260, height: 54)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.95, blue: 0.5), Color.yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.green.opacity(0.5), radius: 15, x: 0, y: 6)
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Nút THÔNG TIN
                    Button(action: {
                        showInfoModal = true
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("THÔNG TIN")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(width: 260, height: 48)
                        .background(.ultraThinMaterial.opacity(0.9))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1.2)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    
                    // Nút THOÁT
                    Button(action: {
                        showExitAlert = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "power")
                                .font(.system(size: 16, weight: .bold))
                            Text("THOÁT")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 260, height: 44)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 10)
                
                Spacer()
            }
            .padding(.top, 20)
            
            // 3. THÔNG TIN PHIÊN BẢN Ở GÓC PHẢI PHÍA DƯỚI
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("version v1.0.1")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.65))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                    )
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
                }
            }
        }
        .sheet(isPresented: $showInfoModal) {
            AppInfoModalView()
        }
        .alert("Thoát Ứng Dụng", isPresented: $showExitAlert) {
            Button("Đóng", role: .cancel) {}
            Button("Thoát", role: .destructive) {
                if let exitAction = onExitTapped {
                    exitAction()
                } else {
                    exit(0)
                }
            }
        } message: {
            Text("Bạn có chắc chắn muốn thoát ứng dụng PickleVision?")
        }
    }
}

// MARK: - Background Nghệ Thuật Môn Pickleball

private struct PickleballCourtBackground: View {
    var body: some View {
        ZStack {
            // Nền Gradient thể thao
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.12, blue: 0.22),
                    Color(red: 0.02, green: 0.06, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Họa tiết phối cảnh mặt sân Pickleball thu nhỏ
            Canvas { context, size in
                let w = size.width
                let h = size.height
                
                // Nền sân xanh dương đậm (Service Courts)
                let courtRect = CGRect(x: w * 0.15, y: h * 0.15, width: w * 0.7, height: h * 0.7)
                context.fill(Path(roundedRect: courtRect, cornerRadius: 8), with: .color(Color(red: 0.10, green: 0.25, blue: 0.42).opacity(0.35)))
                
                // Vạch biên ngoài (Sidelines & Baselines)
                context.stroke(Path(roundedRect: courtRect, cornerRadius: 8), with: .color(Color.white.opacity(0.2)), lineWidth: 2)
                
                // Vùng Bếp NVZ (Non-Volley Zone: Xanh Emerald)
                let kitchenRect = CGRect(x: w * 0.15, y: h * 0.38, width: w * 0.7, height: h * 0.24)
                context.fill(Path(kitchenRect), with: .color(Color(red: 0.12, green: 0.45, blue: 0.35).opacity(0.35)))
                context.stroke(Path(kitchenRect), with: .color(Color.white.opacity(0.2)), lineWidth: 1.5)
                
                // Vạch lưới trắng đứt đoạn ở chính giữa
                var netPath = Path()
                netPath.move(to: CGPoint(x: w * 0.15, y: h * 0.50))
                netPath.addLine(to: CGPoint(x: w * 0.85, y: h * 0.50))
                context.stroke(netPath, with: .color(Color.white.opacity(0.4)), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                
                // Vạch kẻ chia đôi 2 ô giao bóng (Centerline)
                var center1 = Path()
                center1.move(to: CGPoint(x: w * 0.50, y: h * 0.15))
                center1.addLine(to: CGPoint(x: w * 0.50, y: h * 0.38))
                context.stroke(center1, with: .color(Color.white.opacity(0.2)), lineWidth: 1.5)
                
                var center2 = Path()
                center2.move(to: CGPoint(x: w * 0.50, y: h * 0.62))
                center2.addLine(to: CGPoint(x: w * 0.50, y: h * 0.85))
                context.stroke(center2, with: .color(Color.white.opacity(0.2)), lineWidth: 1.5)
            }
            .blur(radius: 1.5)
            
            // Quả bóng Pickleball vàng neon đặc trưng với các lỗ tròn
            VStack {
                HStack {
                    Spacer()
                    PickleballIconView()
                        .frame(width: 140, height: 140)
                        .padding(.trailing, 40)
                        .padding(.top, 20)
                        .opacity(0.22)
                }
                Spacer()
            }
        }
    }
}

// MARK: - Quả bóng Pickleball Neon Icon

private struct PickleballIconView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.yellow, Color(red: 0.8, green: 0.85, blue: 0.1)],
                        center: .topLeading,
                        startRadius: 10,
                        endRadius: 70
                    )
                )
            
            // Các lỗ đặc trưng của bóng wiffle pickleball
            ForEach(0..<8) { i in
                let angle = Double(i) * (.pi / 4)
                let radius: CGFloat = 36
                Circle()
                    .fill(Color.black.opacity(0.35))
                    .frame(width: 12, height: 12)
                    .offset(x: CGFloat(cos(angle)) * radius, y: CGFloat(sin(angle)) * radius)
            }
            
            ForEach(0..<4) { i in
                let angle = Double(i) * (.pi / 2) + (.pi / 8)
                let radius: CGFloat = 18
                Circle()
                    .fill(Color.black.opacity(0.35))
                    .frame(width: 10, height: 10)
                    .offset(x: CGFloat(cos(angle)) * radius, y: CGFloat(sin(angle)) * radius)
            }
        }
    }
}

// MARK: - Modal Thông Tin Ứng Dụng

private struct AppInfoModalView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    
                    // Card Giới thiệu
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.yellow)
                            Text("PickleVision v1.0.1")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                        }
                        Text("Ứng dụng phân tích thi đấu Pickleball bằng Computer Vision chạy trực tiếp trên iPhone/iPad theo thời gian thực (Zero Latency).")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    // Card Hướng dẫn Đặt Chân Máy (Tripod)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "video.badge.plus")
                                .foregroundColor(.cyan)
                            Text("Hướng Dẫn Thiết Lập Camera")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                        }
                        Text("• Vị trí: Đặt camera trên chân đế (Tripod) phía sau vạch cuối sân (Baseline) ở độ cao 1.8m – 2.5m.")
                        Text("• Góc nhìn: Bao quát trọn vẹn 4 góc sân và vạch bếp (Non-Volley Zone).")
                        Text("• Định hướng: Đặt điện thoại quay ngang (Landscape) để đạt độ phân giải chuẩn 1080p @ 60/120fps.")
                    }
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(14)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    // Card Quy tắc Phán Quyết In/Out (USA Pickleball)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                            Text("Luật Phán Quyết (USA Pickleball)")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                        }
                        Text("• Vạch biên & đáy: Bóng chạm mép vạch là IN.")
                        Text("• Giao bóng (Serve): Bóng rơi vào khu vực bếp hoặc chạm vạch bếp là FAULT (Lỗi).")
                        Text("• Pha bóng sống: Bóng rơi vào khu vực bếp là HỢP LỆ (IN).")
                        Text("• Lỗi vô-lê: Người chơi không được vô-lê trên không khi đứng trong khu vực bếp.")
                    }
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(14)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(16)
            }
            .navigationTitle("Thông Tin Ứng Dụng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") {
                        dismiss()
                    }
                    .font(.body.bold())
                }
            }
        }
    }
}
