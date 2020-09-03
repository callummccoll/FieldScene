/*
 * FieldCamera.swift
 * FieldScene
 *
 * Created by Callum McColl on 14/8/20.
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

import SceneKit
import GUCoordinates
import GURobots

public final class FieldCamera {
    
    public struct CameraPerspective<Robot>: Equatable {
        
        public var cameraPivot: KeyPath<Robot, CameraPivot>
        
        public var camera: KeyPath<Robot, Camera>
        
    }
    
    public enum Perspective<Robot>: Equatable {
        
        case sky
        case robot(side: FieldSide, index: Int, cameraPerspective: CameraPerspective<Robot>)
        case custom(hFov: Angle, vFov: Angle, transform: SCNMatrix4)
        
        public static func away(index: Int, cameraPerspective: CameraPerspective<Robot>) -> Perspective<Robot> {
            return .robot(side: .away, index: index, cameraPerspective: cameraPerspective)
        }
        
        public static func home(index: Int, cameraPerspective: CameraPerspective<Robot>) -> Perspective<Robot> {
            return .robot(side: .home, index: index, cameraPerspective: cameraPerspective)
        }
        
        public static func == (lhs: Perspective<Robot>, rhs: Perspective<Robot>) -> Bool {
            switch (lhs, rhs) {
            case (.sky, .sky):
                return true
            case (.robot(let lside, let lindex, let lperspective), .robot(let rside, let rindex, let rperspective)):
                return lside == rside && lindex == rindex && lperspective == rperspective
            case (.custom(let lhFov, let lvFov, let lmat), .custom(let rhFov, let rvFov, let rmat)):
                return lhFov.degrees_d == rhFov.degrees_d
                    && lvFov.degrees_d == rvFov.degrees_d
                    && lmat.m11 == rmat.m11
                    && lmat.m12 == rmat.m12
                    && lmat.m13 == rmat.m13
                    && lmat.m14 == rmat.m14
                    && lmat.m21 == rmat.m21
                    && lmat.m22 == rmat.m22
                    && lmat.m23 == rmat.m23
                    && lmat.m24 == rmat.m24
                    && lmat.m31 == rmat.m31
                    && lmat.m32 == rmat.m32
                    && lmat.m33 == rmat.m33
                    && lmat.m34 == rmat.m34
                    && lmat.m41 == rmat.m41
                    && lmat.m42 == rmat.m42
                    && lmat.m43 == rmat.m43
                    && lmat.m44 == rmat.m44
            default:
                return false
            }
        }
        
    }
    
    public private(set) var camera: SCNCamera
    
    public private(set) var cameraNode: SCNNode
    
    public init<Robot: FieldRobot>(field: Field<Robot>, perspective: Perspective<Robot>) {
        self.cameraNode = SCNNode()
        self.camera = SCNCamera()
        self.cameraNode.camera = self.camera
        self.updateCameraNode(self.cameraNode, camera: self.camera, to: perspective, in: field)
    }
    
    deinit {
        self.cameraNode.removeFromParentNode()
    }
    
    public func update<Robot: FieldRobot>(perspective: Perspective<Robot>, in field: Field<Robot>) {
        self.updateCameraNode(self.cameraNode, camera: self.camera, to: perspective, in: field)
    }
    
    private func updateCameraNode<Robot: FieldRobot>(_ node: SCNNode, camera: SCNCamera, to perspective: Perspective<Robot>, in field: Field<Robot>) {
        func noPerspective() {
            node.position = SCNVector3(x: 0, y: 8, z: 0)
            node.eulerAngles.x = CGFloat.pi / -2.0
            node.eulerAngles.y = 0.0
            node.eulerAngles.z = 0.0
            let tempCamera = SCNCamera()
            camera.xFov = tempCamera.xFov
            camera.yFov = tempCamera.yFov
            camera.zNear = 0.3
        }
        let robot: Robot
        let cameraPivot: CameraPivot
        let robotCamera: Camera
        switch perspective {
        case .robot(let side, let index, let cameraPerspective):
            if side == .home {
                robot = field.homeRobots[index]
            } else {
                robot = field.awayRobots[index]
            }
            cameraPivot = robot[keyPath: cameraPerspective.cameraPivot]
            robotCamera = robot[keyPath: cameraPerspective.camera]
        case .sky:
            noPerspective()
            return
        case .custom(let hFov, let vFov, let mat):
            camera.xFov = Double(hFov.degrees_d)
            camera.yFov = Double(vFov.degrees_d)
            node.transform = mat
            return
        }
        guard let fieldPosition = robot.fieldPosition else {
            noPerspective()
            return
        }
        camera.xFov = Double(robotCamera.hFov.degrees_d)
        camera.yFov = Double(robotCamera.vFov.degrees_d)
        camera.zNear = 0.3
        let yaw = CGFloat(Radians_d((fieldPosition.heading.degrees_d + cameraPivot.yaw.degrees_d)))
        let pitch = CGFloat(cameraPivot.pitch.radians_d + robotCamera.vDirection.radians_d)
        node.transform = SCNMatrix4Identity
        node.transform = SCNMatrix4Rotate(node.transform, CGFloat.pi + yaw, 0, 1.0, 0)
        node.transform = SCNMatrix4Rotate(node.transform, -pitch, 1.0, 0, 0)
        node.transform = SCNMatrix4Translate(
            node.transform,
            CGFloat(Metres_d(fieldPosition.position.y)),
            CGFloat(cameraPivot.height.metres_d + robotCamera.height.metres_d),
            CGFloat(Metres_d(fieldPosition.position.x))
        )
    }
    
}

extension FieldCamera.CameraPerspective where Robot: TopCameraContainer {
    
    public static var top: FieldCamera.CameraPerspective<Robot> {
        return FieldCamera.CameraPerspective<Robot>(cameraPivot: \.topCameraPivot, camera: \.topCamera)
    }
    
}

extension FieldCamera.CameraPerspective where Robot: BottomCameraContainer {
    
    public static var bottom: FieldCamera.CameraPerspective<Robot> {
        return FieldCamera.CameraPerspective<Robot>(cameraPivot: \.bottomCameraPivot, camera: \.bottomCamera)
    }
    
}
