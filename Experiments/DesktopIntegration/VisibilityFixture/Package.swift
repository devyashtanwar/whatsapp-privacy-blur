// swift-tools-version:5.9
import PackageDescription
let package = Package(name:"VisibilityFixture",platforms:[.macOS("15.2")],targets:[
    .target(name:"IntegrationCore"),
    .target(name:"NativeRendering",dependencies:["IntegrationCore"]),
    .target(name:"FixtureCommon",dependencies:["IntegrationCore","NativeRendering"]),
    .executableTarget(name:"FixtureOwner",dependencies:["FixtureCommon"]),
    .executableTarget(name:"FixtureObserver",dependencies:["FixtureCommon","IntegrationCore"])
])
