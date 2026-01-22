//
//  ServiceIdentifiers.swift
//  Runner
//
//  Created by Hawk on 2024/10/24.
//

import Foundation

class ServiceIdentifiers:NSObject{
    // G2 BLE UUIDs - Base: 00002760-08c2-11e1-9073-0e8ac72e{xxxx}
    static let uartServiceUUIDString                                = "00002760-08c2-11e1-9073-0e8ac72e0000"
    // Write characteristic (Commands: Phone -> Glasses)
    static let uartTXCharacteristicUUIDString                       = "00002760-08c2-11e1-9073-0e8ac72e5401"
    // Notify characteristic (Responses: Glasses -> Phone)
    static let uartRXCharacteristicUUIDString                       = "00002760-08c2-11e1-9073-0e8ac72e5402"
    // Display rendering characteristic
    static let displayCharacteristicUUIDString                      = "00002760-08c2-11e1-9073-0e8ac72e6402"
}
