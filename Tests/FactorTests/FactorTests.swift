import Testing
import Factor
import OrderedCollections

extension FactorSource {
	/// Device
	static let fs0 = FactorSource(kind: .device)

	/// Ledger
	static let fs1 = FactorSource(kind: .ledger)
	/// Ledger
	static let fs2 = FactorSource(kind: .ledger)

	/// Arculus
	static let fs3 = FactorSource(kind: .arculus)
	/// Arculus
	static let fs4 = FactorSource(kind: .arculus)
	
	/// Yubikey
	static let fs5 = FactorSource(kind: .yubikey)
	/// Yubikey
	static let fs6 = FactorSource(kind: .yubikey)
	
	/// Question
	static let fs7 = FactorSource(kind: .questions)
	
}
extension AllFactorSourceInProfile {
	static let all = Self.init(elements: [
		.fs0,
		.fs1,
		.fs2,
		.fs3,
		.fs4,
		.fs5,
		.fs6,
		.fs7,
	])
}



extension FactorSourceID {
	static var fs0: Self { FactorSource.fs0.id }
	static var fs1: Self { FactorSource.fs1.id }
	static var fs2: Self { FactorSource.fs2.id }
	static var fs3: Self { FactorSource.fs3.id }
	static var fs4: Self { FactorSource.fs4.id }
	static var fs5: Self { FactorSource.fs5.id }
	static var fs6: Self { FactorSource.fs6.id }
	static var fs7: Self { FactorSource.fs7.id }
}

extension Entity: @retroactive CaseIterable {
	public static let allCases = [Self.a0, .a1, .a2, .a3, .a4]
	static let a0 = Self.securified(index: 0, address: "Alice") { index in
		SecurifiedEntityControl(
			thresholdFactors: [
				.init(index: index, factorSourceID: .fs2),
				.init(index: index, factorSourceID: .fs0),
				.init(index: index, factorSourceID: .fs1),
			],
			threshold: 2,
			overrideFactors: [
				.init(index: index, factorSourceID: .fs7)
			]
		)
	}
	
	static let a1 = Self.unsecure(index: 1, address: "Bob") { index in
		UnsecurifiedEntityControl(index: index, factorSourceID: .fs4)
	}
	
	static let a2 = Self.securified(index: 2, address: "Carol") { index in
		SecurifiedEntityControl(
			thresholdFactors: [
				.init(index: index, factorSourceID: .fs7),
				.init(index: index, factorSourceID: .fs0),
				.init(index: index, factorSourceID: .fs5),
				.init(index: index, factorSourceID: .fs1),
				.init(index: index, factorSourceID: .fs2),
				.init(index: index, factorSourceID: .fs4),
				.init(index: index, factorSourceID: .fs3),
				.init(index: index, factorSourceID: .fs6),
			],
			threshold: 5,
			overrideFactors: []
		)
	}
	
	static let a3 = Self.securified(index: 3, address: "Diana") { index in
		SecurifiedEntityControl(
			thresholdFactors: [
				.init(index: index, factorSourceID: .fs2),
				.init(index: index, factorSourceID: .fs0),
				.init(index: index, factorSourceID: .fs3),
				.init(index: index, factorSourceID: .fs1),
			],
			threshold: 2,
			overrideFactors: []
		)
	}
	
	static let a4 = Self.securified(index: 4, address: "Emily") { index in
		SecurifiedEntityControl(
			thresholdFactors: [],
			threshold: 0,
			overrideFactors: [
				.init(index: index, factorSourceID: .fs7),
				.init(index: index, factorSourceID: .fs1),
				.init(index: index, factorSourceID: .fs5),
			]
		)
	}
	
	
}

extension Entity {
	static let permutations: [[Self]] = [
		[Entity.a0],
		[.a1],
		[.a2],
		[.a3],
		[.a4],
		[.a0, .a1, .a2, .a3, .a4],
		[.a1, .a2, .a3, .a4],
		[.a2, .a3, .a4],
		[.a1, .a2],
		[.a2, .a4]
	]
}

@Test(arguments: Entity.permutations)
func lazy_user(entities: [Entity]) throws {
	let context = SigningContext(
		user: .lazy,
		allFactorSourcesInProfile: .all,
		entities: entities
	)
	let signatures = context.signTransaction()
	#expect(signatures.count == entities.map(\.threshold).reduce(0, +))
}

@Test(arguments: Entity.permutations)
func prudent_user(entities: [Entity]) throws {
	let context = SigningContext(
		user: .prudent,
		allFactorSourcesInProfile: .all,
		entities: entities
	)
	let signatures = context.signTransaction()
	#expect(signatures.count == entities.map(\.factorCount).reduce(0, +))
}

@Test(arguments: Entity.permutations)
func random_user(entities: [Entity]) throws {
	let context = SigningContext(
		user: .random,
		allFactorSourcesInProfile: .all,
		entities: entities
	)
	let signatures = context.signTransaction()
	#expect(signatures.count >= entities.map(\.threshold).reduce(0, +))
}

@Test
func sorted_according_to_priority_of_kinds() throws {
	let context = SigningContext(
		user: .prudent,
		allFactorSourcesInProfile: .all,
		entities: Entity.allCases
	)
	let _ = context.signTransaction()

	let signaturesOfEntities = context.signaturesOfEntities
	
	signaturesOfEntities.forEach {
		var expected = OrderedSet(FactorSourceKind.allCases.sorted())
		let kinds = OrderedSet($0.signatures.map { $0.kind })
		expected.formIntersection(kinds)
		#expect(kinds == expected)
		
	}
}
