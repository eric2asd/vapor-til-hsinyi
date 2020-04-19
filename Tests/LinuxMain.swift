import XCTest

@testable import AppTests

XCTMain([
  testCase(AcronymsTests.allTests),
  testCase(CategoryTests.allTests),
  testCase(UserTests.allTests)
])
