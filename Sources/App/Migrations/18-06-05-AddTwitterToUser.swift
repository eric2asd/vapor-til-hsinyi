//
//  18-06-05-AddTwitterToUser.swift
//  App
//
//  Created by 陳信毅 on 2020/4/18.
//

import FluentPostgreSQL
import Vapor

struct AddTwitterURLToUser: Migration {
  typealias Database = PostgreSQLDatabase
  
  static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
    return Database.update(User.self, on: conn) { builder in
      builder.field(for: \.twitterURL)
    }
  }
  
  static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
    return Database.update(User.self, on: conn) { builder in
      builder.deleteField(for: \.twitterURL)
    }
  }
}
