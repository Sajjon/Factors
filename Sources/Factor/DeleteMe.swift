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
