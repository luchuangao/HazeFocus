import XCTest
import CoreGraphics
@testable import FocusCore

final class FocusGeometryTests: XCTestCase {
    let main = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let right = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
    let a = FocusWindow(id: 1, pid: 10, frame: CGRect(x: 100, y: 100, width: 800, height: 600))
    let b = FocusWindow(id: 2, pid: 20, frame: CGRect(x: 1600, y: 100, width: 900, height: 700))
    let c = FocusWindow(id: 3, pid: 10, frame: CGRect(x: 1700, y: 200, width: 700, height: 500))

    func testPrimaryAndNegativeCoordinateConversion() {
        XCTAssertEqual(FocusGeometry.appKitRect(CGRect(x: 30, y: 60, width: 800, height: 600), primaryHeight: 900), CGRect(x: 30, y: 240, width: 800, height: 600))
        // A display physically above the primary has negative CG Y.
        XCTAssertEqual(FocusGeometry.appKitRect(CGRect(x: -100, y: -700, width: 800, height: 600), primaryHeight: 900), CGRect(x: -100, y: 1000, width: 800, height: 600))
        XCTAssertEqual(FocusGeometry.localRect(CGRect(x: -1000, y: 1000, width: 800, height: 600), screen: CGRect(x: -1440, y: 900, width: 1440, height: 900)), CGRect(x: 440, y: 100, width: 800, height: 600))
    }
    func testActiveDisplayDoesNotExposeBackgroundApp() {
        XCTAssertEqual(FocusGeometry.holes(windows: [a,b,c], focused: a, pid: 10, screen: right, mode: .activeDisplay, allAppWindows: false), [])
    }
    func testEachDisplayUsesFrontmostVisibleWindow() {
        XCTAssertEqual(FocusGeometry.holes(windows: [a,b,c], focused: a, pid: 10, screen: right, mode: .eachDisplay, allAppWindows: false), [b.frame])
    }
    func testAllApplicationWindowsAndNoForeignWindows() {
        XCTAssertEqual(FocusGeometry.holes(windows: [a,b,c], focused: a, pid: 10, screen: right, mode: .activeDisplay, allAppWindows: true), [c.frame])
    }
    func testWindowSpanningDisplaysKeepsBothPartsClear() {
        let spanning = FocusWindow(id: 4, pid: 10, frame: CGRect(x: 1300, y: 100, width: 800, height: 600))
        for screen in [main, right] {
            XCTAssertEqual(FocusGeometry.holes(windows: [spanning,b], focused: spanning, pid: 10, screen: screen, mode: .eachDisplay, allAppWindows: false), [spanning.frame])
        }
    }
    func testAXSelectsExactWindowInsteadOfAppFrontmostFallback() {
        XCTAssertEqual(FocusGeometry.focused(windows: [c,b,a], pid: 10, axFrame: a.frame)?.id, a.id)
        XCTAssertNil(FocusGeometry.focused(windows: [b], pid: 10, axFrame: a.frame))
        XCTAssertNil(FocusGeometry.focused(windows: [a,b,c], pid: 10, axFrame: CGRect(x: 0, y: 0, width: 10, height: 10)))
    }
    func testAppWithoutWindowsDoesNotHighlightAnotherApp() {
        XCTAssertNil(FocusGeometry.focused(windows: [b], pid: 10, axFrame: nil))
        XCTAssertEqual(FocusGeometry.holes(windows: [b], focused: nil, pid: 10, screen: main, mode: .activeDisplay, allAppWindows: false), [])
    }
    func testAutomationInputValidation() {
        XCTAssertEqual(ControlCommand.parse(URL(string: "hazefocus://intensity?value=70")!), .intensity(0.7))
        XCTAssertEqual(ControlCommand.parse(URL(string: "hazefocus://toggle")!), .toggle)
        for url in ["hazefocus://intensity?value=nan", "hazefocus://intensity?value=101", "hazefocus://intensity?value=-1", "https://toggle", "hazefocus://unknown"] {
            XCTAssertNil(ControlCommand.parse(URL(string: url)!))
        }
    }
    func testProfileClampsInvalidIntensity() {
        XCTAssertEqual(AppearanceProfile(intensity: .nan).intensity, 0.65)
        XCTAssertEqual(AppearanceProfile(intensity: -1).intensity, 0)
        XCTAssertEqual(AppearanceProfile(intensity: 2).intensity, 1)
    }
}
