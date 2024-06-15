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
	let signature: Signature
	let factorInstance: FactorInstance
	var factorSourceID: FactorSourceID {
		factorInstance.factorSourceID
	}
}

protocol SigningProcess {
	func canSkipFactorSource(id: FactorSourceID) -> Bool
	func skipFactorSource(id: FactorSourceID)
	var isFinishedSigning: Bool { get }
	func addSignature(_ signature: SignatureOfFactor)
}

// MARK: -
// MARK: CONTEXT
// MARK: -
class Context {
	
	class SignaturesOfSecurifiedEntity: Identifiable {
		typealias ID = Entity.Address
		var id: ID { address }
		public let address: Entity.Address
		public let securifiedEntityControl: SecurifiedEntityControl
		
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
		
		private var isFinishedSigning: Bool {
			isFinishedSigningThanksToOverrideFactors || isFinishedSigningThanksToThresholdFactors
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
	
	enum SignaturesOfEntity: Identifiable {
		class Unsecurified: Identifiable {
			typealias ID = Entity.Address
			let entity: Entity
			var id: ID { entity.address }
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
	let ownerOfFactor: Dictionary<FactorSourceID, SignaturesOfEntity.ID>
	let factorsOfKind: OrderedDictionary<FactorSourceKind, IdentifiedArrayOf<FactorSource>>
	
	init(
		allFactorSourcesInProfile: AllFactorSourceInProfile,
		entities: [EntityInProfile]
	) {
		fatalError()
	}
	
	func canSkipFactorSource(_ factorSource: FactorSource) -> Bool {
		let owner = self.ownerOfFactor[factorSource.id]!
		let signaturesOfEntity = self.signaturesOfEntities[id: owner]!
		fatalError()
	}
	func skipFactorSource(_ factorSource: FactorSource) {
		fatalError()
	}
	func signTransaction() -> Signatures {
		for (kind, factorSourcesOfKind) in self.factorsOfKind {
			
			for factorSource in factorSourcesOfKind {
				precondition(factorSource.kind == kind)
				
				/// emulate lazy, unafraid user
				while canSkipFactorSource(factorSource) {
					skipFactorSource(factorSource)
					continue
				}
				
				
			}
		}
		fatalError()
	}
}
