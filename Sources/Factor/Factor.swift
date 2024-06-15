import Foundation
import Collections
import IdentifiedCollections

extension Comparable where Self: RawRepresentable, Self.RawValue: Comparable {
	public static func < (lhs: Self, rhs: Self) -> Bool {
		lhs.rawValue < rhs.rawValue
	}
}

public struct AllFactorSourceInProfile {
	let elements: IdentifiedArrayOf<FactorSource>
	public init(elements: IdentifiedArrayOf<FactorSource>) {
		self.elements = elements
	}
}

public enum FactorSourceKind: Int, Comparable {
	case device
	case ledger
}

public struct FactorInstance: Hashable {
	let factorSourceID: FactorSourceID
}
public struct OwnedFactorInstance: Hashable {
	let factorInstance: FactorInstance
	let owner: Entity.Address
}
public struct FactorSource: Hashable, Identifiable, Comparable {
	public typealias ID = FactorSourceID
	public let id: FactorSourceID
	public let kind: FactorSourceKind
	public let lastUsed: Date
	
	public static func <(lhs: Self, rhs: Self) -> Bool {
		lhs.kind < rhs.kind && lhs.lastUsed < rhs.lastUsed
	}
}
public struct FactorSourceID: Hashable {}

public struct UnsecurifiedEntityControl: Hashable {
	public let factor: FactorInstance
}

public struct AbstractSecurifiedEntityControl<Factor: Hashable>: Hashable {
	public let thresholdFactors: [Factor]
	public let threshold: Int
	public let overrideFactors: [Factor]
}

public typealias SecurifiedEntityControl = AbstractSecurifiedEntityControl<FactorInstance>

public enum SecurityState: Hashable {
	case unsecurified(UnsecurifiedEntityControl)
	case securified(SecurifiedEntityControl)
}

public typealias Entity = EntityInProfile
public struct EntityInProfile: Hashable {
	public typealias Address = String
	public let address: Address
	public let securityState: SecurityState
	public init(
		securityState: SecurityState,
		address: Address
	) {
		self.securityState = securityState
		self.address = address
	}
}

public struct Signature: Hashable {}

public struct SignatureByFactorOfEntity: Hashable {
	let entityAddress: Entity.Address
	let signature: Signature
	let factorInstance: FactorInstance
	var factorSourceID: FactorSourceID {
		factorInstance.factorSourceID
	}
}

protocol BaseSigningProcess {
	func canSkipFactorSource(id: FactorSourceID) -> Bool
	mutating func skipFactorSource(id: FactorSourceID)
	var isFinishedSigning: Bool { get }
	var signatures: Set<SignatureByFactorOfEntity> { get }
	mutating func addSignature(_ signature: SignatureByFactorOfEntity)
}
protocol SigningProcess: BaseSigningProcess {
	func ownedFactorInstanceOfFactorSource(id: FactorSourceID) -> OwnedFactorInstance
}


// MARK: -
// MARK: CONTEXT
// MARK: -
class Context: BaseSigningProcess {
	
	class SignaturesOfSecurifiedEntity: SigningProcess, Identifiable {
		typealias ID = Entity.Address
		var id: ID { address }
		public let address: Entity.Address
		public let securifiedEntityControl: SecurifiedEntityControl
		
		func ownedFactorInstanceOfFactorSource(id: FactorSourceID) -> OwnedFactorInstance {
			if let instance = securifiedEntityControl.overrideFactors.first(where: { $0.factorSourceID == id }) {
				return OwnedFactorInstance(factorInstance: instance, owner: address)
			} else if let instance = securifiedEntityControl.thresholdFactors.first(where: { $0.factorSourceID == id }) {
				return OwnedFactorInstance(factorInstance: instance, owner: address)
			} else {
				preconditionFailure("failed to find instance created by factor source with id: \(id), but we beleived it to be present. The map `ownersOfFactor` in `Context` is incorrectly setup.")
			}
		}
		
		var signatures: Set<SignatureByFactorOfEntity> = []
		
		var signedOverrideFactors: Set<SignatureByFactorOfEntity> {
			signatures.filter {
				allOverrideFactorSourceIDs.contains($0.factorSourceID)
			}
		}
		
		var signedThresholdFactors: Set<SignatureByFactorOfEntity> {
			signatures.filter {
				allThresholdFactorSourceIDs.contains($0.factorSourceID)
			}
		}
		
		var skippedFactorSourceIDs: Set<FactorSourceID> = []
		
		func skipFactorSource(id: FactorSourceID) {
			precondition(canSkipFactorSource(id: id))
			self.skippedFactorSourceIDs.insert(id)
			
		}
		
		private var allThresholdFactorSourceIDs: Set<FactorSourceID> {
			Set(securifiedEntityControl.thresholdFactors.map(\.factorSourceID))
		}
		
		private var allOverrideFactorSourceIDs: Set<FactorSourceID> {
			Set(securifiedEntityControl.overrideFactors.map(\.factorSourceID))
		}
		
		private var maxSkippableThresholdFactorSourceCount: Int {
			let maxSkippableThresholdFactorSourceCount = securifiedEntityControl.threshold - securifiedEntityControl.thresholdFactors.count
			
			assert(maxSkippableThresholdFactorSourceCount >= 0)
			return maxSkippableThresholdFactorSourceCount
		}
		
		private func isOverrideFactor(id: FactorSourceID) -> Bool {
			allOverrideFactorSourceIDs.contains(id)
		}
		private func isThresholdFactor(id: FactorSourceID) -> Bool {
			allThresholdFactorSourceIDs.contains(id)
		}
		
		private var isFinishedSigningThanksToOverrideFactors: Bool {
			!signedOverrideFactors.isEmpty
		}
		
		private var isFinishedSigningThanksToThresholdFactors: Bool {
			signedThresholdFactors.count >= securifiedEntityControl.threshold
		}
		
		var isFinishedSigning: Bool {
			isFinishedSigningThanksToOverrideFactors || isFinishedSigningThanksToThresholdFactors
		}
		
		func addSignature(_ signature: SignatureByFactorOfEntity) {
			signatures.insert(signature)
		}
		
		func canSkipFactorSource(id: FactorSourceID) -> Bool {
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
				
				let skippedThresholdFactors = self.skippedFactorSourceIDs.subtracting(allThresholdFactorSourceIDs)
				
				/// If we have not skipped more than max skippable threshold count yet, we can skip
				/// this factors
				let canSkipFactorSource = skippedThresholdFactors.count < maxSkippableThresholdFactorSourceCount
				return canSkipFactorSource
			} else {
				preconditionFailure("MUST be in either overrideFactors OR in thresholdFactors (and was not in overrideFactors...)")
			}
			
		}
		
		init(
			address: Entity.Address,
			securifiedEntityControl: SecurifiedEntityControl
		) {
			self.address = address
			self.securifiedEntityControl = securifiedEntityControl
		}
	}
	
	enum SignaturesOfEntity: SigningProcess, Identifiable {
		
		func canSkipFactorSource(id: FactorSourceID) -> Bool {
			switch self {
			case let .securified(s): s.canSkipFactorSource(id: id)
			case let .unsecurified(u): u.canSkipFactorSource(id: id)
			}
		}
		func ownedFactorInstanceOfFactorSource(id: FactorSourceID) -> OwnedFactorInstance {
			switch self {
			case let .securified(s): s.ownedFactorInstanceOfFactorSource(id: id)
			case let .unsecurified(u): u.ownedFactorInstanceOfFactorSource(id: id)
			}
		}
		
		mutating func skipFactorSource(id: FactorSourceID) {
			switch self {
			case let .securified(s):
				s.skipFactorSource(id: id)
				self = .securified(s)
			case let .unsecurified(u):
				u.skipFactorSource(id: id)
				self = .unsecurified(u)
			}
		}
		
		var isFinishedSigning: Bool {
			switch self {
			case let .securified(s): s.isFinishedSigning
			case let .unsecurified(u): u.isFinishedSigning
			}
		}
		
		var signatures: Set<SignatureByFactorOfEntity> {
			switch self {
			case let .securified(s): s.signatures
			case let .unsecurified(u): u.signatures
			}
		}
		
		
		mutating func addSignature(_ signature: SignatureByFactorOfEntity) {
			switch self {
			case let .securified(s):
				s.addSignature(signature)
				self = .securified(s)
			case let .unsecurified(u):
				u.addSignature(signature)
				self = .unsecurified(u)
			}
		}
		
		class Unsecurified: SigningProcess, Identifiable {
			let address: Entity.Address
			var signatures: Set<SignatureByFactorOfEntity> {
				guard let signatureOfFactor else { return [] }
				return [signatureOfFactor]
			}
			let unsecuredControl: UnsecurifiedEntityControl
			init(address: Entity.Address, unsecuredControl: UnsecurifiedEntityControl) {
				self.address = address
				self.unsecuredControl = unsecuredControl
			}
			func canSkipFactorSource(id: FactorSourceID) -> Bool {
				false
			}
			
			func skipFactorSource(id: FactorSourceID) {
				preconditionFailure("not supported")
			}
			
			var isFinishedSigning: Bool {
				signatureOfFactor != nil
			}
			
			func addSignature(_ signature: SignatureByFactorOfEntity) {
				self.signatureOfFactor = signature
			}
			
			typealias ID = Entity.Address
		
			var id: ID { address }
			
			func ownedFactorInstanceOfFactorSource(id: FactorSourceID) -> OwnedFactorInstance {
				guard unsecuredControl.factor.factorSourceID == id else {
					preconditionFailure("expected unsecuredControl.factor.factorSourceID == id but it was not. The map `ownersOfFactor` in `Context` is incorrectly setup.")
				}
				return OwnedFactorInstance(factorInstance: unsecuredControl.factor, owner: address)
			}
			
			var signatureOfFactor: SignatureByFactorOfEntity?
		
		}
		typealias ID = Entity.Address
		case unsecurified(Unsecurified)
		case securified(SignaturesOfSecurifiedEntity)
		
		var id: ID {
			switch self {
			case let .securified(sec): sec.id
			case let .unsecurified(unsec): unsec.id
			}
		}
	}
	
	var signatures: Set<SignatureByFactorOfEntity> {
		Set(signaturesOfEntities.flatMap {
			$0.signatures
		})
	}
	
	private var signaturesOfEntities: IdentifiedArrayOf<SignaturesOfEntity>
	
	
	/// Can be plural, e.g. I'm a own account `A` and `B` and I'm signing a transaction where I spend
	/// funds from accounts `A` **and** `B` where both `A` and `B` is controlled by factor source `X`,
	/// then this dictionary will have the entry `[X: [A, B]]`.
	let ownersOfFactor: Dictionary<FactorSourceID, Set<SignaturesOfEntity.ID>>
	
	let factorsOfKind: OrderedDictionary<FactorSourceKind, IdentifiedArrayOf<FactorSource>>
	
	init(
		allFactorSourcesInProfile: AllFactorSourceInProfile,
		entities: [EntityInProfile]
	) {
		var signaturesOfEntities = IdentifiedArrayOf<SignaturesOfEntity>()
		var ownersOfFactor: Dictionary<FactorSourceID, Set<SignaturesOfEntity.ID>> = [:]
		var usedFactorSources: IdentifiedArrayOf<FactorSource> = []
		
		for entity in entities {
			let address = entity.address
			switch entity.securityState {
			case let .securified(sec):
				let signaturesBuildingContext = SignaturesOfEntity.securified(
					SignaturesOfSecurifiedEntity(
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
				let signatureBuildingContext = SignaturesOfEntity.unsecurified(
					SignaturesOfEntity.Unsecurified(
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
		self.factorsOfKind = OrderedDictionary(grouping: usedFactorSources.sorted(), by: \.kind)
	}
	
	func addSignature(_ signature: SignatureByFactorOfEntity) {
		signaturesOfEntities[id: signature.entityAddress]?.addSignature(signature)
	}
	
	func signWithFactorSource(_ factorSource: FactorSource) {
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

extension FactorSource {
	func bulkSign(
		ownedFactorInstances: some Collection<OwnedFactorInstance>
	) -> OrderedSet<SignatureByFactorOfEntity> {
		OrderedSet(
			ownedFactorInstances.map {
				SignatureByFactorOfEntity(
					entityAddress: $0.owner,
					signature: .init(),
					factorInstance: $0.factorInstance
				)
			}
		)
	}
}
extension Context {
	var isFinishedSigning: Bool {
		signaturesOfEntities.allSatisfy(\.isFinishedSigning)
	}
	
	
	func canSkipFactorSource(id: FactorSourceID) -> Bool {
		ownersOfFactor[id]!.allSatisfy({
			signaturesOfEntities[id: $0]!.canSkipFactorSource(id: id)
		})
	}
	
	func skipFactorSource(id: FactorSourceID) {
		ownersOfFactor[id]!.forEach { owner in
			signaturesOfEntities[id: owner]!.skipFactorSource(id: id)
		}
	}
	
	func signTransaction() -> Set<SignatureByFactorOfEntity> {
		for (kind, factorSourcesOfKind) in self.factorsOfKind {
			
			for factorSource in factorSourcesOfKind {
				precondition(factorSource.kind == kind)
				
				/// emulate lazy, unafraid user
				while canSkipFactorSource(id: factorSource.id) {
					skipFactorSource(id: factorSource.id)
					continue
				}
				
				signWithFactorSource(factorSource)
			}
		}
		
		return self.signatures
	}
}


