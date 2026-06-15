module arcpay::arcpay;

use arcpay::admin_cap::{AdminCap, get_admin_cap_id};
use arcpay::constants::{
    get_VERSION,
    get_ED25519_FLAG,
    get_EIncorrectVersion,
    get_EUnauthorized,
    get_ENotUpgrade,
};
use sui::balance::{Self, Balance};
use sui::coin;
use sui::hash;
use sui::package;
use sui::sui::SUI;

public struct ARCPAY has drop {}

public struct Config has key {
    id: UID,
    version: u64,
    admin: ID,
    backend_pubkey: vector<u8>,
    fees: Balance<SUI>,
}

public struct Offer has key {
    id: UID,
    uuid: vector<u8>,
    buyer: address,
    seller: address,
    escrow: Balance<SUI>,
}

fun init(otw: ARCPAY, ctx: &mut TxContext) {
    package::claim_and_keep(otw, ctx);
}

entry fun migrate(config: &mut Config, admin_cap: &AdminCap) {
    config.assert_admin(admin_cap);
    assert!(config.version < get_VERSION(), get_ENotUpgrade());
    config.version = get_VERSION();
}

public(package) fun create_and_share_config(
    backend_pubkey: vector<u8>,
    admin_cap_id: ID,
    ctx: &mut TxContext,
) {
    transfer::share_object(Config {
        id: object::new(ctx),
        version: get_VERSION(),
        admin: admin_cap_id,
        backend_pubkey,
        fees: balance::zero(),
    });
}

public(package) fun new_and_share_offer(
    uuid: vector<u8>,
    buyer: address,
    seller: address,
    escrow: Balance<SUI>,
    ctx: &mut TxContext,
) {
    transfer::share_object(Offer { id: object::new(ctx), uuid, buyer, seller, escrow });
}

public(package) fun destroy_offer(offer: Offer): (vector<u8>, address, address, Balance<SUI>) {
    let Offer { id, uuid, buyer, seller, escrow } = offer;
    id.delete();
    (uuid, buyer, seller, escrow)
}

public(package) fun set_backend_pubkey(config: &mut Config, backend_pubkey: vector<u8>) {
    config.backend_pubkey = backend_pubkey;
}

public(package) fun fees_join(config: &mut Config, b: Balance<SUI>) {
    config.fees.join(b);
}

public(package) fun fees_split(config: &mut Config, amount: u64): Balance<SUI> {
    config.fees.split(amount)
}

public(package) fun pay_out(b: Balance<SUI>, recipient: address, ctx: &mut TxContext) {
    transfer::public_transfer(b.into_coin(ctx), recipient);
}

public(package) fun assert_admin(config: &Config, cap: &AdminCap) {
    assert!(config.admin == get_admin_cap_id(cap), get_EUnauthorized());
}

public(package) fun is_correct_version(config: &Config) {
    assert!(config.version == get_VERSION(), get_EIncorrectVersion());
}

public fun version(config: &Config): u64 { config.version }

public fun admin(config: &Config): ID { config.admin }

public fun backend_pubkey(config: &Config): &vector<u8> { &config.backend_pubkey }

public fun backend_address(config: &Config): address {
    derive_ed25519_address(&config.backend_pubkey)
}

public fun fees_value(config: &Config): u64 { config.fees.value() }

public fun offer_uuid(offer: &Offer): vector<u8> { offer.uuid }

public fun offer_buyer(offer: &Offer): address { offer.buyer }

public fun offer_seller(offer: &Offer): address { offer.seller }

public fun offer_amount(offer: &Offer): u64 { offer.escrow.value() }

fun derive_ed25519_address(pubkey: &vector<u8>): address {
    let mut data = vector[get_ED25519_FLAG()];
    data.append(*pubkey);
    sui::address::from_bytes(hash::blake2b256(&data))
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ARCPAY {}, ctx);
}

#[test_only]
public fun set_version_for_testing(config: &mut Config, v: u64) {
    config.version = v;
}
