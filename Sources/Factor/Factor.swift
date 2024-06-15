import Foundation
import Collections
import IdentifiedCollections

extension Comparable where Self: RawRepresentable, Self.RawValue: Comparable {
	public static func < (lhs: Self, rhs: Self) -> Bool {
		lhs.rawValue < rhs.rawValue
	}
}

public struct AllFactorSourceInProfile {
	let elements: [FactorSource]
	public init(elements: [FactorSource]) {
		self.elements = elements
	}
}

//public enum Logic {
//
//	public static func calculateSigners(
//		entities: [Entity],
//		allFactorSourcesInProfile: AllFactorSourceInProfile
//	) -> SigningContext.GroupedFactorSourcesOfKinds {
//		let signingEntities = entities.map(SigningContext.SigningEntity.init)
//		let allFactorSourcesInProfile = Dictionary<FactorSourceID, FactorSource>(
//			uniqueKeysWithValues: allFactorSourcesInProfile.elements.map { ($0.id, $0) }
//		)
//		func lookupFactorSourceBy(id: FactorSourceID) -> FactorSource {
//			allFactorSourcesInProfile[id]!
//		}
//
//		// ===========================
//		// Identify all Factor Sources
//		// ===========================
//		var unsortedFactorSources = Set<SigningContext.ControllingFactorSource>()
//		for signingEntity in signingEntities {
//			switch signingEntity.securityState {
//			case .unsecurified(let unsecurifiedEntityControl):
//				unsortedFactorSources.insert(
//					SigningContext.ControllingFactorSource(
//						factorSource: lookupFactorSourceBy(id: unsecurifiedEntityControl.factor.factorSourceID),
//						signingEntity: signingEntity
//					)
//				)
//			case .securified(let securifiedEntityControl):
//				for thresholdFactor in securifiedEntityControl.thresholdFactors {
//					let factorSource = lookupFactorSourceBy(id: thresholdFactor.factorSourceID)
//					unsortedFactorSources.insert(
//						SigningContext.ControllingFactorSource(
//							factorSource: factorSource,
//							signingEntity: signingEntity
//						)
//					)
//				}
//
//				for overrideFactor in securifiedEntityControl.overrideFactors {
//					let factorSource = lookupFactorSourceBy(id: overrideFactor.factorSourceID)
//					unsortedFactorSources.insert(
//						SigningContext.ControllingFactorSource(
//							factorSource: factorSource,
//							signingEntity: signingEntity
//						)
//					)
//				}
//			}
//		}
//
//		// =======================
//		// Sort all Factor Sources
//		// =======================
//		let ungroupedSortedFactorSources = unsortedFactorSources.sorted()
//
//		// ========================
//		// Group all Factor Sources
//		// ========================
//		let map = OrderedDictionary(grouping: ungroupedSortedFactorSources, by: \.factorSource.kind)
//
//		return SigningContext.GroupedFactorSourcesOfKinds(
//			map: OrderedDictionary(
//				uniqueKeysWithValues: map.map { (kind, factorSources) in
//					(
//						kind,
//						SigningContext.GroupedFactorSourcesOfKind(
//							kind: kind,
//							factorSources: Logic.sortFactorSources(factorSources)
//						)
//					)
//			}
//		))
//	}
//}

public enum FactorSourceKind: Int, Comparable {
	case device
	case ledger
}

public struct FactorInstance: Hashable {
	let factorSourceID: FactorSourceID
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
public struct Signatures: Hashable {}

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

public struct SignatureOfFactor: Hashable {
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
	mutating func addSignature(_ signature: SignatureOfFactor)
}
protocol SigningProcess: BaseSigningProcess {
	func factorInstanceOfFactorSource(id: FactorSourceID) -> FactorInstance
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
		
		func factorInstanceOfFactorSource(id: FactorSourceID) -> FactorInstance {
			if let instance = securifiedEntityControl.overrideFactors.first(where: { $0.factorSourceID == id }) {
				return instance
			} else if let instance = securifiedEntityControl.thresholdFactors.first(where: { $0.factorSourceID == id }) {
				return instance
			} else {
				fatalError("failed to find instance created by factor source with id: \(id), but we beleived it to be present. The map `ownersOfFactor` in `Context` is incorrectly setup.")
			}
		}
		
		var signatures: Set<SignatureOfFactor> = []
		
		var signedOverrideFactors: Set<SignatureOfFactor> {
			signatures.filter {
				allOverrideFactorSourceIDs.contains($0.factorSourceID)
			}
		}
		
		var signedThresholdFactors: Set<SignatureOfFactor> {
			signatures.filter {
				allThresholdFactorSourceIDs.contains($0.factorSourceID)
			}
		}
		
		var skippedFactorInstances: Set<FactorInstance> = []
		var skippedFactorSourceIDs: Set<FactorSourceID> {
			Set(skippedFactorInstances.map(\.factorSourceID))
		}
		
		func skipFactorSource(id: FactorSourceID) {
			precondition(canSkipFactorSource(id: id))
			fatalError("TODO")
			
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
		
		func addSignature(_ signature: SignatureOfFactor) {
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
				fatalError("MUST be in either overrideFactors OR in thresholdFactors (and was not in overrideFactors...)")
			}
			
		}
		
		init() {
			fatalError()
		}
	}
	
	enum SignaturesOfEntity: SigningProcess, Identifiable {
		func canSkipFactorSource(id: FactorSourceID) -> Bool {
			switch self {
			case let .securified(s): s.canSkipFactorSource(id: id)
			case let .unsecurified(u): u.canSkipFactorSource(id: id)
			}
		}
		func factorInstanceOfFactorSource(id: FactorSourceID) -> FactorInstance {
			switch self {
			case let .securified(s): s.factorInstanceOfFactorSource(id: id)
			case let .unsecurified(u): u.factorInstanceOfFactorSource(id: id)
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
		
		mutating func addSignature(_ signature: SignatureOfFactor) {
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
			func canSkipFactorSource(id: FactorSourceID) -> Bool {
				false
			}
			
			func skipFactorSource(id: FactorSourceID) {
				fatalError("not supported")
			}
			
			var isFinishedSigning: Bool {
				signatureOfFactor != nil
			}
			
			func addSignature(_ signature: SignatureOfFactor) {
				self.signatureOfFactor = signature
			}
			
			typealias ID = Entity.Address
			let address: Entity.Address
			var id: ID { address }
			let unsecuredControl: UnsecurifiedEntityControl
			
			func factorInstanceOfFactorSource(id: FactorSourceID) -> FactorInstance {
				guard unsecuredControl.factor.factorSourceID == id else {
					fatalError("expected unsecuredControl.factor.factorSourceID == id but it was not. The map `ownersOfFactor` in `Context` is incorrectly setup.")
				}
				return unsecuredControl.factor
			}
			
			var signatureOfFactor: SignatureOfFactor?
			init() { fatalError() }
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
	
	var signaturesOfEntities: IdentifiedArrayOf<SignaturesOfEntity>
	
	/// Can be plural, e.g. I'm a own account `A` and `B` and I'm signing a transaction where I spend
	/// funds from accounts `A` **and** `B` where both `A` and `B` is controlled by factor source `X`,
	/// then this dictionary will have the entry `[X: [A, B]]`.
	let ownersOfFactor: Dictionary<FactorSourceID, Set<SignaturesOfEntity.ID>>
	
	let factorsOfKind: OrderedDictionary<FactorSourceKind, IdentifiedArrayOf<FactorSource>>
	
	init(
		allFactorSourcesInProfile: AllFactorSourceInProfile,
		entities: [EntityInProfile]
	) {
		fatalError()
	}
	func signWithFactorSource(_ factorSource: FactorSource) {
		let owners = self.ownersOfFactor[factorSource.id]!
		let factorInstances = owners.flatMap { owner in
			let signaturesOfEntity = self.signaturesOfEntities[id: owner]
			return signaturesOfEntity?.factorInstanceOfFactorSource(id: factorSource.id)
		}
		let signatures = factorSource.bulkSign(factorInstances: factorInstances)
		for signature in signatures {
			signaturesOfEntities[id: signature.entityAddress]?.addSignature(signature)
		}
	}
}

extension FactorSource {
	func bulkSign(factorInstances: some Collection<FactorInstance>) -> OrderedSet<SignatureOfFactor> {
		[]
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
	
	
	
	func addSignature(_ signature: SignatureOfFactor) {
		fatalError()
	}
	
	func skipFactorSource(id: FactorSourceID) {
		ownersOfFactor[id]!.forEach { owner in
			signaturesOfEntities[id: owner]!.skipFactorSource(id: id)
		}
	}
	
	func signTransaction() -> Signatures {
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
		fatalError()
	}
}


