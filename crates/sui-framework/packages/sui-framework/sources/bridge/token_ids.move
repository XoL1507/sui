module sui::token_ids {

    // token ids
    const SUI: u8 = 0;
    const BTC: u8 = 1;
    const ETH: u8 = 2;
    const USDC: u8 = 3;
    const USDT: u8 = 4;

    public fun sui(): u8 {
        SUI
    }

    public fun btc(): u8 {
        BTC
    }

    public fun eth(): u8 {
        ETH
    }

    public fun usdc(): u8 {
        USDC
    }

    public fun usdt(): u8 {
        USDT
    }
}
