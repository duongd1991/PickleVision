//
//  MatchSetupView.swift
//  PickleVision
//
//  Created by Frontend Coder on 2026-11-06.
//  Player Setup & Initial Server Selection Screen before Court ROI Calibration.
//

import SwiftUI

/// Màn hình thiết lập thông tin cầu thủ và chọn người phát bóng đầu tiên
public struct MatchSetupView: View {
    
    // MARK: - Properties & Callbacks
    
    public var initialNames: [String]
    public var initialServerIndex: Int
    public var onBack: () -> Void
    public var onNext: (_ names: [String], _ serverIndex: Int) -> Void
    
    // MARK: - Local States
    
    @State private var p0: String = ""
    @State private var p1: String = ""
    @State private var p2: String = ""
    @State private var p3: String = ""
    @State private var selectedServer: Int = 0
    @State private var isDoubles: Bool = true
    
    public init(
        initialNames: [String] = ["A1", "A2", "B1", "B2"],
        initialServerIndex: Int = 0,
        onBack: @escaping () -> Void,
        onNext: @escaping (_ names: [String], _ serverIndex: Int) -> Void
    ) {
        self.initialNames = initialNames
        self.initialServerIndex = initialServerIndex
        self.onBack = onBack
        self.onNext = onNext
    }
    
    public var body: some View {
        ZStack {
            // Nền tối thanh lịch
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.10, blue: 0.18),
                    Color(red: 0.02, green: 0.05, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. THANH TIÊU ĐỀ & ĐIỀU HƯỚNG TRÊN CÙNG
                HStack(spacing: 12) {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                            Text("Trang Chủ")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    VStack(spacing: 1) {
                        Text("BƯỚC 1 / 2: THIẾT LẬP CẦU THỦ")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(.yellow)
                        Text("Thông Tin Cầu Thủ & Người Phát Bóng")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Button(action: handleNext) {
                        HStack(spacing: 6) {
                            Text("TIẾP TỤC")
                                .font(.system(size: 13, weight: .black))
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            LinearGradient(
                                colors: [Color.green, Color.yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.green.opacity(0.4), radius: 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial.opacity(0.95))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.white.opacity(0.12)),
                    alignment: .bottom
                )
                
                // 2. KHU VỰC CẤU HÌNH CUỘN
                ScrollView {
                    VStack(spacing: 16) {
                        
                        // Cụm 1: Danh sách 4 cầu thủ chia làm 2 đội (Đội Gần vs Đội Xa)
                        HStack(alignment: .top, spacing: 14) {
                            
                            // Cột Đội Gần (Near Team)
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(red: 0.22, green: 0.52, blue: 0.98))
                                        .frame(width: 8, height: 8)
                                    Text("ĐỘI A (GẦN SÂN DƯỚI)")
                                        .font(.system(size: 11, weight: .black, design: .monospaced))
                                        .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
                                }
                                
                                // Cầu thủ A1
                                PlayerInputCard(
                                    title: "Cầu thủ A1 (Trái):",
                                    color: Color(red: 0.22, green: 0.52, blue: 0.98),
                                    text: $p0,
                                    isServer: selectedServer == 0,
                                    onSelectServer: { selectedServer = 0 }
                                )
                                
                                // Cầu thủ A2
                                PlayerInputCard(
                                    title: "Cầu thủ A2 (Phải):",
                                    color: Color(red: 0.58, green: 0.38, blue: 0.98),
                                    text: $p1,
                                    isServer: selectedServer == 1,
                                    onSelectServer: { selectedServer = 1 }
                                )
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(red: 0.22, green: 0.52, blue: 0.98).opacity(0.3), lineWidth: 1)
                            )
                            
                            // Cột Đội Xa (Far Team)
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(red: 0.98, green: 0.46, blue: 0.12))
                                        .frame(width: 8, height: 8)
                                    Text("ĐỘI B (XA SÂN TRÊN)")
                                        .font(.system(size: 11, weight: .black, design: .monospaced))
                                        .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.3))
                                }
                                
                                // Cầu thủ B1
                                PlayerInputCard(
                                    title: "Cầu thủ B1 (Trái):",
                                    color: Color(red: 0.98, green: 0.46, blue: 0.12),
                                    text: $p2,
                                    isServer: selectedServer == 2,
                                    onSelectServer: { selectedServer = 2 }
                                )
                                
                                // Cầu thủ B2
                                PlayerInputCard(
                                    title: "Cầu thủ B2 (Phải):",
                                    color: Color(red: 0.94, green: 0.28, blue: 0.28),
                                    text: $p3,
                                    isServer: selectedServer == 3,
                                    onSelectServer: { selectedServer = 3 }
                                )
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(red: 0.98, green: 0.46, blue: 0.12).opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        // Cụm 2: Tóm tắt người phát bóng đầu tiên
                        HStack(spacing: 12) {
                            Image(systemName: "tennis.racket")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.yellow)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("NGƯỜI PHÁT BÓNG ĐẦU TIÊN (SERVER):")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                                Text("\(nameForIndex(selectedServer)) (\(teamNameForIndex(selectedServer)))")
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundColor(.yellow)
                            }
                            
                            Spacer()
                            
                            Text("Chạm vào biểu tượng huy hiệu trên thẻ cầu thủ để chọn người phát bóng")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 240)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.yellow.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .onAppear {
            loadInitialData()
        }
    }
    
    // MARK: - Helpers
    
    private func loadInitialData() {
        p0 = initialNames.indices.contains(0) ? initialNames[0] : "A1"
        p1 = initialNames.indices.contains(1) ? initialNames[1] : "A2"
        p2 = initialNames.indices.contains(2) ? initialNames[2] : "B1"
        p3 = initialNames.indices.contains(3) ? initialNames[3] : "B2"
        selectedServer = initialServerIndex
    }
    
    private func nameForIndex(_ index: Int) -> String {
        switch index {
        case 0: return p0.isEmpty ? "A1" : p0
        case 1: return p1.isEmpty ? "A2" : p1
        case 2: return p2.isEmpty ? "B1" : p2
        case 3: return p3.isEmpty ? "B2" : p3
        default: return "Cầu thủ \(index + 1)"
        }
    }
    
    private func teamNameForIndex(_ index: Int) -> String {
        return (index == 0 || index == 1) ? "Đội A" : "Đội B"
    }
    
    private func handleNext() {
        let trimmed0 = p0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "A1" : p0
        let trimmed1 = p1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "A2" : p1
        let trimmed2 = p2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "B1" : p2
        let trimmed3 = p3.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "B2" : p3
        
        onNext([trimmed0, trimmed1, trimmed2, trimmed3], selectedServer)
    }
}

// MARK: - Subview: Card Nhập Tên & Chọn Server

private struct PlayerInputCard: View {
    let title: String
    let color: Color
    @Binding var text: String
    let isServer: Bool
    let onSelectServer: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                
                TextField("Tên cầu thủ...", text: $text)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.white)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
            }
            
            Spacer()
            
            // Nút bấm chọn làm người phát bóng
            Button(action: onSelectServer) {
                HStack(spacing: 4) {
                    Image(systemName: isServer ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12, weight: .bold))
                    Text(isServer ? "PHÁT BÓNG" : "CHỌN GIAO")
                        .font(.system(size: 8.5, weight: .black))
                }
                .foregroundColor(isServer ? .black : .white.opacity(0.7))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(isServer ? Color.yellow : Color.white.opacity(0.12))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isServer ? Color.yellow : color.opacity(0.4), lineWidth: isServer ? 1.5 : 1)
        )
    }
}
