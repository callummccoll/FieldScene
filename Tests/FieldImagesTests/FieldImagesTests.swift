import XCTest
@testable import FieldImages
import GUCoordinates
import Nao

final class FieldImagesTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        Field(player: ManageableNaoV5(fieldPosition: FieldCoordinate(position: CartesianCoordinate(x: 0, y: 0), heading: .degrees(90)))).image
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
