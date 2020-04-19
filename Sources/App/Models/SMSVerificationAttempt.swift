//
//  SMSVerificationAttempt.swift
//  AWSSDKSwiftCore
//
//  Created by 陳信毅 on 2020/4/18.
//

import Vapor
import FluentPostgreSQL

final class SMSVerificationAttempt: Codable {
  var code: String
  var expiresAt: Date?
  var id: UUID?
  var phoneNumber: String
  
  init(code: String, expiresAt: Date?, phoneNumber: String) {
    self.id = nil
    self.code = code
    self.expiresAt = expiresAt
    self.phoneNumber = phoneNumber
  }
}

extension SMSVerificationAttempt: PostgreSQLUUIDModel {
  typealias Database = PostgreSQLDatabase
}
extension SMSVerificationAttempt: Migration {}
