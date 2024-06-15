//
//  Protocols.swift
//  
//
//  Created by Alexander Cyon on 2024-06-15.
//

public protocol BaseSigningProcess {
	func canSkipFactorSource(id: FactorSourceID) -> Bool
	mutating func skipFactorSource(id: FactorSourceID)
	var isFinishedSigning: Bool { get }
	var signatures: Set<SignatureByFactorOfEntity> { get }
	mutating func addSignature(_ signature: SignatureByFactorOfEntity)
}

public protocol SigningProcess: BaseSigningProcess {
	func ownedFactorInstanceOfFactorSource(id: FactorSourceID) -> OwnedFactorInstance
}
