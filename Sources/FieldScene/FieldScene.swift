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
    
    public private(set) var ballNode: SCNNode = SCNNode()
    
    public private(set) var homeRobotNodes: [Int: SCNNode] = [:]
    
    public private(set) var awayRobotNodes: [Int: SCNNode] = [:]
    
    public private(set) var lightNodes: [SCNNode] = []
    
    private var robotNode: SCNNode = SCNNode()
    
    public init<Robot: FieldRobot>(field: Field<Robot>, robotModel: RobotModel = .nao) {
        self.robotModel = robotModel
        // Field
        let fieldNode = SCNNode.load("field", inPackage: "FieldScene")
        scene.rootNode.addChildNode(fieldNode.flattenedClone())
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
        let goalNode = SCNNode.load("goal", inAsset: "field", inPackage: "FieldScene")
        let homeGoal = goalNode.flattenedClone()
        homeGoal.position.x = -4.55
        homeGoal.position.y = 0.101
        homeGoal.rotation.y = 1.0
        homeGoal.rotation.w = CGFloat(Double.pi)
        scene.rootNode.addChildNode(homeGoal)
        // Away Goal
        let awayGoal = goalNode.flattenedClone()
        awayGoal.position.x = 4.55
        awayGoal.position.y = 0.101
        scene.rootNode.addChildNode(awayGoal)
        // Robots
        self.robotNode = SCNNode.load(robotModel.rawValue, inPackage: "FieldScene")
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
        // Ball
        self.ballNode = SCNNode.load("ball", inAsset: "field", inPackage: "FieldScene")
        self.updateBall(from: field.ball)
        scene.rootNode.addChildNode(self.ballNode)
    }
    
    public func renderImage<Robot: FieldRobot>(of field: Field<Robot>, inCamera camera: FieldCamera, resWidth: Pixels_u = 1920, resHeight: Pixels_u = 1080) -> NSImage {
        let view = SCNView(frame: NSRect(x: 0, y: 0, width: Int(resWidth), height: Int(resHeight)))
        view.scene = self.scene
        self.scene.rootNode.addChildNode(camera.cameraNode)
        view.pointOfView = camera.cameraNode
        view.backgroundColor = .white
        let image = view.snapshot()
        camera.cameraNode.removeFromParentNode()
        return image
    }
    
    public func update<Robot: FieldRobot>(from field: Field<Robot>) {
        self.syncRobotNodes(to: field)
        self.updateBall(from: field.ball)
    }
    
    private func updateBall(from ballPosition: BallPosition?) {
        guard let ballPosition = ballPosition else {
            self.ballNode.removeFromParentNode()
            return
        }
        self.ballNode.position.x = 0.0
        self.ballNode.position.y = 0.0
        self.ballNode.position.z = 0.0
        self.ballNode.eulerAngles.z = CGFloat(ballPosition.orientation.pitch.radians_d)
        self.ballNode.eulerAngles.y = CGFloat(ballPosition.orientation.yaw.radians_d)
        self.ballNode.eulerAngles.x = CGFloat(ballPosition.orientation.roll.radians_d)
        self.ballNode.position.x = CGFloat(Metres_d(ballPosition.position.y))
        self.ballNode.position.z = CGFloat(Metres_d(ballPosition.position.x))
        self.ballNode.position.y = 0.144
        if self.ballNode.parent == nil {
            self.scene.rootNode.addChildNode(self.ballNode)
        }
    }
    
    private func syncRobotNodes<Robot: FieldRobot>(to field: Field<Robot>) {
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
    
    private func createRobotNode<Robot: FieldRobot>(for robot: Robot) -> SCNNode {
        let node = self.robotNode.flattenedClone()
        self.updateRobotNode(node, for: robot)
        return node
    }
    
    private func updateRobotNode<Robot: FieldRobot>(_ node: SCNNode, for robot: Robot) {
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
