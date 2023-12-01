// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module sui::chain_ids {

    // Chain IDs
    const SUI: u8 = 0;
    const ETH: u8 = 1;

    public fun sui(): u8 {
        SUI
    }

    public fun eth(): u8 {
        ETH
    }
}