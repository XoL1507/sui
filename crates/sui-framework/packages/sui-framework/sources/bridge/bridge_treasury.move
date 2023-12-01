// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module sui::bridge_treasury {
    use std::ascii::String;
    use std::option;
    use std::type_name;

    use sui::coin::{Self, TreasuryCap, Coin};
    use sui::object_bag::{Self, ObjectBag};
    use sui::sui::SUI;
    use sui::token_ids;
    use sui::transfer;
    use sui::tx_context::TxContext;

    friend sui::bridge;

    const EUnsupportedTokenType: u64 = 0;

    struct BridgeTreasury has store {
        treasuries: ObjectBag
    }

    // bridged tokens
    struct USDC has drop {}

    struct USDT has drop {}

    struct BTC has drop {}

    struct ETH has drop {}

    #[allow(unused_function)]
    /// this function is called exactly once, during the first introduction of this module.
    public(friend) fun create(ctx: &mut TxContext): BridgeTreasury {
        let treasury = BridgeTreasury {
            treasuries: object_bag::new(ctx)
        };

        let (treasury_cap, metadata) = coin::create_currency(
            BTC {},
            8,
            b"BTC",
            b"Bitcoin",
            b"Bridged Bitcoin token",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);
        object_bag::add(&mut treasury.treasuries, type_name::into_string(type_name::get<BTC>()), treasury_cap);

        let (treasury_cap, metadata) = coin::create_currency(
            ETH {},
            18,
            b"ETH",
            b"Ethereum",
            b"Bridged Ethereum token",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);
        object_bag::add(&mut treasury.treasuries, type_name::into_string(type_name::get<ETH>()), treasury_cap);

        let (treasury_cap, metadata) = coin::create_currency(
            USDC {},
            6,
            b"USDC",
            b"USDC Coin",
            b"Bridged USD Coin token",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);
        object_bag::add(&mut treasury.treasuries, type_name::into_string(type_name::get<USDC>()), treasury_cap);

        let (treasury_cap, metadata) = coin::create_currency(
            USDT {},
            6,
            b"USDT",
            b"Tether",
            b"Bridged Tether token",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);
        object_bag::add(&mut treasury.treasuries, type_name::into_string(type_name::get<USDT>()), treasury_cap);

        treasury
    }

    public(friend) fun burn<T>(self: &mut BridgeTreasury, token: Coin<T>) {
        let treasury = get_treasury<T>(self);
        coin::burn(treasury, token);
    }

    public(friend) fun mint<T>(self: &mut BridgeTreasury, amount: u64, ctx: &mut TxContext): Coin<T> {
        let treasury = get_treasury<T>(self);
        coin::mint(treasury, amount, ctx)
    }

    fun get_treasury<T>(self: &mut BridgeTreasury): &mut TreasuryCap<T> {
        assert!(is_bridged_token<T>(), EUnsupportedTokenType);
        let type = type_name::into_string(type_name::get<T>());
        object_bag::borrow_mut<String, TreasuryCap<T>>(&mut self.treasuries,type)
    }

    public fun is_bridged_token<T>(): bool {
        (type_name::get<T>() == type_name::get<BTC>()) ||
            (type_name::get<T>() == type_name::get<ETH>()) ||
            (type_name::get<T>() == type_name::get<USDC>()) ||
            (type_name::get<T>() == type_name::get<USDT>())
    }

    public fun token_id<T>(): u8 {
        let coin_type = type_name::get<T>();
        if (coin_type == type_name::get<SUI>()) {
            token_ids::sui()
        }else if (coin_type == type_name::get<BTC>()) {
            token_ids::btc()
        }else if (coin_type == type_name::get<ETH>()) {
            token_ids::eth()
        }else if (coin_type == type_name::get<USDC>()) {
            token_ids::usdc()
        }else if (coin_type == type_name::get<USDT>()) {
            token_ids::usdt()
        }else {
            abort EUnsupportedTokenType
        }
    }
}