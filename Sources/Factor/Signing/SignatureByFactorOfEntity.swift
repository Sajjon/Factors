//
//  SignatureByFactorOfEntity.swift
//  
//
//  Created by Alexander Cyon on 2024-06-15.
//

public struct SignatureByFactorOfEntity: Hashable, CustomStringConvertible {
	let entityAddress: Entity.Address
	let signature: Signature
	let factorInstance: FactorInstance
	var factorSourceID: FactorSourceID {
		factorInstance.factorSourceID
	}
	public var description: String {
		"SIG-\(entityAddress)-\(factorInstance.index)-\(factorSourceID)"
	}
}
