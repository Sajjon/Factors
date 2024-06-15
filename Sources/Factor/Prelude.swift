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

public struct FactorSource: Hashable, Identifiable, Comparable {
	public typealias ID = FactorSourceID
	public let id: FactorSourceID
	public let kind: FactorSourceKind
	public let lastUsed: Date
	
	public static func <(lhs: Self, rhs: Self) -> Bool {
		lhs.kind < rhs.kind && lhs.lastUsed < rhs.lastUsed
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

public struct FactorSourceID: Hashable {}

public struct UnsecurifiedEntityControl: Hashable {
	public let factor: FactorInstance
}

public struct SecurifiedEntityControl: Hashable {
	public let thresholdFactors: [FactorInstance]
	public let threshold: Int
	public let overrideFactors: [FactorInstance]
}


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
