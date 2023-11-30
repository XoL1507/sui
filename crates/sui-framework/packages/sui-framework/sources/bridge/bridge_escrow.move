// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Escrow package for locking unburnable tokens/objects
module sui::bridge_escrow {
    use std::type_name::{Self, TypeName};

    use sui::bag::{Self, Bag};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::object::{Self, ID};
    use sui::tx_context::TxContext;

    friend sui::bridge;

    struct BridgeEscrow has store {
        escrow: Bag
    }

    public(friend) fun create(ctx: &mut TxContext): BridgeEscrow {
        BridgeEscrow { escrow: bag::new(ctx) }
    }

    // Escrow native tokens, e.g. SUI
    public(friend) fun escrow_token<T>(self: &mut BridgeEscrow, coin: Coin<T>) {
        let coin_type = type_name::get<T>();
        if (!bag::contains(&self.escrow, coin_type)) {
            bag::add(&mut self.escrow, coin_type, balance::zero<T>());
        };
        let balance = bag::borrow_mut<TypeName, Balance<T>>(&mut self.escrow, coin_type);
        balance::join(balance, coin::into_balance(coin));
    }

    public(friend) fun escrow_object<T: key + store>(self: &mut BridgeEscrow, obj: T) {
        bag::add(&mut self.escrow, object::id(&obj), obj);
    }

    public(friend) fun claim_object<T: store>(self: &mut BridgeEscrow, obj_id: ID): T {
        bag::remove<ID, T>(&mut self.escrow, obj_id)
    }

    public(friend) fun claim_token<T>(self: &mut BridgeEscrow, amount: u64, ctx: &mut TxContext): Coin<T> {
        let pool = bag::borrow_mut<TypeName, Balance<T>>(&mut self.escrow, type_name::get<T>());
        coin::from_balance(balance::split(pool, amount), ctx)
    }
}