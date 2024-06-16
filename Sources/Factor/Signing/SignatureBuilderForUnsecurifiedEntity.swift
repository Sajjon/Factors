//
//  Untitled.swift
//  
//
//  Created by Alexander Cyon on 2024-06-15.
//
import OrderedCollections

public final class SignatureBuilderForUnsecurifiedEntity: SigningProcess, Identifiable {
	public let address: Entity.Address
	public let unsecuredControl: UnsecurifiedEntityControl
	public var signatureOfFactor: SignatureByFactorOfEntity?
	
	public init(
		address: Entity.Address,
		unsecuredControl: UnsecurifiedEntityControl
	) {
		self.address = address
		self.unsecuredControl = unsecuredControl
	}
}

// MARK: Identifiable
extension SignatureBuilderForUnsecurifiedEntity {
	public typealias ID = Entity.Address
	public var id: ID { address }
}

// MARK: Protocol
extension SignatureBuilderForUnsecurifiedEntity {
	public var isFinishedSigning: Bool {
		signatureOfFactor != nil
	}
	
	public var signatures: OrderedSet<SignatureByFactorOfEntity> {
		guard let signatureOfFactor else { return [] }
		return [signatureOfFactor]
	}

	public func canSkipFactorSource(id: FactorSourceID) -> Bool {
		false
	}
	
	public func skipFactorSource(id: FactorSourceID) {
		preconditionFailure("not supported")
	}

	public func addSignature(_ signature: SignatureByFactorOfEntity) {
		self.signatureOfFactor = signature
	}
	
	public func ownedFactorInstanceOfFactorSource(
		id: FactorSourceID
	) -> OwnedFactorInstance {
		
		guard unsecuredControl.factor.factorSourceID == id else {
			preconditionFailure("expected unsecuredControl.factor.factorSourceID == id but it was not. The map `ownersOfFactor` in `SigningContext` is incorrectly setup.")
		}
		
		return OwnedFactorInstance(factorInstance: unsecuredControl.factor, owner: address)
	}
}
