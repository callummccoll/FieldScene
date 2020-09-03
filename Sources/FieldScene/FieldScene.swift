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
    
    private var homeRobotPositions: [Int: FieldCoordinate?] = [:]
    private var awayRobotPositions: [Int: FieldCoordinate?] = [:]
    
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
    
    public func update<Robot: FieldRobot>(from field: Field<Robot>, duration: TimeInterval = 0) {
        self.syncRobotNodes(to: field, duration: duration)
        self.updateBall(from: field.ball, duration: duration)
    }
    
    private func updateBall(from ballPosition: BallPosition?, duration: TimeInterval = 0) {
        guard let ballPosition = ballPosition else {
            self.ballNode.removeFromParentNode()
            return
        }
        if self.ballNode.parent == nil {
            self.scene.rootNode.addChildNode(self.ballNode)
        }
        let translateAction = SCNAction.move(
            to: SCNVector3(
                CGFloat(Metres_d(ballPosition.position.y)),
                0.144,
                CGFloat(Metres_d(ballPosition.position.x))
            ),
            duration: duration
        )
        let rotateAction = SCNAction.rotateTo(
            x: CGFloat(ballPosition.orientation.roll.radians_d),
            y: CGFloat(ballPosition.orientation.yaw.radians_d),
            z: CGFloat(ballPosition.orientation.pitch.radians_d),
            duration: duration
        )
        self.ballNode.runAction(translateAction)
        self.ballNode.runAction(rotateAction)
    }
    
    private func syncRobotNodes<Robot: FieldRobot>(to field: Field<Robot>, duration: TimeInterval = 0) {
        func sync(robots: [Robot], nodeCount: Int, get: (Int) -> SCNNode?, assign: (Int, SCNNode) -> Void, remove: (Int) -> Void, lastFieldPosition: (Int) -> FieldCoordinate?, assignFieldPosition: (Int, FieldCoordinate?) -> Void) {
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
                self.updateRobotNode(get(index)!, for: robot, lastFieldPosition: lastFieldPosition(index), duration: duration)
                assignFieldPosition(index, robot.fieldPosition)
            }
        }
        sync(
            robots: field.homeRobots,
            nodeCount: homeRobotNodes.count,
            get: { homeRobotNodes[$0] },
            assign: { homeRobotNodes[$0] = $1 },
            remove: { homeRobotNodes[$0]?.removeFromParentNode() },
            lastFieldPosition: { homeRobotPositions[$0] ?? nil },
            assignFieldPosition: { homeRobotPositions[$0] = $1 }
        )
        sync(
            robots: field.awayRobots,
            nodeCount: awayRobotNodes.count,
            get: { awayRobotNodes[$0] },
            assign: { awayRobotNodes[$0] = $1 },
            remove: {awayRobotNodes[$0]?.removeFromParentNode() },
            lastFieldPosition: { awayRobotPositions[$0] ?? nil },
            assignFieldPosition: { awayRobotPositions[$0] = $1 }
        )
    }
    
    private func createRobotNode<Robot: FieldRobot>(for robot: Robot) -> SCNNode {
        let node = self.robotNode.flattenedClone()
        self.updateRobotNode(node, for: robot)
        return node
    }
    
    private func updateRobotNode<Robot: FieldRobot>(_ node: SCNNode, for robot: Robot, lastFieldPosition: FieldCoordinate? = nil, duration: TimeInterval = 0) {
        guard let fieldPosition = robot.fieldPosition else {
            node.removeFromParentNode()
            return
        }
        if lastFieldPosition == nil {
            self.scene.rootNode.addChildNode(node)
        }
        if let lastFieldPosition = lastFieldPosition, lastFieldPosition == robot.fieldPosition {
            return
        }
        let translateVector = SCNVector3(
            CGFloat(Metres_d(fieldPosition.position.y)),
            0.101,
            CGFloat(Metres_d(fieldPosition.position.x))
        )
        
        let yaw = fieldPosition.heading.radians_d
        let translateAction = SCNAction.move(to: translateVector, duration: duration)
        let rotateVector = SCNVector3(
            x: node.eulerAngles.x,
            y: CGFloat(yaw) - CGFloat.pi / 2.0,
            z: node.eulerAngles.z
        )
        let rotateAction = SCNAction.rotateTo(
            x: rotateVector.x,
            y: rotateVector.y,
            z: rotateVector.z,
            duration: duration
        )
        if node.position.x != translateVector.x || node.position.y != translateVector.y || node.position.z != translateVector.z {
            node.runAction(translateAction)
        }
        if node.eulerAngles.x != rotateVector.x || node.eulerAngles.y != rotateVector.y || node.eulerAngles.z != rotateVector.z {
            node.runAction(rotateAction)
        }
        return
    }
    
}
