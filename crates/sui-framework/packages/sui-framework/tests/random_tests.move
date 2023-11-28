
// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
#[allow(unused_use)]
module sui::random_tests {
    use std::debug; // TODO: remove before merging
    use std::vector;
    use sui::test_scenario;
    use sui::random::{
        Self,
        Random,
        update_randomness_state_for_testing, new_generator, generator_seed, generator_counter, generator_buffer, bytes,
        generate_u256, generate_u128, generate_u64, generate_u32, generate_u16, generate_u8, generate_u128_in_range,
    };

    // TODO: add one from https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-22r1a.pdf

    #[test]
    fun random_test_basic_flow() {
        let scenario_val = test_scenario::begin(@0x0);
        let scenario = &mut scenario_val;

        random::create_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, @0x0);

        let random_state = test_scenario::take_shared<Random>(scenario);
        update_randomness_state_for_testing(
            &mut random_state,
            1,
            x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F",
            test_scenario::ctx(scenario)
        );

        let gen = new_generator(&random_state, test_scenario::ctx(scenario));
        let _o256 = generate_u256(&mut gen);

        test_scenario::return_shared(random_state);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_new_generator() {
        let global_random1 = x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F";
        let global_random2 = x"2F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1A";

        // Create Random
        let scenario_val = test_scenario::begin(@0x0);
        let scenario = &mut scenario_val;
        random::create_for_testing(test_scenario::ctx(scenario));
        test_scenario::end(scenario_val);

        // Set random to global_random1
        let scenario_val = test_scenario::begin(@0x0);
        let scenario = &mut scenario_val;
        let random_state = test_scenario::take_shared<Random>(scenario);
        update_randomness_state_for_testing(
            &mut random_state,
            1,
            global_random1,
            test_scenario::ctx(scenario)
        );
        test_scenario::next_tx(scenario, @0x0);
        let gen1= new_generator(&random_state, test_scenario::ctx(scenario));
        test_scenario::return_shared(random_state);
        test_scenario::end(scenario_val);

        // Set random again to global_random1
        let scenario_val = test_scenario::begin(@0x0);
        let scenario = &mut scenario_val;
        let random_state = test_scenario::take_shared<Random>(scenario);
        update_randomness_state_for_testing(
            &mut random_state,
            2,
            global_random1,
            test_scenario::ctx(scenario)
        );
        test_scenario::next_tx(scenario, @0x0);
        let gen2= new_generator(&random_state, test_scenario::ctx(scenario));
        test_scenario::return_shared(random_state);
        test_scenario::end(scenario_val);

        // Set random to global_random2
        let scenario_val = test_scenario::begin(@0x0);
        let scenario = &mut scenario_val;
        let random_state = test_scenario::take_shared<Random>(scenario);
        update_randomness_state_for_testing(
            &mut random_state,
            3,
            global_random2,
            test_scenario::ctx(scenario)
        );
        test_scenario::next_tx(scenario, @0x0);
        let gen3= new_generator(&random_state, test_scenario::ctx(scenario));
        let gen4= new_generator(&random_state, test_scenario::ctx(scenario));
        test_scenario::return_shared(random_state);
        test_scenario::end(scenario_val);

        assert!(generator_counter(&gen1) == 0, 0);
        assert!(*generator_buffer(&gen1) == vector::empty(), 0);
        assert!(generator_seed(&gen1) == generator_seed(&gen2), 0);
        assert!(generator_seed(&gen1) != generator_seed(&gen3), 0);
        assert!(generator_seed(&gen3) != generator_seed(&gen4), 0);
    }

    #[test]
    fun test_bytes() {
        // TODO: test failure with ETooManyBytes

        let scenario_val = test_scenario::begin(@0x0);
        let scenario = &mut scenario_val;

        random::create_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, @0x0);

        let random_state = test_scenario::take_shared<Random>(scenario);
        update_randomness_state_for_testing(
            &mut random_state,
            1,
            x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F",
            test_scenario::ctx(scenario)
        );

        let gen = new_generator(&random_state, test_scenario::ctx(scenario));

        // Check the output size & internal generator state
        assert!(*generator_buffer(&gen) == vector::empty(), 0);
        let output = bytes(&mut gen, 1);
        assert!(generator_counter(&gen) == 1, 0);
        assert!(vector::length(generator_buffer(&gen)) == 31, 0);
        assert!(vector::length(&output) == 1, 0);
        let output = bytes(&mut gen, 2);
        assert!(generator_counter(&gen) == 1, 0);
        assert!(vector::length(generator_buffer(&gen)) == 29, 0);
        assert!(vector::length(&output) == 2, 0);
        let output = bytes(&mut gen, 29);
        assert!(generator_counter(&gen) == 1, 0);
        assert!(vector::length(generator_buffer(&gen)) == 0, 0);
        assert!(vector::length(&output) == 29, 0);
        let output = bytes(&mut gen, 11);
        assert!(generator_counter(&gen) == 2, 0);
        assert!(vector::length(generator_buffer(&gen)) == 21, 0);
        assert!(vector::length(&output) == 11, 0);
        let output = bytes(&mut gen, 32 * 2);
        assert!(generator_counter(&gen) == 4, 0);
        assert!(vector::length(generator_buffer(&gen)) == 21, 0);
        assert!(vector::length(&output) == 32 * 2, 0);
        let output = bytes(&mut gen, 32 * 5 + 5);
        assert!(generator_counter(&gen) == 9, 0);
        assert!(vector::length(generator_buffer(&gen)) == 16, 0);
        assert!(vector::length(&output) == 32 * 5 + 5, 0);

        // Sanity check that the output is not all zeros.
        let output = bytes(&mut gen, 10);
        let i = 0;
        while (true) { // should break before the overflow
            if (*vector::borrow(&output, i) != 0u8)
                break;
            i = i + 1;
        };

        // Sanity check that 2 different outputs are different.
        let output1 = bytes(&mut gen, 10);
        let output2 = bytes(&mut gen, 10);
        i = 0;
        while (true) { // should break before the overflow
            if (vector::borrow(&output1, i) != vector::borrow(&output2, i))
                break;
            i = i + 1;
        };

        // Regression (not critical for security, but still an indication that something is wrong).
        let output = bytes(&mut gen, 11);
        assert!(output == x"d18dd6bea8393d45affe11", 0);

        test_scenario::return_shared(random_state);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun random_tests_uints() {
        // TODO: test failure with EInvalidRange

        let scenario_val = test_scenario::begin(@0x0);
        let scenario = &mut scenario_val;

        random::create_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, @0x0);

        let random_state = test_scenario::take_shared<Random>(scenario);
        update_randomness_state_for_testing(
            &mut random_state,
            1,
            x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F",
            test_scenario::ctx(scenario)
        );

        // Regression (not critical for security, but still an indication that something is wrong).
        let gen = new_generator(&random_state, test_scenario::ctx(scenario));
        let o256 = generate_u256(&mut gen);
        assert!(o256 == 85985798878417437391783029796051418802193098452099584085821130568389745847195, 0);
        // debug::print(&o256);
        let o128 = generate_u128(&mut gen);
        assert!(o128 == 332057125240408555349883177059479920214, 0);
        // debug::print(&o128);
        let o64 = generate_u64(&mut gen);
        assert!(o64 == 13202990749492462163, 0);
        // debug::print(&o64);
        let o32 = generate_u32(&mut gen);
        assert!(o32 == 3316307786, 0);
        // debug::print(&o32);
        let o16 = generate_u16(&mut gen);
        assert!(o16 == 5961, 0);
        // debug::print(&o16);
        let o8 = generate_u8(&mut gen);
        assert!(o8 == 222, 0);
        // debug::print(&o8);
        let output = generate_u128_in_range(&mut gen, 51, 123456789);
        assert!(output == 104085884, 0);
        // debug::print(&output);

        // u256
        gen = new_generator(&random_state, test_scenario::ctx(scenario));
        assert!(*generator_buffer(&gen) == vector::empty(), 0);
        let output1 = generate_u256(&mut gen);
        assert!(generator_counter(&gen) == 1, 0);
        assert!(vector::length(generator_buffer(&gen)) == 0, 0);
        let output2 = generate_u256(&mut gen);
        assert!(generator_counter(&gen) == 2, 0);
        assert!(vector::length(generator_buffer(&gen)) == 0, 0);
        assert!(output1 != output2, 0);
        let _output3 = generate_u8(&mut gen);
        let _output4 = generate_u256(&mut gen);
        assert!(generator_counter(&gen) == 4, 0);
        assert!(vector::length(generator_buffer(&gen)) == 31, 0);

        // u128
        gen = new_generator(&random_state, test_scenario::ctx(scenario));
        assert!(*generator_buffer(&gen) == vector::empty(), 0);
        let output1 = generate_u128(&mut gen);
        assert!(generator_counter(&gen) == 1, 0);
        assert!(vector::length(generator_buffer(&gen)) == 16, 0);
        let output2 = generate_u128(&mut gen);
        assert!(generator_counter(&gen) == 1, 0);
        assert!(vector::length(generator_buffer(&gen)) == 0, 0);
        assert!(output1 != output2, 0);
        let _output3 = generate_u8(&mut gen);
        let _output4 = generate_u128(&mut gen);
        assert!(generator_counter(&gen) == 2, 0);
        assert!(vector::length(generator_buffer(&gen)) == 15, 0);

        // u64
        gen = new_generator(&random_state, test_scenario::ctx(scenario));
        assert!(*generator_buffer(&gen) == vector::empty(), 0);
        let output1 = generate_u64(&mut gen);
        assert!(generator_counter(&gen) == 1, 0);
        assert!(vector::length(generator_buffer(&gen)) == 24, 0);
        let output2 = generate_u64(&mut gen);
        assert!(generator_counter(&gen) == 1, 0);
        assert!(vector::length(generator_buffer(&gen)) == 16, 0);
        assert!(output1 != output2, 0);
        let _output3 = generate_u8(&mut gen);
        let _output4 = generate_u64(&mut gen);
        assert!(generator_counter(&gen) == 1, 0);
        assert!(vector::length(generator_buffer(&gen)) == 7, 0);

        // u32
        gen = new_generator(&random_state, test_scenario::ctx(scenario));
        assert!(*generator_buffer(&gen) == vector::empty(), 0);
        let output1 = generate_u32(&mut gen);
        assert!(generator_counter(&gen) == 1, 0);
        assert!(vector::length(generator_buffer(&gen)) == 28, 0);
        let output2 = generate_u32(&mut gen);
        assert!(generator_counter(&gen) == 1, 0);
        assert!(vector::length(generator_buffer(&gen)) == 24, 0);
        assert!(output1 != output2, 0);
        let _output3 = generate_u8(&mut gen);
        let _output4 = generate_u32(&mut gen);
        assert!(generator_counter(&gen) == 1, 0);
        assert!(vector::length(generator_buffer(&gen)) == 19, 0);

        // u16
        gen = new_generator(&random_state, test_scenario::ctx(scenario));
        assert!(*generator_buffer(&gen) == vector::empty(), 0);
        let output1 = generate_u16(&mut gen);
        assert!(generator_counter(&gen) == 1, 0);
        assert!(vector::length(generator_buffer(&gen)) == 30, 0);
        let output2 = generate_u16(&mut gen);
        assert!(generator_counter(&gen) == 1, 0);
        assert!(vector::length(generator_buffer(&gen)) == 28, 0);
        assert!(output1 != output2, 0);
        let _output3 = generate_u8(&mut gen);
        let _output4 = generate_u16(&mut gen);
        assert!(generator_counter(&gen) == 1, 0);
        assert!(vector::length(generator_buffer(&gen)) == 25, 0);

        // u8
        gen = new_generator(&random_state, test_scenario::ctx(scenario));
        assert!(*generator_buffer(&gen) == vector::empty(), 0);
        let output1 = generate_u8(&mut gen);
        assert!(generator_counter(&gen) == 1, 0);
        assert!(vector::length(generator_buffer(&gen)) == 31, 0);
        let output2 = generate_u8(&mut gen);
        assert!(generator_counter(&gen) == 1, 0);
        assert!(vector::length(generator_buffer(&gen)) == 30, 0);
        assert!(output1 != output2, 0);
        let _output3 = generate_u128(&mut gen);
        let _output4 = generate_u8(&mut gen);
        assert!(generator_counter(&gen) == 1, 0);
        assert!(vector::length(generator_buffer(&gen)) == 13, 0);

        // in_range
        gen = new_generator(&random_state, test_scenario::ctx(scenario));
        let output1 = generate_u128_in_range(&mut gen, 11, 123454321);
        assert!(generator_counter(&gen) == 1, 0);
        assert!(vector::length(generator_buffer(&gen)) == 0, 0);
        let output2 = generate_u128_in_range(&mut gen, 11, 123454321);
        assert!(generator_counter(&gen) == 2, 0);
        assert!(vector::length(generator_buffer(&gen)) == 0, 0);
        assert!(output1 != output2, 0);
        let output = generate_u128_in_range(&mut gen, 123454321, 123454321 + 1);
        assert!((output == 123454321) || (output == 123454321 + 1), 0);
        let i = 0;
        while (i < 50) {
            let min = generate_u128(&mut gen);
            let max = min + (generate_u64(&mut gen) as u128);
            let output = generate_u128_in_range(&mut gen, min, max);
            assert!(output >= min, 0);
            assert!(output <= max, 0);
            i = i + 1;
        };

        test_scenario::return_shared(random_state);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = random::EInvalidRandomnessUpdate)]
    fun random_tests_duplicate() {
        let scenario_val = test_scenario::begin(@0x0);
        let scenario = &mut scenario_val;

        random::create_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, @0x0);

        let random_state = test_scenario::take_shared<Random>(scenario);
        update_randomness_state_for_testing(
            &mut random_state,
            1,
            vector[0, 1, 2, 3],
            test_scenario::ctx(scenario)
        );
        update_randomness_state_for_testing(
            &mut random_state,
            1,
            vector[0, 1, 2, 3],
            test_scenario::ctx(scenario)
        );

        test_scenario::return_shared(random_state);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = random::EInvalidRandomnessUpdate)]
    fun random_tests_out_of_order() {
        let scenario_val = test_scenario::begin(@0x0);
        let scenario = &mut scenario_val;

        random::create_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, @0x0);

        let random_state = test_scenario::take_shared<Random>(scenario);
        update_randomness_state_for_testing(
            &mut random_state,
            1,
            vector[0, 1, 2, 3],
            test_scenario::ctx(scenario)
        );
        update_randomness_state_for_testing(
            &mut random_state,
            3,
            vector[0, 1, 2, 3],
            test_scenario::ctx(scenario)
        );

        test_scenario::return_shared(random_state);
        test_scenario::end(scenario_val);
    }
}
