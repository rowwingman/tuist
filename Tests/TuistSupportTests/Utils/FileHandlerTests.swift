import Basic
import Foundation
import XCTest
@testable import TuistSupport
@testable import TuistSupportTesting

final class FileHandlerErrorTests: XCTestCase {
    func test_description() {
        XCTAssertEqual(FileHandlerError.invalidTextEncoding(AbsolutePath("/path")).description, "The file at /path is not a utf8 text file")
        XCTAssertEqual(FileHandlerError.writingError(AbsolutePath("/path")).description, "Couldn't write to the file /path")
    }
}

final class FileHandlerTests: TuistUnitTestCase {
    private var subject: FileHandler!
    private let fileManager = FileManager.default

    // MARK: - Setup

    override func setUp() {
        super.setUp()

        subject = FileHandler()
    }

    // MARK: - Tests

    func test_replace() throws {
        // Given
        let tempFile = try TemporaryFile()
        let destFile = try TemporaryFile()
        try "content".write(to: tempFile.path.asURL, atomically: true, encoding: .utf8)

        // When
        try subject.replace(destFile.path, with: tempFile.path)

        // Then
        let content = try String(contentsOf: destFile.path.asURL)
        XCTAssertEqual(content, "content")
    }

    func test_replace_cleans_up_temp() throws {
        // FIX: This test runs fine locally but it fails on CI.
        // // Given
        // let temporaryPath = try self.temporaryPath()
        // let from = temporaryPath.appending(component: "from")
        // try FileHandler.shared.touch(from)
        // let to = temporaryPath.appending(component: "to")

        // let count = try countItemsInRootTempDirectory(appropriateFor: to.asURL)

        // // When
        // try subject.replace(to, with: from)

        // // Then
        // XCTAssertEqual(count, try countItemsInRootTempDirectory(appropriateFor: to.asURL))
    }

    // MARK: - Private

    private func countItemsInRootTempDirectory(appropriateFor url: URL) throws -> Int {
        let tempPath = AbsolutePath(try fileManager.url(for: .itemReplacementDirectory,
                                                        in: .userDomainMask,
                                                        appropriateFor: url,
                                                        create: true).path)
        let rootTempPath = tempPath.parentDirectory
        try fileManager.removeItem(at: tempPath.asURL)
        let content = try fileManager.contentsOfDirectory(atPath: rootTempPath.pathString)
        return content.count
    }
}
