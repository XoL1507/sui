
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

    // TODO: Add more tests

    // TODO: add one from https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-22r1a.pdf

    #[test]
    fun random_tests_basic() {
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

        // Generator creation
        let gen = new_generator(&random_state, test_scenario::ctx(scenario));
        assert!(generator_counter(&gen) == 0, 0);
        assert!(*generator_buffer(&gen) == vector::empty(), 0);
        let gen2 = new_generator(&random_state, test_scenario::ctx(scenario));
        assert!(generator_seed(&gen) != generator_seed(&gen2), 0);

        // Output of bytes()
        let output = bytes(&mut gen, 1);
        assert!(generator_counter(&gen) == 1, 0);
        assert!(vector::length(generator_buffer(&gen)) > 0, 0);
        assert!(vector::length(&output) == 1, 0);
        let output = bytes(&mut gen, 123);
        assert!(vector::length(&output) == 123, 0);

        // Regression (not critical for security, but still an indication that something is wrong).
        // TODO: update below values once the derivation is finalized.
        let output = bytes(&mut gen, 11);
        // assert!(output == x"6af00f2b91f2368174b274", 0);
        debug::print(&output);
        let o256 = generate_u256(&mut gen);
        // assert!(o256 == 102424989351137624442743717338301217437790586040020277745588756491405331490976, 0);
        debug::print(&o256);
        let o128 = generate_u128(&mut gen);
        // assert!(o128 == 10561522037547253597764097430796866278, 0);
        debug::print(&o128);
        let o64 = generate_u64(&mut gen);
        // assert!(o64 == 2220242459375045919, 0);
        debug::print(&o64);
        let o32 = generate_u32(&mut gen);
        // assert!(o32 == 2192545141, 0);
        debug::print(&o32);
        let o16 = generate_u16(&mut gen);
        // assert!(o16 == 22735, 0);
        debug::print(&o16);
        let o8 = generate_u8(&mut gen);
        // assert!(o8 == 14, 0);
        debug::print(&o8);
        let output = generate_u128_in_range(&mut gen, 51, 123456789);
        // assert!(output == 65131366, 0);
        debug::print(&output);

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
