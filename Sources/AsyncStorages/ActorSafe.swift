//
//  File.swift
//  
//
//  Created by Oleg on 7/11/24.
//

import Foundation

public final actor ActorSafe<Wrapped> {
    
    private var value: Wrapped
    
    public init(_ value: Wrapped) {
        self.value = value
    }
    
    public func get() -> Wrapped {
        value
    }
    
    public func set(_ newValue: Wrapped) {
        value = newValue
    }
    
    public func write<T>(with block: (inout Wrapped) -> T) -> T {
        return block(&value)
    }
    
    public func write<T>(with block: (inout Wrapped) throws -> T) throws -> T {
        return try block(&value)
    }
}
