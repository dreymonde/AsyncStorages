//
//  File.swift
//  
//
//  Created by Oleg on 7/11/24.
//

import Foundation

final actor ActorSafe<Wrapped> {
    
    private var value: Wrapped
    
    init(_ value: Wrapped) {
        self.value = value
    }
    
    func get() -> Wrapped {
        value
    }
    
    func set(_ newValue: Wrapped) {
        value = newValue
    }
    
    func write<T>(with block: (inout Wrapped) -> T) -> T {
        return block(&value)
    }
    
    func write<T>(with block: (inout Wrapped) throws -> T) throws -> T {
        return try block(&value)
    }
}
