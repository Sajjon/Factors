import Foundation
import Collections
import IdentifiedCollections

public enum SimUser {
	/// Skipping as many as possible
	case lazy
	
	/// Never skips, signing as much as possible
	case prudent
	
	case random
}

public class SigningContext: BaseSigningProcess {
	
	/// Builders of signatures
	public private(set) var signaturesOfEntities: IdentifiedArrayOf<SignaturesBuilderOfEntity>
	
	/// Can be plural, e.g. if Alice owns account `A` and `B` and Alice signs a transaction where she spend
	/// funds from accounts `A` **and** `B` where both `A` and `B` is controlled by factor source `X`,
	/// then this dictionary will have the entry `[X: [A, B]]`.
	private let ownersOfFactor: Dictionary<FactorSourceID, Set<SignaturesBuilderOfEntity.ID>>
	
	/// Ordered and sorted list of needed factor sources.
	private let factorsOfKind: OrderedDictionary<FactorSourceKind, IdentifiedArrayOf<FactorSource>>
	
	/// Only relevant for tests
	public let user: SimUser
	
	public init(
		user: SimUser,
		allFactorSourcesInProfile: AllFactorSourceInProfile,
		entities: [Entity]
	) {
		self.user = user
		var signaturesOfEntities = IdentifiedArrayOf<SignaturesBuilderOfEntity>()
		var ownersOfFactor: Dictionary<FactorSourceID, Set<SignaturesBuilderOfEntity.ID>> = [:]
		var usedFactorSources: IdentifiedArrayOf<FactorSource> = []
		
		for entity in entities {
			let address = entity.address
			switch entity.securityState {
			case let .securified(sec):
				let signaturesBuildingContext = SignaturesBuilderOfEntity.securified(
					SignaturesBuilderForSecurifiedEntity(
						address: address,
						securifiedEntityControl: sec
					)
				)
				// SEC 1/3: Update `signaturesOfEntities`
				signaturesOfEntities.append(signaturesBuildingContext)
				
				func add(factors keyPath: KeyPath<SecurifiedEntityControl, [FactorInstance]>) {
					let factors = sec[keyPath: keyPath]
					for factor in factors {
						let id = factor.factorSourceID
						// SEC 2/3: Update `ownersOfFactor`
						do { var s = ownersOfFactor[id, default: []]; s.insert(address); ownersOfFactor[id] = s; }
						
						// SEC 3/3: Update `usedFactorSources`
						do {
							let factorSource = allFactorSourcesInProfile.elements[id: id]!
							usedFactorSources.append(factorSource)
						}
					}
					
				}
				
				add(factors: \.thresholdFactors)
				add(factors: \.overrideFactors)
				
			case let .unsecurified(uec):
				let id = uec.factor.factorSourceID
				let signatureBuildingContext = SignaturesBuilderOfEntity.unsecurified(
					SignatureBuilderForUnsecurifiedEntity(
						address: address,
						unsecuredControl: uec
					)
				)
				
				// UEC 1/3: Update `signaturesOfEntities`
				signaturesOfEntities.append(signatureBuildingContext)
				
				// UEC 2/3: Update `ownersOfFactor`
				do { var s = ownersOfFactor[id, default: []]; s.insert(address); ownersOfFactor[id] = s; }
				
				// UEC 3/3: Update `usedFactorSources`
				let factorSource = allFactorSourcesInProfile.elements[id: id]!
				usedFactorSources.append(factorSource)
				
			}
		}
		self.signaturesOfEntities = signaturesOfEntities
		self.ownersOfFactor = ownersOfFactor
		
		self.factorsOfKind = OrderedDictionary(grouping: usedFactorSources.sorted(by: <), by: \.kind)
		
	}
}

// MARK: Public
extension SigningContext {
	public func signTransaction() -> OrderedSet<SignatureByFactorOfEntity> {
		for (kind, factorSourcesOfKind) in self.factorsOfKind {
			
			for factorSource in factorSourcesOfKind {
				precondition(factorSource.kind == kind)
				
				let trySkip = switch user {
				case .lazy: true
				case .prudent: false
				case .random: Bool.random()
				}
				if trySkip && canSkipFactorSource(id: factorSource.id) {
					skipFactorSource(id: factorSource.id)
				} else {
					signWithFactorSource(factorSource)
				}
				
			}
		}
		
		return self.signatures
	}
}

// MARK: Protocol
extension SigningContext {
	
	public var signatures: OrderedSet<SignatureByFactorOfEntity> {
		OrderedSet(signaturesOfEntities.flatMap {
			$0.signatures
		})
	}
	
	public func addSignature(_ signature: SignatureByFactorOfEntity) {
		signaturesOfEntities[id: signature.entityAddress]?.addSignature(signature)
	}

	public var isFinishedSigning: Bool {
		signaturesOfEntities.allSatisfy(\.isFinishedSigning)
	}
	
	
	public func canSkipFactorSource(id: FactorSourceID) -> Bool {
		ownersOfFactor[id]!.allSatisfy({
			signaturesOfEntities[id: $0]!.canSkipFactorSource(id: id)
		})
	}
	
	public func skipFactorSource(id: FactorSourceID) {
		ownersOfFactor[id]!.forEach { owner in
			signaturesOfEntities[id: owner]!.skipFactorSource(id: id)
		}
	}
	
}

// MARK: Private
extension SigningContext {

	private func signWithFactorSource(_ factorSource: FactorSource) {
		let owners = self.ownersOfFactor[factorSource.id]!
		let ownedFactorInstances = owners.map { owner in
			let signaturesOfEntity = self.signaturesOfEntities[id: owner]!
			return signaturesOfEntity.ownedFactorInstanceOfFactorSource(id: factorSource.id)
		}
		let signatures = factorSource.bulkSign(ownedFactorInstances: ownedFactorInstances)
		for signature in signatures {
			addSignature(signature)
		}
	}
	
	
}


