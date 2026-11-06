//
//  CameraPreviewView.swift
//  PickleVision
//
//  Created by Frontend Coder on 2026-11-05.
//  Zero-copy Metal MTKView Camera Preview with Rec.709 Shaders and 4-Corner Calibration Touch Mode.
//

import SwiftUI
import MetalKit
import CoreVideo
import simd

/// Chế độ hiển thị của camera preview
public enum CameraPreviewInteractionMode: Equatable {
    case livePlayback
    case courtCalibration(selectedCornerIndex: Int?)
}

/// View bọc Metal MTKView hiển thị video camera độ phân giải cao và giao diện căn chỉnh 4 góc sân
public struct CameraPreviewView: UIViewRepresentable {
    
    // MARK: - Properties
    
    @Binding public var currentPixelBuffer: CVPixelBuffer?
    @Binding public var interactionMode: CameraPreviewInteractionMode
    @Binding public var calibrationCorners: [CGPoint]
    public var onCalibrationCompleted: (([CGPoint]) -> Void)?
    
    public init(
        pixelBuffer: Binding<CVPixelBuffer?>,
        interactionMode: Binding<CameraPreviewInteractionMode> = .constant(.livePlayback),
        calibrationCorners: Binding<[CGPoint]> = .constant([]),
        onCalibrationCompleted: (([CGPoint]) -> Void)? = nil
    ) {
        self._currentPixelBuffer = pixelBuffer
        self._interactionMode = interactionMode
        self._calibrationCorners = calibrationCorners
        self.onCalibrationCompleted = onCalibrationCompleted
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    public func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.framebufferOnly = false
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0)
        mtkView.preferredFramesPerSecond = 120
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        
        // Thiết lập Metal Pipeline trong coordinator
        if let device = mtkView.device {
            context.coordinator.setupMetal(device: device)
        }
        
        // Gắn cử chỉ chạm và kéo để tinh chỉnh 4 chốt góc sân
        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePanGesture(_:))
        )
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTapGesture(_:))
        )
        mtkView.addGestureRecognizer(panGesture)
        mtkView.addGestureRecognizer(tapGesture)
        
        return mtkView
    }
    
    public func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.parent = self
        if let buffer = currentPixelBuffer {
            context.coordinator.enqueueFrame(buffer)
        }
    }
    
    // MARK: - Coordinator & Metal Renderer
    
    public final class Coordinator: NSObject, MTKViewDelegate {
        var parent: CameraPreviewView
        
        private var device: MTLDevice?
        private var commandQueue: MTLCommandQueue?
        private var yuvPipelineState: MTLRenderPipelineState?
        private var bgraPipelineState: MTLRenderPipelineState?
        private var textureCache: CVMetalTextureCache?
        
        private var currentBuffer: CVPixelBuffer?
        private let bufferLock = NSLock()
        
        // Chỉ số góc đang kéo (0: NearLeft, 1: NearRight, 2: FarRight, 3: FarLeft)
        private var draggingCornerIndex: Int? = nil
        
        init(parent: CameraPreviewView) {
            self.parent = parent
            super.init()
        }
        
        // MARK: - Metal Setup
        
        func setupMetal(device: MTLDevice) {
            self.device = device
            self.commandQueue = device.makeCommandQueue()
            
            // Khởi tạo Texture Cache Zero-Copy
            let cacheResult = CVMetalTextureCacheCreate(
                kCFAllocatorDefault,
                nil,
                device,
                nil,
                &textureCache
            )
            if cacheResult != kCVReturnSuccess {
                print("[CameraPreviewView] Không thể khởi tạo CVMetalTextureCache: \(cacheResult)")
            }
            
            // Xây dựng Metal Shaders trực tiếp từ mã nguồn Rec.709
            let shaderSource = """
            #include <metal_stdlib>
            using namespace metal;
            
            struct VertexOut {
                float4 position [[position]];
                float2 texCoords;
            };
            
            vertex VertexOut videoVertexShader(uint vertexID [[vertex_id]]) {
                float2 positions[4] = {
                    float2(-1.0, -1.0),
                    float2( 1.0, -1.0),
                    float2(-1.0,  1.0),
                    float2( 1.0,  1.0)
                };
                float2 texCoords[4] = {
                    float2(0.0, 1.0),
                    float2(1.0, 1.0),
                    float2(0.0, 0.0),
                    float2(1.0, 0.0)
                };
                
                VertexOut out;
                out.position = float4(positions[vertexID], 0.0, 1.0);
                out.texCoords = texCoords[vertexID];
                return out;
            }
            
            fragment float4 yuvRec709FragmentShader(
                VertexOut in [[stage_in]],
                texture2d<float, access::sample> lumaTexture [[texture(0)]],
                texture2d<float, access::sample> chromaTexture [[texture(1)]]
            ) {
                constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
                float y = lumaTexture.sample(textureSampler, in.texCoords).r;
                float2 uv = chromaTexture.sample(textureSampler, in.texCoords).rg - float2(0.5, 0.5);
                
                // Chuẩn Rec.709 (HDTV / iOS Camera)
                float r = y + 1.5748 * uv.y;
                float g = y - 0.1873 * uv.x - 0.4681 * uv.y;
                float b = y + 1.8556 * uv.x;
                
                return float4(clamp(r, 0.0, 1.0), clamp(g, 0.0, 1.0), clamp(b, 0.0, 1.0), 1.0);
            }
            
            fragment float4 bgraFragmentShader(
                VertexOut in [[stage_in]],
                texture2d<float, access::sample> bgraTexture [[texture(0)]]
            ) {
                constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
                return bgraTexture.sample(textureSampler, in.texCoords);
            }
            """
            
            do {
                let library = try device.makeLibrary(source: shaderSource, options: nil)
                
                // Pipeline YUV Rec.709
                let yuvDesc = MTLRenderPipelineDescriptor()
                yuvDesc.vertexFunction = library.makeFunction(name: "videoVertexShader")
                yuvDesc.fragmentFunction = library.makeFunction(name: "yuvRec709FragmentShader")
                yuvDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
                self.yuvPipelineState = try device.makeRenderPipelineState(descriptor: yuvDesc)
                
                // Pipeline BGRA direct
                let bgraDesc = MTLRenderPipelineDescriptor()
                bgraDesc.vertexFunction = library.makeFunction(name: "videoVertexShader")
                bgraDesc.fragmentFunction = library.makeFunction(name: "bgraFragmentShader")
                bgraDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
                self.bgraPipelineState = try device.makeRenderPipelineState(descriptor: bgraDesc)
                
            } catch {
                print("[CameraPreviewView] Lỗi biên dịch Metal Shader: \(error.localizedDescription)")
            }
        }
        
        func enqueueFrame(_ pixelBuffer: CVPixelBuffer) {
            bufferLock.lock()
            self.currentBuffer = pixelBuffer
            bufferLock.unlock()
        }
        
        // MARK: - MTKViewDelegate
        
        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        
        public func draw(in view: MTKView) {
            bufferLock.lock()
            guard let pixelBuffer = currentBuffer,
                  let textureCache = textureCache,
                  let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let commandQueue = commandQueue else {
                bufferLock.unlock()
                return
            }
            bufferLock.unlock()
            
            let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                return
            }
            
            if pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange ||
               pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange {
                
                // YUV Bi-Planar rendering
                var lumaMetalTexture: CVMetalTexture?
                CVMetalTextureCacheCreateTextureFromImage(
                    kCFAllocatorDefault,
                    textureCache,
                    pixelBuffer,
                    nil,
                    .r8Unorm,
                    width,
                    height,
                    0,
                    &lumaMetalTexture
                )
                
                var chromaMetalTexture: CVMetalTexture?
                CVMetalTextureCacheCreateTextureFromImage(
                    kCFAllocatorDefault,
                    textureCache,
                    pixelBuffer,
                    nil,
                    .rg8Unorm,
                    width / 2,
                    height / 2,
                    1,
                    &chromaMetalTexture
                )
                
                if let lumaCV = lumaMetalTexture,
                   let chromaCV = chromaMetalTexture,
                   let lumaTex = CVMetalTextureGetTexture(lumaCV),
                   let chromaTex = CVMetalTextureGetTexture(chromaCV),
                   let pipeline = yuvPipelineState {
                    
                    encoder.setRenderPipelineState(pipeline)
                    encoder.setFragmentTexture(lumaTex, index: 0)
                    encoder.setFragmentTexture(chromaTex, index: 1)
                    encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                }
                
            } else {
                // BGRA direct rendering
                var bgraMetalTexture: CVMetalTexture?
                CVMetalTextureCacheCreateTextureFromImage(
                    kCFAllocatorDefault,
                    textureCache,
                    pixelBuffer,
                    nil,
                    .bgra8Unorm,
                    width,
                    height,
                    0,
                    &bgraMetalTexture
                )
                
                if let bgraCV = bgraMetalTexture,
                   let bgraTex = CVMetalTextureGetTexture(bgraCV),
                   let pipeline = bgraPipelineState {
                    
                    encoder.setRenderPipelineState(pipeline)
                    encoder.setFragmentTexture(bgraTex, index: 0)
                    encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                }
            }
            
            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        
        // MARK: - Calibration Touch & Pan Gestures
        
        @objc func handleTapGesture(_ recognizer: UITapGestureRecognizer) {
            guard case .courtCalibration = parent.interactionMode,
                  let view = recognizer.view else { return }
            
            let point = recognizer.location(in: view)
            let viewSize = view.bounds.size
            guard viewSize.width > 0 && viewSize.height > 0 else { return }
            
            // Chuẩn hóa điểm chạm sang pixel tỷ lệ [0..1]
            let normalizedPoint = CGPoint(x: point.x / viewSize.width, y: point.y / viewSize.height)
            
            // Tìm góc gần nhất trong bán kính 40 pt
            var corners = parent.calibrationCorners
            if corners.count < 4 {
                corners.append(normalizedPoint)
                parent.calibrationCorners = corners
                if corners.count == 4 {
                    parent.onCalibrationCompleted?(corners)
                }
            } else {
                let thresholdDist: CGFloat = 0.08
                for i in 0..<corners.count {
                    let d = hypot(corners[i].x - normalizedPoint.x, corners[i].y - normalizedPoint.y)
                    if d < thresholdDist {
                        parent.interactionMode = .courtCalibration(selectedCornerIndex: i)
                        return
                    }
                }
            }
        }
        
        @objc func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
            guard case .courtCalibration = parent.interactionMode,
                  let view = recognizer.view else { return }
            
            let point = recognizer.location(in: view)
            let viewSize = view.bounds.size
            guard viewSize.width > 0 && viewSize.height > 0 else { return }
            
            let normalizedPoint = CGPoint(
                x: min(max(point.x / viewSize.width, 0.0), 1.0),
                y: min(max(point.y / viewSize.height, 0.0), 1.0)
            )
            
            switch recognizer.state {
            case .began:
                var corners = parent.calibrationCorners
                guard corners.count >= 4 else { return }
                
                var closestIndex = 0
                var minDistance = CGFloat.greatestFiniteMagnitude
                for i in 0..<corners.count {
                    let d = hypot(corners[i].x - normalizedPoint.x, corners[i].y - normalizedPoint.y)
                    if d < minDistance {
                        minDistance = d
                        closestIndex = i
                    }
                }
                
                if minDistance < 0.12 {
                    draggingCornerIndex = closestIndex
                    parent.interactionMode = .courtCalibration(selectedCornerIndex: closestIndex)
                } else {
                    draggingCornerIndex = nil
                }
                
            case .changed:
                if let idx = draggingCornerIndex, idx < parent.calibrationCorners.count {
                    var corners = parent.calibrationCorners
                    corners[idx] = normalizedPoint
                    parent.calibrationCorners = corners
                }
                
            case .ended, .cancelled:
                if draggingCornerIndex != nil {
                    parent.onCalibrationCompleted?(parent.calibrationCorners)
                    draggingCornerIndex = nil
                }
                
            default:
                break
            }
        }
    }
}
