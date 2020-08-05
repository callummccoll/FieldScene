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

import GUCoordinates
import Nao
import Foundation
import SceneKit
import AppKit

public struct Field {
    
    public var player: ManageableNaoV5
    
    public var teamMates: [FieldCoordinate]
    
    public var opponents: [FieldCoordinate]
    
    public init(player: ManageableNaoV5, teamMates: [FieldCoordinate] = [], opponents: [FieldCoordinate] = []) {
        self.player = player
        self.teamMates = teamMates
        self.opponents = opponents
    }
    
    var image: NSImage {
        let bundle = "FieldImages_FieldImages.bundle"
        // create a new scene
        let field = SCNScene(named: bundle + "/field.scnassets/field.scn")!.rootNode.childNode(withName: "field", recursively: true)!
        let homeGoal = SCNScene(named: bundle + "/field.scnassets/goal.scn")!.rootNode.childNode(withName: "goal", recursively: true)!
        homeGoal.position.x = -4.55
        homeGoal.position.y = 0.001
        homeGoal.rotation.y = 1.0
        homeGoal.rotation.w = CGFloat(Double.pi)
        let awayGoal = SCNScene(named: bundle + "/field.scnassets/goal.scn")!.rootNode.childNode(withName: "goal", recursively: true)!
        awayGoal.position.x = 4.55
        awayGoal.position.y = 0.001
        let scene = SCNScene()
        scene.rootNode.addChildNode(field)
        scene.rootNode.addChildNode(homeGoal)
        scene.rootNode.addChildNode(awayGoal)
        
        // create and add a camera to the scene
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        
        cameraNode.position = SCNVector3(x: 0, y: 8, z: 0)
        cameraNode.eulerAngles.x = CGFloat.pi / -2.0
        
        // retrieve the SCNView
        let scnView = SCNView(frame: NSRect(x: 0, y: 0, width: 640, height: 480))
        
        scnView.backgroundColor = .black
        
        // set the scene to the view
        scnView.scene = scene
        
        // allows the user to manipulate the camera
        scnView.allowsCameraControl = true
        
        // show statistics such as fps and timing information
        scnView.showsStatistics = true
        
        // configure the view
        scnView.backgroundColor = NSColor.black
        return scnView.snapshot()
    }
    
}
