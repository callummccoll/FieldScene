/*
 * FieldSceneRenderer.swift
 * FieldSceneTester
 *
 * Created by Callum McColl on 20/8/20.
 * Copyright © 2020 Callum McColl. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer in the documentation and/or other materials
 *    provided with the distribution.
 *
 * 3. All advertising materials mentioning features or use of this
 *    software must display the following acknowledgement:
 *
 *        This product includes software developed by Callum McColl.
 *
 * 4. Neither the name of the author nor the names of contributors
 *    may be used to endorse or promote products derived from this
 *    software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
 * OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * -----------------------------------------------------------------------
 * This program is free software; you can redistribute it and/or
 * modify it under the above terms or under the terms of the GNU
 * General Public License as published by the Free Software Foundation;
 * either version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see http://www.gnu.org/licenses/
 * or write to the Free Software Foundation, Inc., 51 Franklin Street,
 * Fifth Floor, Boston, MA  02110-1301, USA.
 *
 */

import GUUnits
import GURobots
import SceneKit
import MetalKit

public class FieldSceneRenderer {
    
    var scene: FieldScene
    
    private let device: MTLDevice
    private let renderer: SCNRenderer
    private let commandQueue: MTLCommandQueue
    private let frame: CGRect
    private let width: Int
    private let height: Int
    private let bufferPool: CVPixelBufferPool
    private let textureCache: CVMetalTextureCache
    
    
    public init(scene: FieldScene, resWidth: Pixels_u, resHeight: Pixels_u) {
        self.scene = scene
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Unable to get metal default system device.")
        }
        self.device = device
        self.renderer = SCNRenderer(device: device, options: nil)
        self.renderer.scene = scene.scene
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Unable to create command queue.")
        }
        self.commandQueue = commandQueue
        self.width = Int(resWidth)
        self.height = Int(resHeight)
        self.frame = CGRect(x: 0, y: 0, width: width, height: height)
        var bufferPool: CVPixelBufferPool? = nil
        if kCVReturnSuccess != CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            [kCVPixelBufferPoolMinimumBufferCountKey: 30] as CFDictionary,
            [
                kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey: width,
                kCVPixelBufferHeightKey: height,
                kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
            ] as CFDictionary,
            &bufferPool
        ) {
            fatalError("Unable to create buffer pool.")
        }
        guard let bufferPoolNonOpt = bufferPool else {
            fatalError("Failed to create buffer pool.")
        }
        self.bufferPool = bufferPoolNonOpt
        var tempTextureCache: CVMetalTextureCache? = nil
        if kCVReturnSuccess != CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, self.device, nil, &tempTextureCache) {
            fatalError("Unable to create texture cache.")
        }
        guard let textureCache = tempTextureCache else {
            fatalError("Failed to create texture cache.")
        }
        self.textureCache = textureCache
    }
    
    public func renderPixelBuffer<Robot: FieldRobot>(of field: Field<Robot>, inCamera camera: FieldCamera, atTime renderTime: TimeInterval = TimeInterval(0), antialiasingMode: SCNAntialiasingMode = .none) -> CVPixelBuffer {
        self.scene.scene.rootNode.addChildNode(camera.cameraNode)
        defer { camera.cameraNode.removeFromParentNode() }
        self.renderer.pointOfView = camera.cameraNode
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            fatalError("Unable to create command buffer.")
        }
        let pixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        var tempPixelBuffer: CVPixelBuffer? = nil
        if kCVReturnSuccess != CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, self.bufferPool, [kCVPixelBufferPoolAllocationThresholdKey: 30] as CFDictionary, &tempPixelBuffer) {
            fatalError("Unable to create pixelBuffer.")
        }
        guard let pixelBuffer = tempPixelBuffer else {
            fatalError("Failed to create pixelBuffer.")
        }
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer), mipmapped: false)
        let textureAttributes = [
            kCVMetalTextureUsage: textureDescriptor.usage,
            kCVMetalTextureStorageMode: textureDescriptor.storageMode
        ] as CFDictionary
        var tempTextureRef: CVMetalTexture? = nil
        if kCVReturnSuccess != CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCache, pixelBuffer, textureAttributes, pixelFormat, width, height, 0, &tempTextureRef) {
            fatalError("Unable to create texture.")
        }
        guard let textureRef = tempTextureRef, let texture = CVMetalTextureGetTexture(textureRef) else {
            fatalError("Failed to create texture.")
        }
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        renderPassDescriptor.depthAttachment.depthResolveFilter = .max
        renderPassDescriptor.depthAttachment.loadAction = .clear

        renderPassDescriptor.depthAttachment.storeAction = .store
        var sampleCount: Int
        switch antialiasingMode {
        case .none:
            sampleCount = 1
        case .multisampling2X:
            sampleCount = 2
        case .multisampling4X:
            sampleCount = 4
        case .multisampling8X:
            sampleCount = 8
        case .multisampling16X:
            sampleCount = 16
        default:
            fatalError("Antialiasing mode currently unsupported.")
        }
        while sampleCount > 1 {
            if self.device.supportsTextureSampleCount(sampleCount) {
                break
            }
            sampleCount = sampleCount / 2
        }
        if sampleCount > 1 {
            guard let multiSampleTextureDescriptor = textureDescriptor.copy() as? MTLTextureDescriptor else {
                fatalError("Unable to copy texture descriptor.")
            }
            multiSampleTextureDescriptor.textureType = .type2DMultisample
            multiSampleTextureDescriptor.usage = .renderTarget
            multiSampleTextureDescriptor.sampleCount = sampleCount
            multiSampleTextureDescriptor.storageMode = .private
            guard let multiSampleTexture = self.device.makeTexture(descriptor: multiSampleTextureDescriptor) else {
                fatalError("Unable to create multi sample texture.")
            }
            renderPassDescriptor.colorAttachments[0].texture = multiSampleTexture
            renderPassDescriptor.colorAttachments[0].resolveTexture = texture
            renderPassDescriptor.colorAttachments[0].storeAction = .storeAndMultisampleResolve
        } else {
            renderPassDescriptor.colorAttachments[0].texture = texture
            renderPassDescriptor.colorAttachments[0].storeAction = .store
        }
        self.renderer.render(atTime: renderTime, viewport: self.frame, commandBuffer: commandBuffer, passDescriptor: renderPassDescriptor)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return pixelBuffer
    }
    
    public func renderImage<Robot: FieldRobot>(of field: Field<Robot>, inCamera camera: FieldCamera, atTime renderTime: TimeInterval = TimeInterval(0), antialiasingMode: SCNAntialiasingMode = .none) -> NSImage {
        let pixelBuffer = self.renderPixelBuffer(of: field, inCamera: camera, atTime: renderTime, antialiasingMode: antialiasingMode)
        let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: self.frame) else {
            fatalError("Unable to create CGImage.")
        }
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        return nsImage
    }
    
}
