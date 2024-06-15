//
//  OwnedFactorInstance.swift
//  
//
//  Created by Alexander Cyon on 2024-06-15.
//

public struct OwnedFactorInstance: Hashable {
	let factorInstance: FactorInstance
	let owner: Entity.Address
}
