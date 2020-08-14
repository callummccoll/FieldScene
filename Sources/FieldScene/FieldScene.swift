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

public final class FieldScene {
    
    public enum RobotModel: String, Equatable {
        
        case nao
        
    }
    
    private let robotModel: RobotModel
    
    public private(set) var scene: SCNScene = SCNScene()
    
    public private(set) var homeRobotNodes: [Int: SCNNode] = [:]
    
    public private(set) var awayRobotNodes: [Int: SCNNode] = [:]
    
    public private(set) var lightNodes: [SCNNode] = []
    
    private var robotNode: SCNNode = SCNNode()
    
    private let packageBundleName = "FieldScene_FieldScene"
    
    private lazy var resourcesURL: URL? = {
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
    
    public init<Robot: FieldPositionContainer>(field: Field<Robot>, robotModel: RobotModel = .nao) {
        self.robotModel = robotModel
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
        self.robotNode = self.loadNode(named: robotModel.rawValue)
        for (index, homeRobot) in field.homeRobots.enumerated() {
            let robotNode = self.createRobotNode(for: homeRobot)
            homeRobotNodes[index] = robotNode
            scene.rootNode.addChildNode(robotNode)
        }
        for (index, awayRobot) in field.awayRobots.enumerated() {
            let robotNode = self.createRobotNode(for: awayRobot)
            awayRobotNodes[index] = robotNode
            scene.rootNode.addChildNode(robotNode)
        }
        self.fixResourcePaths(ofNode: fieldNode)
        self.fixResourcePaths(ofNode: homeGoal)
        self.fixResourcePaths(ofNode: awayGoal)
    }
    
    private func loadNode(named name: String) -> SCNNode {
        let path = bundle + "/" + name + ".scnassets/" + name + ".scn"
        guard let node = SCNScene(named: path)?.rootNode.childNode(withName: name, recursively: true) else {
            fatalError("Unable to get " + name + " node.")
        }
        self.fixResourcePaths(ofNode: node)
        return node
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
            $0.diffuse.contents = fixContents($0.diffuse.contents) ?? $0.diffuse.contents
            $0.normal.contents = fixContents($0.normal.contents) ?? $0.normal.contents
            $0.reflective.contents = fixContents($0.reflective.contents) ?? $0.reflective.contents
            $0.transparent.contents = fixContents($0.transparent.contents) ?? $0.transparent.contents
            $0.ambientOcclusion.contents = fixContents($0.ambientOcclusion.contents) ?? $0.ambientOcclusion.contents
            $0.selfIllumination.contents = fixContents($0.selfIllumination.contents) ?? $0.selfIllumination.contents
            $0.emission.contents = fixContents($0.emission.contents) ?? $0.emission.contents
            $0.multiply.contents = fixContents($0.multiply.contents) ?? $0.multiply.contents
            $0.ambient.contents = fixContents($0.ambient.contents) ?? $0.ambient.contents
            $0.displacement.contents = fixContents($0.displacement.contents) ?? $0.displacement.contents
        }
        node.childNodes.forEach(fixResourcePaths)
    }
    
    public func renderImage<Robot: FieldPositionContainer>(of field: Field<Robot>, inCamera camera: FieldCamera, resWidth: Pixels_u = 1920, resHeight: Pixels_u = 1080) -> NSImage {
        let view = SCNView(frame: NSRect(x: 0, y: 0, width: Int(resWidth), height: Int(resHeight)))
        self.scene.rootNode.addChildNode(camera.cameraNode)
        view.scene = self.scene
        let image = view.snapshot()
        camera.cameraNode.removeFromParentNode()
        return image
    }
    
    public func update<Robot: FieldPositionContainer>(from field: Field<Robot>) {
        self.syncRobotNodes(to: field)
    }
    
    private func syncRobotNodes<Robot: FieldPositionContainer>(to field: Field<Robot>) {
        func sync(robots: [Robot], nodeCount: Int, get: (Int) -> SCNNode?, assign: (Int, SCNNode) -> Void, remove: (Int) -> Void) {
            if robots.count < nodeCount {
                let indexRange = robots.count..<nodeCount
                indexRange.forEach(remove)
            } else if robots.count > nodeCount {
                let firstIndex = nodeCount
                for (index, robot) in robots[nodeCount..<robots.count].enumerated() {
                    let actualIndex = firstIndex + index
                    let node: SCNNode
                    if let temp = get(actualIndex) {
                        node = temp
                    } else {
                        let temp = self.createRobotNode(for: robot)
                        node = temp
                        assign(actualIndex, node)
                    }
                    scene.rootNode.addChildNode(node)
                }
            }
            for (index, robot) in robots.enumerated() {
                self.updateRobotNode(get(index)!, for: robot)
            }
        }
        sync(
            robots: field.homeRobots,
            nodeCount: homeRobotNodes.count,
            get: { homeRobotNodes[$0] },
            assign: { homeRobotNodes[$0] = $1 },
            remove: { homeRobotNodes[$0]?.removeFromParentNode() }
        )
        sync(
            robots: field.awayRobots,
            nodeCount: awayRobotNodes.count,
            get: { awayRobotNodes[$0] },
            assign: { awayRobotNodes[$0] = $1 },
            remove: {awayRobotNodes[$0]?.removeFromParentNode() }
        )
    }
    
    private func createRobotNode<Robot: FieldPositionContainer>(for robot: Robot) -> SCNNode {
        let node = self.robotNode.flattenedClone()
        self.updateRobotNode(node, for: robot)
        return node
    }
    
    private func updateRobotNode<Robot: FieldPositionContainer>(_ node: SCNNode, for robot: Robot) {
        guard let fieldPosition = robot.fieldPosition else {
            return
        }
        let yaw = fieldPosition.heading.radians_d
        node.position.z = CGFloat(Metres_d(fieldPosition.position.x))
        node.position.x = CGFloat(Metres_d(fieldPosition.position.y))
        node.position.y = 0.101
        node.eulerAngles.y = CGFloat(yaw) - CGFloat.pi / 2.0
        return
    }
    
}
