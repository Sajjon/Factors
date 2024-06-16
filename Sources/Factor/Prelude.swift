import Foundation
import Collections
import IdentifiedCollections
import CryptoKit

extension Comparable where Self: RawRepresentable, Self.RawValue: Comparable {
	public static func < (lhs: Self, rhs: Self) -> Bool {
		lhs.rawValue < rhs.rawValue
	}
}

public struct AllFactorSourceInProfile: ExpressibleByArrayLiteral {
	public init(arrayLiteral elements: FactorSource...) {
		self.init(elements: .init(elements))
	}
	let elements: IdentifiedArrayOf<FactorSource>
	public init(elements: IdentifiedArrayOf<FactorSource>) {
		self.elements = elements
	}
}

public enum FactorSourceKind: Int, Comparable {
	case device
	case offDevice
	case ledger
	case arculus
	case yubikey
	case questions
}

public struct FactorInstance: Hashable {
	public static func == (lhs: Self, rhs: Self) -> Bool {
		lhs.privateKey.publicKey.rawRepresentation ==
		rhs.privateKey.publicKey.rawRepresentation
	}
	public func hash(into hasher: inout Hasher) {
		hasher.combine(privateKey.publicKey.rawRepresentation)
	}
	public let index: UInt32
	public let factorSourceID: FactorSourceID
	let privateKey: Curve25519.Signing.PrivateKey

	public init(index: UInt32, factorSourceID: FactorSourceID) {
		self.index = index
		self.factorSourceID = factorSourceID
		self.privateKey = try! Curve25519.Signing.PrivateKey.init(rawRepresentation: withUnsafeBytes(of: index) { let d = Data($0); assert(d.count == 4); return Data([d, d, d, d].flatMap({ $0 })) } + withUnsafeBytes(of: factorSourceID.uuid) { Data($0) })
	}
}

public struct FactorSource: Hashable, Identifiable, Comparable {
	public typealias ID = FactorSourceID
	public let kind: FactorSourceKind
	public let id: FactorSourceID
	public let lastUsed: Date
	
	public static func <(lhs: Self, rhs: Self) -> Bool {
		lhs.kind < rhs.kind && lhs.lastUsed < rhs.lastUsed
	}
	
	public init(kind: FactorSourceKind, id: FactorSourceID = .init(), lastUsed: Date = .now) {
		self.id = id
		self.kind = kind
		self.lastUsed = lastUsed
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

public typealias FactorSourceID = UUID

public struct UnsecurifiedEntityControl: Hashable {
	public let factor: FactorInstance
}

public struct SecurifiedEntityControl: Hashable {
	public let thresholdFactors: [FactorInstance]
	public let threshold: Int
	public let overrideFactors: [FactorInstance]
	
	public init(
		thresholdFactors: [FactorInstance],
		threshold: Int,
		overrideFactors: [FactorInstance]
	) {
		precondition(thresholdFactors.count >= threshold)
		self.thresholdFactors = thresholdFactors
		self.threshold = threshold
		self.overrideFactors = overrideFactors
	}
}


public enum SecurityState: Hashable {
	case unsecurified(UnsecurifiedEntityControl)
	case securified(SecurifiedEntityControl)
}

public struct Entity: Hashable {
	public typealias Address = String
	public let address: Address
	public let securityState: SecurityState
	public init(
		address: Address,
		securityState: SecurityState
	) {
		self.securityState = securityState
		self.address = address
	}
	
	public static func unsecure(
		index: UInt32,
		address: Address,
		makeControl: (UInt32) -> UnsecurifiedEntityControl
	) -> Self {
		.init(address: "\(address) (\(index))", securityState: .unsecurified(makeControl(index)))
	}
	
	public static func securified(
		index: UInt32,
		address: Address,
		makeControl: (UInt32) -> SecurifiedEntityControl
	) -> Self {
		.init(address: "\(address) (\(index))", securityState: .securified(makeControl(index)))
	}
}

public struct Signature: Hashable {}
