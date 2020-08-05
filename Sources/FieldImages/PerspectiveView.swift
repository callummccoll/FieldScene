//
/*
 * PerspectiveView.swift
 * FieldImages
 *
 * Created by Callum McColl on 6/8/20.
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

import SwiftUI
import GUCoordinates
import Nao
import SceneKit

public struct PerspectiveView: NSViewRepresentable {
    
    private class Data {
        
        let bundle: String = "FieldImages_FieldImages.bundle"
        
        var scene: SCNScene = SCNScene()
        
        var cameraNode: SCNNode = SCNNode()
        
        var camera: SCNCamera = SCNCamera()
        
        var homeRobotNodes: [Int: SCNNode] = [:]
        
        var awayRobotNodes: [Int: SCNNode] = [:]
        
        var lightNodes: [SCNNode] = []
        
    }
    
    public var perspective: Perspective
    
    public var field: Field
    
    public var lightIntensity: CGFloat
    
    private let data: Data = Data()
    
    public init(field: Field = Field(), perspective: Perspective = .none, lightIntensity: CGFloat = 6000) {
        self.field = field
        self.perspective = perspective
        self.lightIntensity = lightIntensity
    }
    
    public func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .black
        let scene = data.scene
        // Field
        let field = SCNScene(named: self.data.bundle + "/field.scnassets/field.scn")!.rootNode.childNode(withName: "field", recursively: true)!
        scene.rootNode.addChildNode(field)
        // Lights
        let lightCoordinates: [(x: CGFloat, z: CGFloat)] = [(0, 0), (4, 2.5), (-4, 2.5), (4, -2.5), (-4, -2.5)]
        lightCoordinates.forEach {
            let light = SCNLight()
            light.type = .omni
            light.intensity = self.lightIntensity
            light.attenuationStartDistance = 0
            light.attenuationEndDistance = 20
            light.attenuationFalloffExponent = 4
            light.castsShadow = true
            let node = SCNNode()
            node.light = light
            node.position.x = $0.x
            node.position.z = $0.z
            node.position.y = 10
            self.data.lightNodes.append(node)
            scene.rootNode.addChildNode(node)
            // Home Goal
            let homeGoal = SCNScene(named: self.data.bundle + "/field.scnassets/goal.scn")!.rootNode.childNode(withName: "goal", recursively: true)!
            homeGoal.position.x = -4.55
            homeGoal.position.y = 0.001
            homeGoal.rotation.y = 1.0
            homeGoal.rotation.w = CGFloat(Double.pi)
            scene.rootNode.addChildNode(homeGoal)
            // Away Goal
            let awayGoal = SCNScene(named: self.data.bundle + "/field.scnassets/goal.scn")!.rootNode.childNode(withName: "goal", recursively: true)!
            awayGoal.position.x = 4.55
            awayGoal.position.y = 0.001
            scene.rootNode.addChildNode(awayGoal)
            // Robots
            for (index, homeNao) in self.field.homeRobots.enumerated() {
                let nao = self.createNaoNode(for: homeNao)
                self.data.homeRobotNodes[index] = nao
                scene.rootNode.addChildNode(nao)
            }
            for (index, awayNao) in self.field.awayRobots.enumerated() {
                let nao = self.createNaoNode(for: awayNao)
                self.data.awayRobotNodes[index] = nao
                scene.rootNode.addChildNode(nao)
            }
            // Camera
            let (cameraNode, camera) = self.createCameraNode(for: self.perspective)
            self.data.cameraNode = cameraNode
            self.data.camera = camera
            scene.rootNode.addChildNode(cameraNode)
        }
        return scnView
    }
    
    public func updateNSView(_ nsView: NSViewType, context: Context) {
        self.syncRobotNodes()
        self.updateCameraNode(self.data.cameraNode, camera: self.data.camera, to: self.perspective)
    }
    
    private func syncRobotNodes() {
        func sync(robots: [ManageableNaoV5], nodeCount: Int, get: (Int) -> SCNNode, assign: (Int, SCNNode) -> Void, remove: (Int) -> Void) {
            if robots.count < nodeCount {
                let indexRange = robots.count..<nodeCount
                indexRange.forEach(remove)
            } else if robots.count > nodeCount {
                let firstIndex = nodeCount
                for (index, robot) in robots[nodeCount..<robots.count].enumerated() {
                    let actualIndex = firstIndex + index
                    let node = self.createNaoNode(for: robot)
                    assign(actualIndex, SCNNode())
                    self.data.scene.rootNode.addChildNode(node)
                }
            }
            for (index, robot) in robots.enumerated() {
                let node = get(index)
                self.updateNaoNode(node, for: robot)
            }
        }
        sync(
            robots: self.field.homeRobots,
            nodeCount: self.data.homeRobotNodes.count,
            get: { self.data.homeRobotNodes[$0]! },
            assign: { self.data.homeRobotNodes[$0] = $1 },
            remove: {self.data.homeRobotNodes[$0]!.removeFromParentNode() }
        )
        sync(
            robots: self.field.awayRobots,
            nodeCount: self.data.awayRobotNodes.count,
            get: { self.data.awayRobotNodes[$0]! },
            assign: { self.data.awayRobotNodes[$0] = $1 },
            remove: {self.data.awayRobotNodes[$0]!.removeFromParentNode() }
        )
    }
    
    private func createNaoNode(for nao: ManageableNaoV5) -> SCNNode {
        let node = SCNScene(named: self.data.bundle + "/nao.scnassets/nao.scn")!.rootNode.childNode(withName: "nao", recursively: true)!
        self.updateNaoNode(node, for: nao)
        return node
    }
    
    private func updateNaoNode(_ node: SCNNode, for nao: ManageableNaoV5) {
        guard let fieldPosition = nao.fieldPosition else {
            return
        }
        let yaw = fieldPosition.heading.radians_d
        node.position.z = CGFloat(Metres_d(fieldPosition.position.x))
        node.position.x = CGFloat(Metres_d(fieldPosition.position.y))
        node.position.y = 0.001
        node.eulerAngles.y = CGFloat(yaw) - CGFloat.pi / 2.0
        return
    }
    
    private func createCameraNode(for perspective: Perspective) -> (SCNNode, SCNCamera) {
        let node = SCNNode()
        let camera = SCNCamera()
        node.camera = camera
        self.updateCameraNode(node, camera: camera, to: perspective)
        return (node, camera)
    }
    
    private func updateCameraNode(_ node: SCNNode, camera: SCNCamera, to perspective: Perspective) {
        func noPerspective() {
            node.position = SCNVector3(x: 0, y: 8, z: 0)
            node.eulerAngles.x = CGFloat.pi / -2.0
            let tempCamera = SCNCamera()
            camera.xFov = tempCamera.xFov
            camera.yFov = tempCamera.yFov
            camera.zNear = tempCamera.zNear
        }
        let robot: ManageableNaoV5
        let cameraPivot: CameraPivot
        let naoCamera: Camera
        switch perspective {
        case .home(let index, let cameraPerspective):
            robot = self.field.homeRobots[index]
            let temp = self.robotCamera(for: cameraPerspective, of: robot)
            cameraPivot = temp.0
            naoCamera = temp.1
        case .away(let index, let cameraPerspective):
            robot = self.field.homeRobots[index]
            let temp = self.robotCamera(for: cameraPerspective, of: robot)
            cameraPivot = temp.0
            naoCamera = temp.1
        case .none:
            noPerspective()
            return
        }
        guard let fieldPosition = robot.fieldPosition else {
            noPerspective()
            return
        }
        camera.xFov = Double(naoCamera.hFov.degrees_d)
        camera.yFov = Double(naoCamera.vFov.degrees_d)
        camera.zNear = 0.3
        node.position.z = CGFloat(Metres_d(fieldPosition.position.x))
        node.position.x = CGFloat(Metres_d(fieldPosition.position.y))
        node.position.y = CGFloat(cameraPivot.height.metres_d + naoCamera.height.metres_d)
        let yaw = fieldPosition.heading.radians_d + cameraPivot.yaw.radians_d
        let pitch = cameraPivot.pitch.radians_d + naoCamera.vDirection.radians_d
        node.eulerAngles.z = CGFloat(-pitch)
        node.eulerAngles.y = CGFloat(yaw) + CGFloat.pi
    }
    
    private func robotCamera(for cameraPerspective: CameraPerspective, of robot: ManageableNaoV5) -> (CameraPivot, Camera) {
        switch cameraPerspective {
        case .top:
            return (robot.topCameraPivot, robot.topCamera)
        case .bottom:
            return (robot.bottomCameraPivot, robot.bottomCamera)
        }
    }
    
}

struct PerspectiveView_Previews: PreviewProvider {
    static var previews: some View {
        PerspectiveView()
    }
}
