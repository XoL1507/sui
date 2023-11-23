
// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
#[allow(unused_use)]
module sui::random_tests {
    use std::vector;
    use sui::test_scenario;
    use sui::random::{
        Self,
        Random,
        update_randomness_state_for_testing, new_generator, generator_seed, generator_counter, generator_buffer, bytes,
        derive_u256, derive_u128, derive_u64, derive_u32, derive_u16, derive_u8, in_range_u128,
    };

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

        // TODO: add more tests, those are the basic ones.

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
        let output = bytes(&mut gen, 11);
        let expected_output = x"3bff1751555a41b27d4fa1";
        assert!(output == expected_output, 0);
        let o256 = derive_u256(&mut gen);
        assert!(o256 == 24828730474480621738486841678633925655019414817958929826440829032071710951741, 0);
        let o128 = derive_u128(&mut gen);
        assert!(o128 == 14412017820763709912689755607911963291, 0);
        let o64 = derive_u64(&mut gen);
        assert!(o64 == 12999399150466996990, 0);
        let o32 = derive_u32(&mut gen);
        assert!(o32 == 391931270, 0);
        let o16 = derive_u16(&mut gen);
        assert!(o16 == 36521, 0);
        let o8 = derive_u8(&mut gen);
        assert!(o8 == 229, 0);
        let output = in_range_u128(&mut gen, 51, 123456789);
        assert!(output == 34169096, 0);

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
