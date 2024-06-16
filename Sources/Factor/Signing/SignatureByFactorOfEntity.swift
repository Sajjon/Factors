//
//  SignatureByFactorOfEntity.swift
//  
//
//  Created by Alexander Cyon on 2024-06-15.
//

public struct SignatureByFactorOfEntity: Hashable, CustomStringConvertible {
	public let entityAddress: Entity.Address
	public let signature: Signature
	public let factorInstance: FactorInstance
	public var factorSourceID: FactorSourceID {
		factorInstance.factorSourceID
	}
	public var kind: FactorSourceKind {
		factorSourceID.factorSourceKind
	}
	public var description: String {
		"SIG-\(entityAddress)-\(factorInstance.index)-\(factorSourceID)"
	}
}
