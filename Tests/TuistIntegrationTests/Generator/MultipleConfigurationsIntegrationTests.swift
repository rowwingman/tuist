import Basic
import XcodeProj
import XCTest
@testable import TuistCore
@testable import TuistCoreTesting
@testable import TuistGenerator

final class MultipleConfigurationsIntegrationTests: XCTestCase {
    private var fileHandler: MockFileHandler!
    private var path: AbsolutePath {
        return fileHandler.currentPath
    }

    override func setUp() {
        do {
            fileHandler = try MockFileHandler()
            try setupTestProject()
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    override func tearDown() {
        fileHandler = nil
    }

    func testGenerateThrowsLintingErrorWhenConfigurationsAreEmpty() throws {
        // Given
        let modelLoader = createModelLoader(projectSettings: Settings(configurations: [:]),
                                            targetSettings: nil)
        let subject = Generator(modelLoader: modelLoader)

        // When / Then
        XCTAssertThrowsError(try subject.generateWorkspace(at: path, config: .default, workspaceFiles: []))
    }

    func testGenerateWhenSingleDebugConfigurationInProject() throws {
        // Given
        let projectSettings = Settings(base: ["A": "A"],
                                       configurations: [.debug: nil])

        // When
        try generateWorkspace(projectSettings: projectSettings, targetSettings: nil)

        // Then
        assertProject(expectedConfigurations: ["Debug"])
        assertTarget(expectedConfigurations: ["Debug"])

        let debug = try extractWorkspaceSettings(configuration: "Debug")
        XCTAssertTrue(debug.contains("A", "A")) // from base
    }

    func testGenerateWhenConfigurationSettingsOverrideXCConfig() throws {
        // Given
        let debugFilePath = try createFile(path: "Configs/debug.xcconfig", content: """
        A=A_XCCONFIG
        B=B_XCCONFIG
        """)
        let debugConfiguration = Configuration(settings: ["A": "A", "C": "C"],
                                               xcconfig: debugFilePath)
        let projectSettings = Settings(configurations: [.debug: debugConfiguration])

        // When
        try generateWorkspace(projectSettings: projectSettings, targetSettings: nil)

        // Then
        assertProject(expectedConfigurations: ["Debug"])
        assertTarget(expectedConfigurations: ["Debug"])

        let debug = try extractWorkspaceSettings(configuration: "Debug")
        XCTAssertTrue(debug.contains("A", "A")) // from settings overriding .xcconfig
        XCTAssertTrue(debug.contains("B", "B_XCCONFIG")) // from .xcconfig
        XCTAssertTrue(debug.contains("C", "C")) // from settings
    }

    func testGenerateWhenConfigurationSettingsOverrideBase() throws {
        // Given
        let debugConfiguration = Configuration(settings: ["A": "A", "C": "C"])
        let projectSettings = Settings(base: ["A": "A_BASE", "B": "B_BASE"],
                                       configurations: [.debug: debugConfiguration])

        // When
        try generateWorkspace(projectSettings: projectSettings, targetSettings: nil)

        // Then
        assertProject(expectedConfigurations: ["Debug"])
        assertTarget(expectedConfigurations: ["Debug"])

        let debug = try extractWorkspaceSettings(configuration: "Debug")
        XCTAssertTrue(debug.contains("A", "A")) // from configuration settings overriding base
        XCTAssertTrue(debug.contains("B", "B_BASE")) // from base
        XCTAssertTrue(debug.contains("C", "C")) // from settings
    }

    func testGenerateWhenBuildConfigurationWithCustomName() throws {
        // Given
        let customConfiguration = Configuration(settings: ["A": "A", "C": "C"])
        let projectSettings = Settings(base: ["A": "A_BASE", "B": "B_BASE"],
                                       configurations: [.debug("Custom"): customConfiguration,
                                                        .release: nil])

        // When
        try generateWorkspace(projectSettings: projectSettings, targetSettings: nil)

        // Then
        assertProject(expectedConfigurations: ["Custom", "Release"])
        assertTarget(expectedConfigurations: ["Custom", "Release"])

        let custom = try extractWorkspaceSettings(configuration: "Custom")
        XCTAssertTrue(custom.contains("A", "A")) // from custom settings overriding base
        XCTAssertTrue(custom.contains("B", "B_BASE")) // from base
        XCTAssertTrue(custom.contains("C", "C")) // from custom settings

        let release = try extractWorkspaceSettings(configuration: "Release")
        XCTAssertTrue(release.contains("A", "A_BASE")) // from base
        XCTAssertTrue(release.contains("B", "B_BASE")) // from base
        XCTAssertFalse(release.contains("C", "C")) // non-existing, only defined in Custom
    }

    func testGenerateWhenTargetSettingsOverrideTargetXCConfig() throws {
        // Given
        let debugFilePath = try createFile(path: "Configs/debug.xcconfig", content: """
        A=A_XCCONFIG
        B=B_XCCONFIG
        """)
        let debugConfiguration = Configuration(settings: ["A": "A", "C": "C"],
                                               xcconfig: debugFilePath)
        let projectSettings = Settings(configurations: [.debug: nil])
        let targetSettings = Settings(configurations: [.debug: debugConfiguration])

        // When
        try generateWorkspace(projectSettings: projectSettings, targetSettings: targetSettings)

        // Then
        assertProject(expectedConfigurations: ["Debug"])
        assertTarget(expectedConfigurations: ["Debug"])

        let debug = try extractWorkspaceSettings(configuration: "Custom")
        XCTAssertTrue(debug.contains("A", "A")) // from target settings overriding target .xcconfig
        XCTAssertTrue(debug.contains("B", "B_XCCONFIG")) // from target .xcconfig
        XCTAssertTrue(debug.contains("C", "C")) // from target settings
    }

    func testGenerateWhenMultipleConfigurations() throws {
        // Given
        let projectDebugConfiguration = Configuration(settings: ["A": "A_PROJECT_DEBUG",
                                                                 "B": "B_PROJECT_DEBUG"])
        let projectReleaseConfiguration = Configuration(settings: ["A": "A_PROJECT_RELEASE",
                                                                   "C": "C_PROJECT_RELEASE"])
        let projectSettings = Settings(configurations: [.debug: projectDebugConfiguration,
                                                        .release("ProjectRelease"): projectReleaseConfiguration])

        let targetDebugConfiguration = Configuration(settings: ["B": "B_TARGET_DEBUG"])
        let targetStagingConfiguration = Configuration(settings: ["B": "B_TARGET_STAGING"])

        let targetSettings = Settings(configurations: [.debug: targetDebugConfiguration,
                                                       .release("Staging"): targetStagingConfiguration])

        // When
        try generateWorkspace(projectSettings: projectSettings, targetSettings: targetSettings)

        // Then
        assertProject(expectedConfigurations: ["Debug", "ProjectRelease"])
        assertTarget(expectedConfigurations: ["Debug", "ProjectRelease", "Staging"])

        let debug = try extractWorkspaceSettings(configuration: "Debug")
        XCTAssertTrue(debug.contains("A", "A_PROJECT_DEBUG")) // from project debug settings
        XCTAssertTrue(debug.contains("B", "B_TARGET_DEBUG")) // from target debug settings

        let release = try extractWorkspaceSettings(configuration: "ProjectRelease")
        XCTAssertTrue(release.contains("A", "A_PROJECT_RELEASE")) // from project debug settings
        XCTAssertTrue(release.contains("C", "C_PROJECT_RELEASE")) // from project debug settings
        XCTAssertFalse(release.containsKey("B")) // non-existing

        let staging = try extractWorkspaceSettings(configuration: "Staging")
        XCTAssertTrue(staging.contains("B", "B_TARGET_STAGING")) // from target staging settings
        XCTAssertFalse(staging.containsKey("A")) // non-existing
        XCTAssertFalse(staging.containsKey("C")) // non-existing
    }

    /**
     Exhaustive test to validate the priority of the particular settings:
     - project .xcconfig
     - project base
     - project configuration settings
     - target .xcconfig
     - target base
     - target configuraiton settings
     */
    func testGenerateWhenTargetSettingsOverrideProjectBaseSettingsAndXCConfig() throws {
        // Given
        let projectDebugFilePath = try createFile(path: "Configs/project_debug.xcconfig", content: """
        A=A_PROJECT_XCCONFIG
        B=B_PROJECT_XCCONFIG
        C=C_PROJECT_XCCONFIG
        D=D_PROJECT_XCCONFIG
        E=E_PROJECT_XCCONFIG
        F=F_PROJECT_XCCONFIG
        PROJECT_XCCONFIG=YES
        """)
        let projectDebugConfiguration = Configuration(settings: ["C": "C_PROJECT",
                                                                 "D": "D_PROJECT",
                                                                 "E": "E_PROJECT",
                                                                 "F": "F_PROJECT",
                                                                 "PROJECT": "YES"],
                                                      xcconfig: projectDebugFilePath)

        let projectSettings = Settings(base: ["B": "B_PROJECT_BASE",
                                              "C": "C_PROJECT_BASE",
                                              "D": "D_PROJECT_BASE",
                                              "E": "E_PROJECT_BASE",
                                              "F": "F_PROJECT_BASE",
                                              "PROJECT_BASE": "YES"],
                                       configurations: [.debug: projectDebugConfiguration])

        let targetDebugFilePath = try createFile(path: "Configs/target_debug.xcconfig", content: """
        D=D_TARGET_XCCONFIG
        E=E_TARGET_XCCONFIG
        F=F_TARGET_XCCONFIG
        TARGET_XCCONFIG=YES
        """)

        let targetDebugConfiguration = Configuration(settings: ["F": "F_TARGET",
                                                                "TARGET": "YES"],
                                                     xcconfig: targetDebugFilePath)
        let targetSettings = Settings(base: ["E": "E_TARGET_BASE",
                                             "F": "E_TARGET_BASE",
                                             "TARGET_BASE": "YES"],
                                      configurations: [.debug: targetDebugConfiguration])

        // When
        try generateWorkspace(projectSettings: projectSettings, targetSettings: targetSettings)

        // Then
        assertProject(expectedConfigurations: ["Debug"])
        assertTarget(expectedConfigurations: ["Debug"])

        let debug = try extractWorkspaceSettings(configuration: "Debug")
        XCTAssertTrue(debug.contains("A", "A_PROJECT_XCCONFIG")) // from project .xcconfig
        XCTAssertTrue(debug.contains("B", "B_PROJECT_BASE")) // from project base
        XCTAssertTrue(debug.contains("C", "C_PROJECT")) // from project settings
        XCTAssertTrue(debug.contains("D", "D_TARGET_XCCONFIG")) // from target .xcconfig
        XCTAssertTrue(debug.contains("E", "E_TARGET_BASE")) // from target base
        XCTAssertTrue(debug.contains("F", "F_TARGET")) // from target settings
        XCTAssertTrue(debug.contains("PROJECT_XCCONFIG", "YES")) // from project .xcconfig
        XCTAssertTrue(debug.contains("PROJECT_BASE", "YES")) // from project base
        XCTAssertTrue(debug.contains("PROJECT", "YES")) // from project settings
        XCTAssertTrue(debug.contains("TARGET_XCCONFIG", "YES")) // from target .xcconfig
        XCTAssertTrue(debug.contains("TARGET_BASE", "YES")) // from target base
        XCTAssertTrue(debug.contains("TARGET", "YES")) // from target settings
    }

    // MARK: - Helpers

    private func generateWorkspace(projectSettings: Settings, targetSettings: Settings?) throws {
        let modelLoader = createModelLoader(projectSettings: projectSettings, targetSettings: targetSettings)
        let subject = Generator(modelLoader: modelLoader)
        _ = try subject.generateWorkspace(at: path, config: .default, workspaceFiles: [])
    }

    private func setupTestProject() throws {
        try fileHandler.createFolders(["App/Sources"])
    }

    @discardableResult
    private func createFile(path relativePath: String, content: String) throws -> AbsolutePath {
        let absolutePath = path.appending(RelativePath(relativePath))
        try fileHandler.touch(absolutePath)
        try content.data(using: .utf8)!.write(to: URL(fileURLWithPath: absolutePath.pathString))
        return absolutePath
    }

    private func createModelLoader(projectSettings: Settings, targetSettings: Settings?) -> GeneratorModelLoading {
        let modelLoader = MockGeneratorModelLoader(basePath: path)
        let appTarget = createAppTarget(settings: targetSettings)
        let project = createProject(path: pathTo("App"), settings: projectSettings, targets: [appTarget], schemes: [])
        let workspace = createWorkspace(projects: ["App"])
        modelLoader.mockProject("App") { _ in project }
        modelLoader.mockWorkspace { _ in workspace }
        return modelLoader
    }

    private func createWorkspace(projects: [String]) -> Workspace {
        return Workspace(name: "Workspace", projects: projects.map { pathTo($0) })
    }

    private func createProject(path: AbsolutePath, settings: Settings, targets: [Target], schemes: [Scheme]) -> Project {
        return Project(path: path,
                       name: "App",
                       settings: settings,
                       filesGroup: .group(name: "Project"),
                       targets: targets,
                       schemes: schemes)
    }

    private func createAppTarget(settings: Settings?) -> Target {
        return Target(name: "AppTarget",
                      platform: .iOS,
                      product: .app,
                      bundleId: "test.bundle",
                      settings: settings,
                      sources: [pathTo("App/Sources/AppDelegate.swift")],
                      filesGroup: .group(name: "ProjectGroup"))
    }

    private func pathTo(_ relativePath: String) -> AbsolutePath {
        return path.appending(RelativePath(relativePath))
    }

    private func extractWorkspaceSettings(configuration: String) throws -> ExtractedBuildSettings {
        return try extractBuildSettings(path: .workspace(path: path.appending(component: "Workspace.xcworkspace").pathString,
                                                         scheme: "AppTarget",
                                                         configuration: configuration))
    }

    private func loadXcodeProj(_ relativePath: String) throws -> XcodeProj {
        let appProjectPath = path.appending(RelativePath(relativePath))
        return try XcodeProj(pathString: appProjectPath.pathString)
    }

    // MARK: - Assertions

    private func assertTarget(_ target: String = "AppTarget",
                              expectedConfigurations: Set<String>,
                              file: StaticString = #file,
                              line: UInt = #line) {
        let proj: XcodeProj
        do {
            proj = try loadXcodeProj("App/App.xcodeproj")
        } catch {
            XCTFail(error.localizedDescription, file: file, line: line)
            return
        }

        guard let nativeTarget = proj.pbxproj.nativeTargets.first(where: { $0.name == target }) else {
            XCTFail("Target \(target) not found", file: file, line: line)
            return
        }

        let configurationNames = Set(nativeTarget.buildConfigurationList?.buildConfigurations.map { $0.name } ?? [])
        XCTAssertEqual(configurationNames, expectedConfigurations, file: file, line: line)
    }

    private func assertProject(expectedConfigurations: Set<String>,
                               file: StaticString = #file,
                               line: UInt = #line) {
        let proj: XcodeProj
        let rootProject: PBXProject?
        do {
            proj = try loadXcodeProj("App/App.xcodeproj")
            rootProject = try proj.pbxproj.rootProject()
        } catch {
            XCTFail(error.localizedDescription, file: file, line: line)
            return
        }

        let configurationNames = Set(rootProject?.buildConfigurationList?.buildConfigurations.map { $0.name } ?? [])
        XCTAssertEqual(configurationNames, expectedConfigurations, file: file, line: line)
    }
}

private func extractBuildSettings(path: XcodePath) throws -> ExtractedBuildSettings {
    var arguments = [
        "/usr/bin/xcrun",
        "xcodebuild",
        path.argument,
        path.path,
        "-showBuildSettings",
        "-configuration",
        path.configuration,
    ]

    if let scheme = path.scheme {
        arguments.append("-scheme")
        arguments.append(scheme)
    }

    let rawBuildSettings = try Basic.Process.checkNonZeroExit(arguments: arguments)
    return ExtractedBuildSettings(rawBuildSettings: rawBuildSettings)
}

private struct ExtractedBuildSettings {
    let rawBuildSettings: String

    func contains(_ key: String, _ value: String) -> Bool {
        return contains((key, value))
    }

    func containsKey(_ key: String) -> Bool {
        return rawBuildSettings.contains(" \(key)) = ")
    }

    func contains(_ pair: (key: String, value: String)) -> Bool {
        return rawBuildSettings.contains("\(pair.key) = \(pair.value)")
    }

    func contains(settings: [String: String]) -> Bool {
        return settings.allSatisfy { contains($0) }
    }
}

private enum XcodePath {
    case project(path: String, configuration: String)
    case workspace(path: String, scheme: String, configuration: String)

    var path: String {
        switch self {
        case let .project(path: path, configuration: _):
            return path
        case let .workspace(path: path, scheme: _, configuration: _):
            return path
        }
    }

    var scheme: String? {
        switch self {
        case .project(path: _, configuration: _):
            return nil
        case let .workspace(path: _, scheme: scheme, configuration: _):
            return scheme
        }
    }

    var configuration: String {
        switch self {
        case let .project(path: _, configuration: configuration):
            return configuration
        case let .workspace(path: _, scheme: _, configuration: configuration):
            return configuration
        }
    }

    var argument: String {
        switch self {
        case .project(path: _):
            return "-project"
        case .workspace(path: _, scheme: _, configuration: _):
            return "-workspace"
        }
    }
}

private class MockGeneratorModelLoader: GeneratorModelLoading {
    private var projects = [String: (AbsolutePath) throws -> Project]()
    private var workspaces = [String: (AbsolutePath) throws -> Workspace]()

    private let basePath: AbsolutePath

    init(basePath: AbsolutePath) {
        self.basePath = basePath
    }

    // MARK: - GeneratorModelLoading

    func loadProject(at path: AbsolutePath) throws -> Project {
        return try projects[path.pathString]!(path)
    }

    func loadWorkspace(at path: AbsolutePath) throws -> Workspace {
        return try workspaces[path.pathString]!(path)
    }

    // MARK: - Mock

    func mockProject(_ path: String, loadClosure: @escaping (AbsolutePath) throws -> Project) {
        projects[basePath.appending(component: path).pathString] = loadClosure
    }

    func mockWorkspace(_ path: String = "", loadClosure: @escaping (AbsolutePath) throws -> Workspace) {
        workspaces[basePath.appending(component: path).pathString] = loadClosure
    }
}