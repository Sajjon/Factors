//
//  SignaturesBuilderForSecurifiedEntity.swift
//  
//
//  Created by Alexander Cyon on 2024-06-15.
//
import OrderedCollections

public class SignaturesBuilderForSecurifiedEntity: SigningProcess, Identifiable {
	private let address: Entity.Address
	public let securifiedEntityControl: SecurifiedEntityControl

	private var skippedFactorSourceIDs: Set<FactorSourceID>
	public var signatures: OrderedSet<SignatureByFactorOfEntity>
	
	public init(
		address: Entity.Address,
		securifiedEntityControl: SecurifiedEntityControl
	) {
		self.address = address
		self.securifiedEntityControl = securifiedEntityControl
		self.skippedFactorSourceIDs = []
		self.signatures = []
	}
}

// MARK: Identfiable
extension SignaturesBuilderForSecurifiedEntity {
	public typealias ID = Entity.Address
	public var id: ID { address }
}

// MARK: Computed Private
extension SignaturesBuilderForSecurifiedEntity {
	
	private var signedOverrideFactors: OrderedSet<SignatureByFactorOfEntity> {
		signatures.filter {
			allOverrideFactorSourceIDs.contains($0.factorSourceID)
		}
	}
	
	private var signedThresholdFactors: OrderedSet<SignatureByFactorOfEntity> {
		signatures.filter {
			allThresholdFactorSourceIDs.contains($0.factorSourceID)
		}
	}
	
	private var isFinishedSigningThanksToOverrideFactors: Bool {
		!signedOverrideFactors.isEmpty
	}
	
	private var isFinishedSigningThanksToThresholdFactors: Bool {
		signedThresholdFactors.count >= securifiedEntityControl.threshold
	}

	private var allThresholdFactorSourceIDs: Set<FactorSourceID> {
		Set(securifiedEntityControl.thresholdFactors.map(\.factorSourceID))
	}
	
	private var allOverrideFactorSourceIDs: Set<FactorSourceID> {
		Set(securifiedEntityControl.overrideFactors.map(\.factorSourceID))
	}
	

}

// MARK: Private Methods
extension SignaturesBuilderForSecurifiedEntity {
	
	private func isOverrideFactor(id: FactorSourceID) -> Bool {
		allOverrideFactorSourceIDs.contains(id)
	}
	
	private func isThresholdFactor(id: FactorSourceID) -> Bool {
		allThresholdFactorSourceIDs.contains(id)
	}
}

// MARK: Protocol
extension SignaturesBuilderForSecurifiedEntity {
	public var isFinishedSigning: Bool {
		isFinishedSigningThanksToOverrideFactors || isFinishedSigningThanksToThresholdFactors
	}
	
	public func ownedFactorInstanceOfFactorSource(id: FactorSourceID) -> OwnedFactorInstance {
		if let instance = securifiedEntityControl.overrideFactors.first(where: { $0.factorSourceID == id }) {
			return OwnedFactorInstance(factorInstance: instance, owner: address)
		} else if let instance = securifiedEntityControl.thresholdFactors.first(where: { $0.factorSourceID == id }) {
			return OwnedFactorInstance(factorInstance: instance, owner: address)
		} else {
			preconditionFailure("failed to find instance created by factor source with id: \(id), but we beleived it to be present. The map `ownersOfFactor` in `SigningContext` is incorrectly setup.")
		}
	}

	public func skipFactorSource(id: FactorSourceID) {
		precondition(canSkipFactorSource(id: id))
		self.skippedFactorSourceIDs.insert(id)
		
	}
	
	public func addSignature(_ signature: SignatureByFactorOfEntity) {
		signatures.append(signature)
	}
	
	public func canSkipFactorSource(id: FactorSourceID) -> Bool {
		guard !self.skippedFactorSourceIDs.contains(id) else {
			return false // already skipped
		}
		if isFinishedSigning {
			return true
		}
		
		if isOverrideFactor(id: id) {
			let remaningOverrideFactorSourceIDs = allOverrideFactorSourceIDs.subtracting(self.skippedFactorSourceIDs)
			/// If the remaining override factors is NOT empty, it means that we can sign with any subsequent
			/// override factor, thus we can skip this one.
			let canSkipFactorSource = !remaningOverrideFactorSourceIDs.isEmpty
			return canSkipFactorSource
		} else if isThresholdFactor(id: id) {
			
			let nonSkippedThresholdFactorSourceIDs = allThresholdFactorSourceIDs.subtracting(skippedFactorSourceIDs)
			
			/// We have not skipped this (`id`) yet, if we would skip it we would at least have
			/// `nonSkippedThresholdFactorSourceIDs == securifiedEntityControl.threshold`,
			/// since we use `>` below.
			let canSkipFactorSource = nonSkippedThresholdFactorSourceIDs.count > securifiedEntityControl.threshold
			return canSkipFactorSource
		} else {
			preconditionFailure("MUST be in either overrideFactors OR in thresholdFactors (and was not in overrideFactors...)")
		}
	}

}
