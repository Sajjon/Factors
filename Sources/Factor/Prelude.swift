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
		self.init(elements: .init(uniqueElements: elements))
	}
	let elements: IdentifiedArrayOf<FactorSource>
	public init(elements: IdentifiedArrayOf<FactorSource>) {
		self.elements = elements
	}
}

public enum FactorSourceKind: Int, Comparable, CaseIterable, CustomStringConvertible {
	case ledger = 0
	case arculus = 1
	case yubikey
	case offDevice
	case questions
	case device
	
	public var description: String {
		switch self {
		case .ledger: "ledger"
		case .arculus: "arculus"
		case .yubikey: "yubikey"
		case .offDevice: "offDevice"
		case .questions: "questions"
		case .device: "device"
		}
	}
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
		
		let idBytes = withUnsafeBytes(of: factorSourceID.id.uuid) { Data($0) }
		let indexBytes = withUnsafeBytes(of: index) {
			let d = Data($0)
			assert(d.count == 4)
			return Data([d, d, d, d].flatMap({ $0 }))
		}
		let keyBytes = idBytes + indexBytes
		self.privateKey = try! Curve25519.Signing.PrivateKey(rawRepresentation: keyBytes)
	}
}

public struct FactorSource: Hashable, Identifiable, Comparable, CustomStringConvertible {
	public typealias ID = FactorSourceID
	public var kind: FactorSourceKind {
		id.factorSourceKind
	}
	public let id: FactorSourceID
	public let lastUsed: Date
	
	public static func <(lhs: Self, rhs: Self) -> Bool {
		guard lhs.kind == rhs.kind else {
			return lhs.kind < rhs.kind
		}
		return lhs.lastUsed < rhs.lastUsed
	}
	
	public init(kind: FactorSourceKind, lastUsed: Date = .now) {
		self.id = .init(kind: kind)
		self.lastUsed = lastUsed
	}
	
	public var description: String {
		".\(kind)-\(id.id.short)"
	}
}

extension UUID {
	public var short: String {
		String(uuidString.lowercased().suffix(6))
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

public struct FactorSourceID: Hashable {
	public let factorSourceKind: FactorSourceKind
	public let id: UUID
	public init(kind: FactorSourceKind, id: UUID = .init()) {
		self.factorSourceKind = kind
		self.id = id
	}
}

public struct UnsecurifiedEntityControl: Hashable {
	public let factor: FactorInstance
	public init(factor: FactorInstance) {
		self.factor = factor
	}
	public init(index: UInt32, factorSourceID: FactorSourceID) {
		self.init(factor: .init(index: index, factorSourceID: factorSourceID))
	}
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
		precondition(Set(thresholdFactors).intersection(Set(overrideFactors)).isEmpty)
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
	
	/// We define `1` as threshold for unsecurified entities.
	public var threshold: Int {
		switch securityState {
		case .unsecurified: 1
		case .securified(let securifiedEntityControl):
			securifiedEntityControl.threshold
		}
	}
	
	public var factorCount: Int {
		switch securityState {
		case .unsecurified: 1
		case .securified(let securifiedEntityControl):
			securifiedEntityControl.thresholdFactors.count + securifiedEntityControl.overrideFactors.count
		}
	}
	
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
