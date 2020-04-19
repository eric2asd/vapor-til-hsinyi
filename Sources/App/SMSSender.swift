//
//  SMSSender.swift
//  App
//
//  Created by 陳信毅 on 2020/4/18.
//

import Vapor

protocol SMSSender: Service {
  func sendSMS(to phoneNumber: String, message: String) throws -> Future<Bool>
}
