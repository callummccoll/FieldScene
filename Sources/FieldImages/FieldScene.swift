/*
 * FieldScene.swift
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

import SceneKit

import GUUnits
import GUCoordinates
import GURobots

public class FieldScene<Robot: FieldRobot> {
    
    public enum CameraPerspective: Equatable {
        
        case top
        case bottom
        
    }
    
    public enum Perspective: Equatable {
        
        case none
        case home(index: Int, cameraPerspective: CameraPerspective)
        case away(index: Int, cameraPerspective: CameraPerspective)
        
    }
    
    public var scnView: SCNView = SCNView()
    
    public var scene: SCNScene = SCNScene()
    
    public var cameraNode: SCNNode = SCNNode()
    
    public var camera: SCNCamera = SCNCamera()
    
    public var homeRobotNodes: [Int: SCNNode] = [:]
    
    public var awayRobotNodes: [Int: SCNNode] = [:]
    
    public var lightNodes: [SCNNode] = []
    
    private let packageBundleName = "fieldImages_FieldImages"
    
    private lazy var resourcesURL: URL? = {
        let packageBundleName = "FieldImages_FieldImages"
        let expectedBundle = Bundle.main.bundleURL.appendingPathComponent("Contents", isDirectory: true).appendingPathComponent("Resources", isDirectory: true).appendingPathComponent(packageBundleName + ".bundle", isDirectory: true).appendingPathComponent("Contents", isDirectory: true).appendingPathComponent("Resources", isDirectory: true)
        if FileManager.default.fileExists(atPath: expectedBundle.path) {
            return expectedBundle
        }
        return nil
    }()
    
    private lazy var bundle: String = {
        let expectedBundle = Bundle.main.bundleURL.appendingPathComponent("Contents", isDirectory: true).appendingPathComponent("Resources", isDirectory: true).appendingPathComponent(packageBundleName + ".bundle", isDirectory: true).appendingPathComponent("Contents", isDirectory: true).appendingPathComponent("Resources", isDirectory: true).path
        if FileManager.default.fileExists(atPath: expectedBundle) {
            return packageBundleName + ".bundle/Contents/Resources"
        }
        guard let bundle = Bundle.allBundles.first(where : {
            return FileManager.default.fileExists(atPath: $0.bundleURL.appendingPathComponent(packageBundleName + ".bundle", isDirectory: true).path)
        }) else {
            fatalError("Unable to locate bundle in \(Bundle.allBundles.map { $0.bundlePath }), mainBundle: \(Bundle.main.bundlePath)")
        }
        return packageBundleName + ".bundle"
    }()
    
    public init(field: Field<Robot>, perspective: Perspective) {
        scnView.backgroundColor = .black
        // Field
        let fieldScenePath = self.bundle + "/field.scnassets"
        guard let fieldNode = SCNScene(named: "field.scn", inDirectory: fieldScenePath)?.rootNode.childNode(withName: "field", recursively: true) else {
            fatalError("Unable to load field node from scene: \(fieldScenePath).")
        }
        self.fixResourcePaths(ofNode: fieldNode)
        scene.rootNode.addChildNode(fieldNode)
        // Lights
        let lightCoordinates: [(x: CGFloat, z: CGFloat)] = [(0, 0), (4, 2.5), (-4, 2.5), (4, -2.5), (-4, -2.5)]
        lightCoordinates.forEach {
            let light = SCNLight()
            light.type = .omni
            light.intensity = CGFloat(field.lightIntensity)
            light.attenuationStartDistance = 0
            light.attenuationEndDistance = 20
            light.attenuationFalloffExponent = 4
            light.castsShadow = true
            let node = SCNNode()
            node.light = light
            node.position.x = $0.x
            node.position.z = $0.z
            node.position.y = 10
            lightNodes.append(node)
            scene.rootNode.addChildNode(node)
        }
        // Home Goal
        guard let homeGoal = SCNScene(named: bundle + "/field.scnassets/goal.scn")?.rootNode.childNode(withName: "goal", recursively: true) else {
            fatalError("Unable to get home goal node.")
        }
        homeGoal.position.x = -4.55
        homeGoal.position.y = 0.101
        homeGoal.rotation.y = 1.0
        homeGoal.rotation.w = CGFloat(Double.pi)
        scene.rootNode.addChildNode(homeGoal)
        // Away Goal
        guard let awayGoal = SCNScene(named: bundle + "/field.scnassets/goal.scn")?.rootNode.childNode(withName: "goal", recursively: true) else {
            fatalError("Unable to get away goal node.")
        }
        awayGoal.position.x = 4.55
        awayGoal.position.y = 0.101
        scene.rootNode.addChildNode(awayGoal)
        // Robots
        for (index, homeNao) in field.homeRobots.enumerated() {
            let nao = self.createNaoNode(for: homeNao)
            homeRobotNodes[index] = nao
            scene.rootNode.addChildNode(nao)
        }
        for (index, awayNao) in field.awayRobots.enumerated() {
            let nao = self.createNaoNode(for: awayNao)
            awayRobotNodes[index] = nao
            scene.rootNode.addChildNode(nao)
        }
        // Camera
        let (cameraNode, camera) = self.createCameraNode(for: perspective, in: field)
        self.cameraNode = cameraNode
        self.camera = camera
        scene.rootNode.addChildNode(cameraNode)
        self.scnView.scene = scene
        self.fixResourcePaths(ofNode: fieldNode)
        self.fixResourcePaths(ofNode: homeGoal)
        self.fixResourcePaths(ofNode: awayGoal)
    }
    
    private func fixResourcePaths(ofNode node: SCNNode) {
        func fixPath(_ path: URL) -> URL? {
            let components = path.pathComponents.drop(while: { $0 != "FieldImages" }).drop(while: { $0 == "FieldImages"})
            if components.isEmpty {
                return nil
            }
            guard let resourcesURL = self.resourcesURL else {
                return nil
            }
            return URL(fileURLWithPath: components.reduce(resourcesURL.path) { $0 + "/" + $1 }, isDirectory: false)
        }
        func fixContents(_ contents: Any?) -> URL? {
            if let path = contents as? String {
                return fixPath(URL(fileURLWithPath: path, isDirectory: false))
            }
            if let path = contents as? URL {
                return fixPath(path)
            }
            return nil
        }
        node.geometry?.materials.forEach {
            guard let path = fixContents($0.diffuse.contents) else {
                return
            }
            $0.diffuse.contents = path
        }
        node.childNodes.forEach(fixResourcePaths)
    }
    
    public func renderImage(of field: Field<Robot>, from perspective: Perspective, resWidth: Pixels_u = 1920, resHeight: Pixels_u = 1080) -> NSImage {
        self.update(from: field, perspective: perspective)
        let view = SCNView(frame: NSRect(x: 0, y: 0, width: Int(resWidth), height: Int(resHeight)))
        view.scene = self.scene
        return view.snapshot()
    }
    
    public func update(from field: Field<Robot>, perspective: Perspective) {
        self.syncRobotNodes(to: field)
        self.updateCameraNode(self.cameraNode, camera: self.camera, to: perspective, in: field)
    }
    
    private func syncRobotNodes(to field: Field<Robot>) {
        func sync(robots: [Robot], nodeCount: Int, get: (Int) -> SCNNode, assign: (Int, SCNNode) -> Void, remove: (Int) -> Void) {
            if robots.count < nodeCount {
                let indexRange = robots.count..<nodeCount
                indexRange.forEach(remove)
            } else if robots.count > nodeCount {
                let firstIndex = nodeCount
                for (index, robot) in robots[nodeCount..<robots.count].enumerated() {
                    let actualIndex = firstIndex + index
                    let node = self.createNaoNode(for: robot)
                    assign(actualIndex, SCNNode())
                    scene.rootNode.addChildNode(node)
                }
            }
            for (index, robot) in robots.enumerated() {
                let node = get(index)
                self.updateNaoNode(node, for: robot)
            }
        }
        sync(
            robots: field.homeRobots,
            nodeCount: homeRobotNodes.count,
            get: { homeRobotNodes[$0]! },
            assign: { homeRobotNodes[$0] = $1 },
            remove: {homeRobotNodes[$0]!.removeFromParentNode() }
        )
        sync(
            robots: field.awayRobots,
            nodeCount: awayRobotNodes.count,
            get: { awayRobotNodes[$0]! },
            assign: { awayRobotNodes[$0] = $1 },
            remove: {awayRobotNodes[$0]!.removeFromParentNode() }
        )
    }
    
    private func createNaoNode(for nao: Robot) -> SCNNode {
        guard let node = SCNScene(named: bundle + "/nao.scnassets/nao.scn")?.rootNode.childNode(withName: "nao", recursively: true) else {
            fatalError("Unable to get nao node.")
        }
        self.fixResourcePaths(ofNode: node)
        self.updateNaoNode(node, for: nao)
        return node
    }
    
    private func updateNaoNode(_ node: SCNNode, for nao: Robot) {
        guard let fieldPosition = nao.fieldPosition else {
            return
        }
        let yaw = fieldPosition.heading.radians_d
        node.position.z = CGFloat(Metres_d(fieldPosition.position.x))
        node.position.x = CGFloat(Metres_d(fieldPosition.position.y))
        node.position.y = 0.101
        node.eulerAngles.y = CGFloat(yaw) - CGFloat.pi / 2.0
        return
    }
    
    private func createCameraNode(for perspective: Perspective, in field: Field<Robot>) -> (SCNNode, SCNCamera) {
        let node = SCNNode()
        let camera = SCNCamera()
        node.camera = camera
        self.updateCameraNode(node, camera: camera, to: perspective, in: field)
        return (node, camera)
    }
    
    private func updateCameraNode(_ node: SCNNode, camera: SCNCamera, to perspective: Perspective, in field: Field<Robot>) {
        func noPerspective() {
            node.position = SCNVector3(x: 0, y: 8, z: 0)
            node.eulerAngles.x = CGFloat.pi / -2.0
            node.eulerAngles.y = 0.0
            node.eulerAngles.z = 0.0
            let tempCamera = SCNCamera()
            camera.xFov = tempCamera.xFov
            camera.yFov = tempCamera.yFov
            camera.zNear = tempCamera.zNear
        }
        let robot: Robot
        let cameraPivot: CameraPivot
        let naoCamera: Camera
        switch perspective {
        case .home(let index, let cameraPerspective):
            robot = field.homeRobots[index]
            let temp = self.robotCamera(for: cameraPerspective, of: robot)
            cameraPivot = temp.0
            naoCamera = temp.1
        case .away(let index, let cameraPerspective):
            robot = field.awayRobots[index]
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
        let yaw = Radians_d((fieldPosition.heading.degrees_d + cameraPivot.yaw.degrees_d))
        let pitch = cameraPivot.pitch.radians_d + naoCamera.vDirection.radians_d
        node.eulerAngles.x = 0.0
        node.eulerAngles.y = CGFloat.pi
        node.eulerAngles.z = 0.0
        node.eulerAngles.z -= CGFloat(pitch)
        node.eulerAngles.y += CGFloat(yaw)
    }
    
    private func robotCamera(for cameraPerspective: CameraPerspective, of robot: Robot) -> (CameraPivot, Camera) {
        switch cameraPerspective {
        case .top:
            return (robot.topCameraPivot, robot.topCamera)
        case .bottom:
            return (robot.bottomCameraPivot, robot.bottomCamera)
        }
    }
    
}
