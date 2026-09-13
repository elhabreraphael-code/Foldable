// swift-tools-version: 5.9
// Copyright (c) 2026 Jhey
// SPDX-License-Identifier: GPL-3.0-or-later

import PackageDescription

let package = Package(
    name: "LidPlane",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "LidPlane", targets: ["LidPlane"])],
    targets: [
        .target(name: "LidPlaneCore"),
        .executableTarget(name: "LidPlane", dependencies: ["LidPlaneCore"]),
        .executableTarget(name: "LidPlaneChecks", dependencies: ["LidPlaneCore"], path: "Tests/LidPlaneCoreTests")
    ]
)
