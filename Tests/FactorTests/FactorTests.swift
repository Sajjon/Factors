import Testing
import Factor

extension FactorSource {
	/// Device
	static let fs0 = FactorSource(kind: .device)

	/// Ledger
	static let fs1 = FactorSource(kind: .ledger)

	/// Arculus
	static let fs2 = FactorSource(kind: .arculus)
	
	/// Yubikey
	static let fs3 = FactorSource(kind: .yubikey)
	
	/// Question
	static let fs4 = FactorSource(kind: .questions)
	
}
extension AllFactorSourceInProfile {
	static let all = Self.init(elements: [
		.fs0,
		.fs1,
		.fs2,
		.fs3,
		.fs4,
	])
}



extension FactorSourceID {
	static var fs0: Self { FactorSource.fs0.id }
	static var fs1: Self { FactorSource.fs1.id }
	static var fs2: Self { FactorSource.fs2.id }
	static var fs3: Self { FactorSource.fs3.id }
	static var fs4: Self { FactorSource.fs4.id }
}

extension Entity {
	static let a0 = Self.securified(index: 0, address: "Alice") { index in
		SecurifiedEntityControl(
			thresholdFactors: [
				.init(index: index, factorSourceID: .fs0),
				.init(index: index, factorSourceID: .fs1),
				.init(index: index, factorSourceID: .fs2),
			],
			threshold: 2,
			overrideFactors: [
				.init(index: index, factorSourceID: .fs3)
			]
		)
	}
	
	static let a1 = Self.unsecure(index: 0, address: "Alice") { index in
		UnsecurifiedEntityControl.init(index: index, factorSourceID: .fs4)
	}
}

@Test
func lazy_user() throws {
	let entities = [Entity.a0]
	let context = Context(
		user: .lazy,
		allFactorSourcesInProfile: .all,
		entities: entities
	)
	let signatures = context.signTransaction()
	print(signatures)
	#expect(signatures.count == entities.map(\.threshold).reduce(0, +))
}
