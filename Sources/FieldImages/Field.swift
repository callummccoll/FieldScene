/*
 * Field.swift
 * 
 *
 * Created by Callum McColl on 4/8/20.
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
import GUCoordinates
import Nao
import Foundation
import SceneKit
import AppKit

public enum CameraPerspective: Equatable {
    
    case none
    case playerTop
    case playerBottom
    
}

public struct Field {
    
    public var player: ManageableNaoV5
    
    public var teamMates: [ManageableNaoV5]
    
    public var opponents: [ManageableNaoV5]
    
    public init(player: ManageableNaoV5, teamMates: [ManageableNaoV5] = [], opponents: [ManageableNaoV5] = []) {
        self.player = player
        self.teamMates = teamMates
        self.opponents = opponents
    }
    
    @available(macOS 10.12, *)
    public func image(perspective: CameraPerspective = .none) -> NSImage {
        // retrieve the SCNView
        let scnView = SCNView(
            frame: NSRect(x: 0, y: 0, width: 640, height: 480),
            options: ["renderingAPI": SCNRenderingAPI.metal]
        )
        scnView.backgroundColor = .black
        // set the scene to the view
        scnView.scene = self.scene(perspective: perspective)
        return scnView.snapshot()
    }
    
    private var awayGoal: SCNNode {
        let awayGoal = SCNScene(named: bundle + "/field.scnassets/goal.scn")!.rootNode.childNode(withName: "goal", recursively: true)!
        awayGoal.position.x = 4.55
        awayGoal.position.y = 0.001
        return awayGoal
    }
    
    private let bundle = "FieldImages_FieldImages.bundle"
    
    private func camera(perspective: CameraPerspective) -> SCNCamera {
        guard nil != self.player.fieldPosition else {
            return SCNCamera()
        }
        let naoCamera: Camera
        switch perspective {
        case .playerTop:
            naoCamera = self.player.topCamera
        case .playerBottom:
            naoCamera = self.player.bottomCamera
        case .none:
            return SCNCamera()
        }
        let camera = SCNCamera()
        camera.xFov = Double(naoCamera.hFov.degrees_d)
        camera.yFov = Double(naoCamera.vFov.degrees_d)
        camera.zNear = 0.3
        return camera
    }
    
    private func cameraNode(perspective: CameraPerspective) -> SCNNode {
        let node = SCNNode()
        func noPerspective() -> SCNNode {
            node.position = SCNVector3(x: 0, y: 8, z: 0)
            node.eulerAngles.x = CGFloat.pi / -2.0
            node.camera = self.camera(perspective: perspective)
            return node
        }
        let naoPath: KeyPath<Self, ManageableNaoV5>
        let naoCameraPivotPath: KeyPath<Self, CameraPivot>
        let naoCameraPath: KeyPath<Self, Camera>
        switch perspective {
        case .playerTop:
            naoPath = \.player
            naoCameraPivotPath = \.player.topCameraPivot
            naoCameraPath = \.player.topCamera
        case .playerBottom:
            naoPath = \.player
            naoCameraPivotPath = \.player.bottomCameraPivot
            naoCameraPath = \.player.bottomCamera
        case .none:
            return noPerspective()
        }
        guard let fieldPosition = self[keyPath: naoPath].fieldPosition else {
            return noPerspective()
        }
        let cameraPivot = self[keyPath: naoCameraPivotPath]
        let naoCamera = self[keyPath: naoCameraPath]
        node.position.z = CGFloat(Metres_d(fieldPosition.position.x))
        node.position.x = CGFloat(Metres_d(fieldPosition.position.y))
        node.position.y = CGFloat(cameraPivot.height.metres_d + naoCamera.height.metres_d)
        let yaw = fieldPosition.heading.radians_d + cameraPivot.yaw.radians_d
        let pitch = cameraPivot.pitch.radians_d + naoCamera.vDirection.radians_d
        node.eulerAngles.z = CGFloat(-pitch)
        node.eulerAngles.y = CGFloat(yaw) + CGFloat.pi
        node.camera = self.camera(perspective: perspective)
        return node
    }
    
    private var field: SCNNode {
        return SCNScene(named: bundle + "/field.scnassets/field.scn")!.rootNode.childNode(withName: "field", recursively: true)!
    }
    
    private var homeGoal: SCNNode {
        let homeGoal = SCNScene(named: bundle + "/field.scnassets/goal.scn")!.rootNode.childNode(withName: "goal", recursively: true)!
        homeGoal.position.x = -4.55
        homeGoal.position.y = 0.001
        homeGoal.rotation.y = 1.0
        homeGoal.rotation.w = CGFloat(Double.pi)
        return homeGoal
    }
    
    private var lights: [SCNNode] {
        let lightCoordinates: [(x: CGFloat, z: CGFloat)] = [(0, 0), (4, 2.5), (-4, 2.5), (4, -2.5), (-4, -2.5)]
        return lightCoordinates.map {
            let light = SCNLight()
            light.type = .omni
            light.intensity = 6000
            light.attenuationStartDistance = 0
            light.attenuationEndDistance = 20
            light.attenuationFalloffExponent = 4
            light.castsShadow = true
            let node = SCNNode()
            node.light = light
            node.position.x = $0.x
            node.position.z = $0.z
            node.position.y = 10
            return node
        }
    }
    
    private var playerNao: SCNNode {
        let nao = SCNScene(named: bundle + "/nao.scnassets/nao.scn")!.rootNode.childNode(withName: "nao", recursively: true)!
        guard let fieldPosition = self.player.fieldPosition else {
            return nao
        }
        let cameraPivot = self.player.topCameraPivot
        let yaw = fieldPosition.heading.radians_d + cameraPivot.yaw.radians_d
        nao.position.z = CGFloat(Metres_d(fieldPosition.position.x))
        nao.position.x = CGFloat(Metres_d(fieldPosition.position.y))
        nao.position.y = 0.001
        nao.eulerAngles.y = CGFloat(yaw) - CGFloat.pi / 2.0
        return nao
    }
    
    private func scene(perspective: CameraPerspective) -> SCNScene {
        // create a new scene
        let scene = SCNScene()
        scene.rootNode.addChildNode(self.field)
        scene.rootNode.addChildNode(self.homeGoal)
        scene.rootNode.addChildNode(self.awayGoal)
        // add Lights
        self.lights.forEach(scene.rootNode.addChildNode)
        // Add nao
        if nil != self.player.fieldPosition {
            scene.rootNode.addChildNode(self.playerNao)
        }
        // Add camera to the scene
        scene.rootNode.addChildNode(self.cameraNode(perspective: perspective))
        return scene
    }
    
}
