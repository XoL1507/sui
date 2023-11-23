// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// This module provides functionality for generating secure randomness.
module sui::random {
    use std::bcs;
    use std::vector;
    use sui::address::to_bytes;
    use sui::hash::blake2b256;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext, fresh_object_address};
    use sui::versioned::{Self, Versioned};

    // Sender is not @0x0 the system address.
    const ENotSystemAddress: u64 = 0;
    const EWrongInnerVersion: u64 = 1;
    const EInvalidRandomnessUpdate: u64 = 2;
    const ETooManyBytes: u64 = 3;
    const EInvalidRange: u64 = 4;

    const CURRENT_VERSION: u64 = 1;

    /// Singleton shared object which stores the global randomness state.
    /// The actual state is stored in a versioned inner field.
    struct Random has key {
        id: UID,
        inner: Versioned,
    }

    struct RandomInner has store {
        version: u64,
        epoch: u64,
        randomness_round: u64,
        random_bytes: vector<u8>,
    }

    #[allow(unused_function)]
    /// Create and share the Random object. This function is called exactly once, when
    /// the Random object is first created.
    /// Can only be called by genesis or change_epoch transactions.
    fun create(ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == @0x0, ENotSystemAddress);

        let version = CURRENT_VERSION;

        let inner = RandomInner {
            version,
            epoch: tx_context::epoch(ctx),
            randomness_round: 0,
            random_bytes: vector[],
        };

        let self = Random {
            id: object::randomness_state(),
            inner: versioned::create(version, inner, ctx),
        };
        transfer::share_object(self);
    }

    #[test_only]
    public fun create_for_testing(ctx: &mut TxContext) {
        create(ctx);
    }

    fun load_inner_mut(
        self: &mut Random,
    ): &mut RandomInner {
        let version = versioned::version(&self.inner);

        // Replace this with a lazy update function when we add a new version of the inner object.
        assert!(version == CURRENT_VERSION, EWrongInnerVersion);
        let inner: &mut RandomInner = versioned::load_value_mut(&mut self.inner);
        assert!(inner.version == version, EWrongInnerVersion);
        inner
    }

    fun load_inner(
        self: &Random,
    ): &RandomInner {
        let version = versioned::version(&self.inner);

        // Replace this with a lazy update function when we add a new version of the inner object.
        assert!(version == CURRENT_VERSION, EWrongInnerVersion);
        let inner: &RandomInner = versioned::load_value(&self.inner);
        assert!(inner.version == version, EWrongInnerVersion);
        inner
    }

    #[allow(unused_function)]
    /// Record new randomness. Called when executing the RandomnessStateUpdate system
    /// transaction.
    fun update_randomness_state(
        self: &mut Random,
        new_round: u64,
        new_bytes: vector<u8>,
        ctx: &TxContext,
    ) {
        // Validator will make a special system call with sender set as 0x0.
        assert!(tx_context::sender(ctx) == @0x0, ENotSystemAddress);

        // Randomness should only be incremented.
        let epoch = tx_context::epoch(ctx);
        let inner = load_inner_mut(self);
        assert!(
            (epoch == inner.epoch + 1 && inner.randomness_round == 0) ||
                (new_round == inner.randomness_round + 1),
            EInvalidRandomnessUpdate
        );

        inner.epoch = tx_context::epoch(ctx);
        inner.randomness_round = new_round;
        inner.random_bytes = new_bytes;
    }

    #[test_only]
    public fun update_randomness_state_for_testing(
        self: &mut Random,
        new_round: u64,
        new_bytes: vector<u8>,
        ctx: &TxContext,
    ) {
        update_randomness_state(self, new_round, new_bytes, ctx);
    }


    /// Unique randomness generator, derived from the global randomness.
    struct RandomGenerator has drop {
        seed: vector<u8>,
        counter: u64,
        buffer: vector<u8>,
    }

    const RAND_OUTPUT_LEN: u16 = 32;
    const MAX_RANDOM_BYTES: u16 = RAND_OUTPUT_LEN * 100;

    /// Create a generator.
    public fun new_generator(r: &Random, ctx: &mut TxContext): RandomGenerator {
        let inner = load_inner(r);
        // TODO[crypto]: PRF - should we use keyed blake2b256? or something else?
        let seed_inputs = inner.random_bytes;
        vector::append(&mut seed_inputs, to_bytes(fresh_object_address(ctx)));
        let seed = blake2b256(&seed_inputs);
        RandomGenerator { seed, counter: 0, buffer: vector::empty() }
    }

    // TODO[move]: Should any of the following functions be implemented as native functions to save gas?

    // Fill the buffer with 32 random bytes.
    fun fill_buffer(g: &mut RandomGenerator) {
        // TODO[crypto]: PRF - should we used keyed blake2b256? or something else?
        let inputs = g.seed;
        vector::append(&mut inputs, bcs::to_bytes(&g.counter));
        g.counter = g.counter + 1;
        vector::append(&mut g.buffer, blake2b256(&inputs));
    }

    /// Derive n random bytes.
    public fun bytes(g: &mut RandomGenerator, num_of_bytes: u16): vector<u8> {
        // TODO[move]: should we have this limit or just leave it to gas limit?
        assert!(num_of_bytes <= MAX_RANDOM_BYTES, ETooManyBytes);
        let result = vector::empty();
        let num_of_derived_bytes = 0;
        while (num_of_derived_bytes < num_of_bytes) {
            if (vector::length(&g.buffer) == 0) {
                fill_buffer(g);
            };
            vector::push_back(&mut result, vector::pop_back(&mut g.buffer));
            num_of_derived_bytes = num_of_derived_bytes + 1;
        };
        result
    }

    // Helper function that extracts the given number of bytes from the random generator and returns it as u256.
    // Assumes that the caller has already checked that num_of_bytes is valid.
    fun u256_from_bytes(g: &mut RandomGenerator, num_of_bytes: u16): u256 {
        let bytes = bytes(g, num_of_bytes);
        let result: u256 = 0;
        let i = 0;
        while (i < num_of_bytes) {
            let byte = *vector::borrow(&bytes, (i as u64));
            result = (result << 8) + (byte as u256);
            i = i + 1;
        };
        result
    }

    /// Derive a u256.
    public fun derive_u256(g: &mut RandomGenerator): u256 {
        u256_from_bytes(g, 32)
    }

    /// Derive a u128.
    public fun derive_u128(g: &mut RandomGenerator): u128 {
        (u256_from_bytes(g, 16) as u128)
    }

    /// Derive a u64.
    public fun derive_u64(g: &mut RandomGenerator): u64 {
        (u256_from_bytes(g, 8) as u64)
    }

    /// Derive a u32.
    public fun derive_u32(g: &mut RandomGenerator): u32 {
        (u256_from_bytes(g, 4) as u32)
    }

    /// Derive a u16.
    public fun derive_u16(g: &mut RandomGenerator): u16 {
        (u256_from_bytes(g, 2) as u16)
    }

    /// Derive a u8.
    public fun derive_u8(g: &mut RandomGenerator): u8 {
        (u256_from_bytes(g, 1) as u8)
    }

    /// Derive a random u128 in [min, max] (with a bias of 2^{-128}).
    public fun in_range_u128(g: &mut RandomGenerator, min: u128, max: u128): u128 {
        assert!(min < max, EInvalidRange);
        let diff = ((max - min + 1) as u256);
        let rand = derive_u256(g);
        ((rand % diff) as u128) + min
    }

    #[test_only]
    public fun generator_seed(r: &RandomGenerator): &vector<u8> {
        &r.seed
    }

    #[test_only]
    public fun generator_counter(r: &RandomGenerator): u64 {
        r.counter
    }

    #[test_only]
    public fun generator_buffer(r: &RandomGenerator): &vector<u8> {
        &r.buffer
    }

}
