//
//  SignaturesOfEntity.swift
//  
//
//  Created by Alexander Cyon on 2024-06-15.
//


public enum SignaturesOfEntity: SigningProcess, Identifiable {
	case unsecurified(Unsecurified)
	case securified(SignaturesOfSecurifiedEntity)
}

extension SignaturesOfEntity {
	public typealias ID = Entity.Address

	public var id: ID {
		switch self {
		case let .securified(sec): sec.id
		case let .unsecurified(unsec): unsec.id
		}
	}
}

// MARK: Protocol
extension SignaturesOfEntity {
	public func canSkipFactorSource(id: FactorSourceID) -> Bool {
		switch self {
		case let .securified(s): s.canSkipFactorSource(id: id)
		case let .unsecurified(u): u.canSkipFactorSource(id: id)
		}
	}
	
	public func ownedFactorInstanceOfFactorSource(id: FactorSourceID) -> OwnedFactorInstance {
		switch self {
		case let .securified(s): s.ownedFactorInstanceOfFactorSource(id: id)
		case let .unsecurified(u): u.ownedFactorInstanceOfFactorSource(id: id)
		}
	}
	
	public mutating func skipFactorSource(id: FactorSourceID) {
		switch self {
		case let .securified(s):
			s.skipFactorSource(id: id)
			self = .securified(s)
		case let .unsecurified(u):
			u.skipFactorSource(id: id)
			self = .unsecurified(u)
		}
	}
	
	public var isFinishedSigning: Bool {
		switch self {
		case let .securified(s): s.isFinishedSigning
		case let .unsecurified(u): u.isFinishedSigning
		}
	}
	
	public var signatures: Set<SignatureByFactorOfEntity> {
		switch self {
		case let .securified(s): s.signatures
		case let .unsecurified(u): u.signatures
		}
	}
	
	public mutating func addSignature(_ signature: SignatureByFactorOfEntity) {
		switch self {
		case let .securified(s):
			s.addSignature(signature)
			self = .securified(s)
		case let .unsecurified(u):
			u.addSignature(signature)
			self = .unsecurified(u)
		}
	}
	
	
}

