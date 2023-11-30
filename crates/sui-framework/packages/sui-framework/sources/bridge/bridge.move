// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module sui::bridge {
    use std::ascii::String;
    use std::string;
    use std::type_name;
    use std::vector;

    use sui::address;
    use sui::balance;
    use sui::bcs;
    use sui::bridge_committee::{Self, BridgeCommittee};
    use sui::bridge_escrow::{Self, BridgeEscrow};
    use sui::bridge_treasury::{Self, BridgeTreasury};
    use sui::chain_ids;
    use sui::coin::{Self, Coin};
    use sui::event::emit;
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct Bridge has key {
        id: UID,
        // nonce for replay protection
        sequence_num: u64,
        // committee pub keys
        committee: BridgeCommittee,
        // Escrow for storing native tokens
        escrow: BridgeEscrow,
        // Bridge treasury for mint/burn bridged tokens
        treasury: BridgeTreasury,
        pending_messages: Table<BridgeMessageKey, BridgeMessage>,
        approved_messages: Table<BridgeMessageKey, ApprovedBridgeMessage>,
        paused: bool
    }

    // message types
    const TOKEN_BRIDGE_MSG: u8 = 0;
    //const OBJ_BRIDGE_MSG: u8 = 1;

    struct BridgeMessage has copy, store, drop {
        // 0: token , 1: object ? TBD
        message_type: u8,
        source_chain: u8,
        bridge_seq_num: u64,
        sender_address: vector<u8>,
        target_chain: u8,
        target_address: vector<u8>,
        payload: vector<u8>
    }

    struct ApprovedBridgeMessage has store {
        message: BridgeMessage,
        approved_epoch: u64,
        signatures: vector<vector<u8>>,
    }

    struct BridgeMessageKey has copy, drop, store {
        source_chain: u8,
        bridge_seq_num: u64
    }

    struct BridgeEvent has copy, drop {
        message: BridgeMessage,
        message_bytes: vector<u8>
    }

    const EUnexpectedMessageType: u64 = 0;
    const EUnauthorisedClaim: u64 = 1;
    const EMalformedMessageError: u64 = 2;
    const EUnexpectedTokenType: u64 = 3;
    const EUnexpectedChainID: u64 = 4;
    const ENotSystemAddress: u64 = 5;

    #[allow(unused_function)]
    fun create(ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == @0x0, ENotSystemAddress);
        let bridge = Bridge {
            id: object::bridge(),
            sequence_num: 0,
            committee: bridge_committee::create_genesis_static_committee(),
            escrow: bridge_escrow::create(ctx),
            treasury: bridge_treasury::create(ctx),
            pending_messages: table::new<BridgeMessageKey, BridgeMessage>(ctx),
            approved_messages: table::new<BridgeMessageKey, ApprovedBridgeMessage>(ctx),
            paused: false
        };
        transfer::share_object(bridge)
    }

    fun serialise_token_bridge_payload<T>(token: &Coin<T>): vector<u8> {
        let coin_type = bcs::to_bytes(type_name::borrow_string(&type_name::get<T>()));
        let amount = bcs::to_bytes(&balance::value(coin::balance(token)));
        vector::append(&mut coin_type, amount);
        coin_type
    }

    fun deserialise_token_bridge_payload(message: vector<u8>): (String, u64) {
        let bcs = bcs::new(message);
        let payload = bcs::peel_vec_vec_u8(&mut bcs);
        assert!(vector::length(&payload) == 2, EMalformedMessageError);
        let amount_bytes = bcs::new(vector::pop_back(&mut payload));
        let amount = bcs::peel_u64(&mut amount_bytes);

        let coin_type_bytes = bcs::new(vector::pop_back(&mut payload));
        let coin_type = string::to_ascii(string::utf8(bcs::peel_vec_u8(&mut coin_type_bytes)));
        (coin_type, amount)
    }

    fun deserialise_message(message: vector<u8>): BridgeMessage {
        let bcs = bcs::new(message);
        BridgeMessage {
            message_type: bcs::peel_u8(&mut bcs),
            bridge_seq_num: bcs::peel_u64(&mut bcs),
            source_chain: bcs::peel_u8(&mut bcs),
            sender_address: bcs::peel_vec_u8(&mut bcs),
            target_chain: bcs::peel_u8(&mut bcs),
            target_address: bcs::peel_vec_u8(&mut bcs),
            payload: bcs::into_remainder_bytes(bcs)
        }
    }

    fun serialise_message(message: BridgeMessage): vector<u8> {
        let BridgeMessage {
            message_type,
            bridge_seq_num,
            source_chain,
            sender_address,
            target_chain,
            target_address,
            payload
        } = message;

        let message = vector[];
        vector::push_back(&mut message, message_type);
        vector::append(&mut message, bcs::to_bytes(&bridge_seq_num));
        vector::push_back(&mut message, source_chain);
        vector::append(&mut message, bcs::to_bytes(&sender_address));
        vector::push_back(&mut message, target_chain);
        vector::append(&mut message, bcs::to_bytes(&target_address));
        vector::append(&mut message, payload);

        message
    }

    // Create bridge request to send token to other chain, the request will be in pending state until approved
    public fun send_token<T>(
        self: &mut Bridge,
        target_chain: u8,
        target_address: vector<u8>,
        token: Coin<T>,
        ctx: &mut TxContext
    ) {
        let bridge_seq_num = self.sequence_num;
        self.sequence_num = self.sequence_num + 1;
        // create bridge message
        let payload = serialise_token_bridge_payload(&token);
        let message = BridgeMessage {
            message_type: TOKEN_BRIDGE_MSG,
            source_chain: chain_ids::sui(),
            bridge_seq_num,
            sender_address: address::to_bytes(tx_context::sender(ctx)),
            target_chain,
            target_address,
            payload
        };
        // burn / escrow token
        if (bridge_treasury::is_bridged_token<T>()) {
            bridge_treasury::burn(&mut self.treasury, token);
        }else {
            bridge_escrow::escrow_token(&mut self.escrow, token);
        };
        // Store pending bridge request
        let key = BridgeMessageKey { source_chain: chain_ids::sui(), bridge_seq_num };
        table::add(&mut self.pending_messages, key, message);

        // emit event
        // TODO: Approvals for bridge to other chains will not be consummed because claim happens on other chain, we need to archieve old approvals on Sui.
        emit(BridgeEvent { message, message_bytes: serialise_message(message) })
    }

    // Record bridge message approvels in Sui, call by the bridge client
    public fun approve_sui_bridge_request(
        self: &mut Bridge,
        bridge_seq_num: u64,
        signatures: vector<vector<u8>>,
        ctx: &TxContext
    ) {
        let key = BridgeMessageKey { source_chain: chain_ids::sui(), bridge_seq_num };
        // retrieve pending request
        let message = table::remove(&mut self.pending_messages,key);
        let message_bytes = serialise_message(message);
        // varify signatures
        bridge_committee::verify_signatures(&self.committee, message_bytes, signatures);
        let approved_message = ApprovedBridgeMessage {
            message,
            approved_epoch: tx_context::epoch(ctx),
            signatures,
        };
        // Store approval
        table::add(&mut self.approved_messages, key, approved_message);
    }

    // Record bridge message approvels in Sui, call by the bridge client
    public fun approve_foreign_bridge_request(
        self: &mut Bridge,
        message: vector<u8>,
        signatures: vector<vector<u8>>,
        ctx: &TxContext
    ) {
        // varify signatures
        bridge_committee::verify_signatures(&self.committee, message, signatures);
        let message = deserialise_message(message);
        // Ensure message is not from Sui
        assert!(message.source_chain != chain_ids::sui(), EUnexpectedChainID);
        let approved_message = ApprovedBridgeMessage {
            message,
            approved_epoch: tx_context::epoch(ctx),
            signatures,
        };
        let key = BridgeMessageKey { source_chain: message.source_chain, bridge_seq_num: message.bridge_seq_num };

        // Store approval
        table::add(&mut self.approved_messages, key, approved_message);
    }

    // Claim token from approved bridge message
    fun claim_token_internal<T>(
        self: &mut Bridge,
        source_chain: u8,
        bridge_seq_num: u64,
        ctx: &mut TxContext
    ): (Coin<T>, address) {
        let key = BridgeMessageKey { source_chain, bridge_seq_num };
        // retrieve approved bridge message
        let ApprovedBridgeMessage {
            message,
            approved_epoch: _,
            signatures: _,
        } = table::remove(&mut self.approved_messages, key);
        // ensure target chain is Sui
        assert!(message.target_chain == chain_ids::sui(), EUnexpectedChainID);
        // get owner address
        let owner = address::from_bytes(message.target_address);
        // ensure this is a token bridge message
        assert!(message.message_type == TOKEN_BRIDGE_MSG, EUnexpectedMessageType);
        // extract token message
        let (token_type, amount) = deserialise_token_bridge_payload(message.payload);
        // check token type
        assert!(type_name::into_string(type_name::get<T>()) == token_type, EUnexpectedTokenType);
        // claim from escrow or treasury
        let token = if (bridge_treasury::is_bridged_token<T>()) {
            bridge_treasury::mint<T>(&mut self.treasury, amount, ctx)
        }else {
            bridge_escrow::claim_token(&mut self.escrow, amount, ctx)
        };
        (token, owner)
    }

    // This function can only be called by the token recipient
    public fun claim_token<T>(self: &mut Bridge, source_chain: u8, bridge_seq_num: u64, ctx: &mut TxContext): Coin<T> {
        let (token, owner) = claim_token_internal<T>(self, source_chain, bridge_seq_num, ctx);
        // Only token owner can claim the token
        assert!(tx_context::sender(ctx) == owner, EUnauthorisedClaim);
        token
    }

    // This function can be called by anyone to claim and transfer the token to the recipient
    public fun claim_and_transfer_token<T>(
        self: &mut Bridge,
        source_chain: u8,
        bridge_seq_num: u64,
        ctx: &mut TxContext
    ) {
        let (token, owner) = claim_token_internal<T>(self, source_chain, bridge_seq_num, ctx);
        transfer::public_transfer(token, owner)
    }
}
