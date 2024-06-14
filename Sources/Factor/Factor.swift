import Foundation
import Collections

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

public enum Logic {
	public static func sortFactorSources(
		_ factorSources: some Collection<FactorSource>
	) -> OrderedSet<FactorSource> {
		OrderedSet(factorSources.sorted(by: { lhs, rhs in
			lhs.kind < rhs.kind && lhs.lastUsed < rhs.lastUsed
		}))
		
	}
	public static func calculateSigners(
		entities: [Entity],
		allFactorSourcesInProfile: AllFactorSourceInProfile
	) -> SigningContext.GroupedFactorSourcesOfKinds {
		let allFactorSourcesInProfile = Dictionary<FactorSourceID, FactorSource>(
			uniqueKeysWithValues: allFactorSourcesInProfile.elements.map { ($0.id, $0) }
		)
		func lookupFactorSourceBy(id: FactorSourceID) -> FactorSource {
			allFactorSourcesInProfile[id]!
		}
		
		// ===========================
		// Identify all Factor Sources
		// ===========================
		var unsortedFactorSources = Set<FactorSource>()
		for entity in entities {
			switch entity.securityState {
			case .unsecurified(let unsecurifiedEntityControl):
				unsortedFactorSources.insert(
					lookupFactorSourceBy(id: unsecurifiedEntityControl.factor.factorSourceID)
				)
			case .securified(let securifiedEntityControl):
				for thresholdFactor in securifiedEntityControl.thresholdFactors {
					unsortedFactorSources.insert(
						lookupFactorSourceBy(id: thresholdFactor.factorSourceID)
					)
				}
			
				for overrideFactor in securifiedEntityControl.overrideFactors {
					unsortedFactorSources.insert(
						lookupFactorSourceBy(id: overrideFactor.factorSourceID)
					)
				}
			}
		}
		
		// =======================
		// Sort all Factor Sources
		// =======================
		let ungroupedSortedFactorSources = Logic.sortFactorSources(unsortedFactorSources)
		
		// ========================
		// Group all Factor Sources
		// ========================
		let map = OrderedDictionary(grouping: ungroupedSortedFactorSources, by: \.kind)
		
		return SigningContext.GroupedFactorSourcesOfKinds(
			map: OrderedDictionary(
				uniqueKeysWithValues: map.map { (kind, factorSources) in
					(
						kind,
						SigningContext.GroupedFactorSourcesOfKind(
							kind: kind,
							factorSources: Logic.sortFactorSources(factorSources)
						)
					)
			}
		))
	}
}

public enum FactorSourceKind: Int, Comparable {
	case device
	case ledger
}

public struct FactorInstance: Hashable {
	let factorSourceID: FactorSourceID
}
public struct FactorSource: Hashable {
	let id: FactorSourceID
	let kind: FactorSourceKind
	let lastUsed: Date
}
public struct FactorSourceID: Hashable {}
public struct Signatures: Hashable {}

public struct UnsecurifiedEntityControl {
	public let factor: FactorInstance
}
public struct SecurifiedEntityControl {
	public let thresholdFactors: [FactorInstance]
	public let threshold: Int
	public let overrideFactors: [FactorInstance]
}
public enum SecurityState {
	case unsecurified(UnsecurifiedEntityControl)
	case securified(SecurifiedEntityControl)
}


public struct Entity {
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


public final class SigningContext {

	public final class GroupedFactorSourcesOfKind {
		let kind: FactorSourceKind
		let factorSources: OrderedSet<FactorSource>
		public init(
			kind: FactorSourceKind,
			factorSources: OrderedSet<FactorSource>
		) {
			self.kind = kind
			self.factorSources = factorSources
		}
	}
	
	public final class GroupedFactorSourcesOfKinds {
		let map: OrderedDictionary<FactorSourceKind, GroupedFactorSourcesOfKind>
		init(
			map: OrderedDictionary<FactorSourceKind, GroupedFactorSourcesOfKind>
		) {
			self.map = map
		}
	}
	
	public final class SigningEntity {
		let address: Entity.Address
		let securityState: SecurityState
		init(entity: Entity) {
			self.address = entity.address
			self.securityState = entity.securityState
		}
	}
	
	private let entities: [SigningEntity]
	private let ofKinds: GroupedFactorSourcesOfKinds
	
	public init(
		entities: [Entity],
		allFactorSourcesInProfile: AllFactorSourceInProfile
	) {
		self.entities = entities.map(SigningEntity.init)
		self.ofKinds = Logic.calculateSigners(
			entities: entities,
			allFactorSourcesInProfile: allFactorSourcesInProfile
		)
	}
}


extension SigningContext {

	/// If context uses threshold signatures with a lower threshold amount than
	/// number of threshold factors, then user can skip one or more factor sources.
	///
	/// Will always return `false` for non-securified accounts.
	func canSkipFactorSource(_ factorSource: FactorSource) -> Bool {
		fatalError()
	}
	
	func skipFactorSource(_ factorSource: FactorSource) {
		precondition(canSkipFactorSource(factorSource))
		fatalError()
	}
	
	func signTransaction() -> Signatures {
		for (kind, ofKind) in self.ofKinds.map {
			precondition(kind == ofKind.kind)
			for factorSource in ofKind.factorSources {
				precondition(ofKind.kind == factorSource.kind)
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


