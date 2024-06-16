import Testing
import Factor
import Algorithms

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

extension Entity: @retroactive CaseIterable {
	public static let allCases = [Self.a0, .a1, .a2, .a3, .a4]
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
	
	static let a1 = Self.unsecure(index: 1, address: "Bob") { index in
		UnsecurifiedEntityControl(index: index, factorSourceID: .fs4)
	}
	
	static let a2 = Self.securified(index: 2, address: "Carol") { index in
		SecurifiedEntityControl(
			thresholdFactors: [
				.init(index: index, factorSourceID: .fs0),
				.init(index: index, factorSourceID: .fs1),
				.init(index: index, factorSourceID: .fs2),
				.init(index: index, factorSourceID: .fs3),
			],
			threshold: 4,
			overrideFactors: []
		)
	}
	
	static let a3 = Self.securified(index: 3, address: "Diana") { index in
		SecurifiedEntityControl(
			thresholdFactors: [
				.init(index: index, factorSourceID: .fs0),
				.init(index: index, factorSourceID: .fs1),
				.init(index: index, factorSourceID: .fs2),
				.init(index: index, factorSourceID: .fs3),
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
				.init(index: index, factorSourceID: .fs1),
				.init(index: index, factorSourceID: .fs2),
				.init(index: index, factorSourceID: .fs3),
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
		[.a0, .a4]
	]
}

@Test(arguments: Entity.permutations)
func lazy_user(entities: [Entity]) throws {
	let context = Context(
		user: .lazy,
		allFactorSourcesInProfile: .all,
		entities: entities
	)
	let signatures = context.signTransaction()
	#expect(signatures.count == entities.map(\.threshold).reduce(0, +))
}

@Test(arguments: Entity.permutations)
func prudent_user(entities: [Entity]) throws {
	let entities = [Entity.a0, .a1]
	let context = Context(
		user: .prudent,
		allFactorSourcesInProfile: .all,
		entities: entities
	)
	let signatures = context.signTransaction()
	#expect(signatures.count == entities.map(\.factorCount).reduce(0, +))
}

@Test(arguments: Entity.permutations)
func random_user(entities: [Entity]) throws {
	let entities = [Entity.a0, .a1]
	let context = Context(
		user: .random,
		allFactorSourcesInProfile: .all,
		entities: entities
	)
	let signatures = context.signTransaction()
	#expect(signatures.count >= entities.map(\.threshold).reduce(0, +))
}
