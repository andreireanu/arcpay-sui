module arcpay::config;

use arcpay::arcpay::AdminCap;
use sui::balance::{Self, Balance};
use sui::coin::Coin;
use sui::hash;
use sui::sui::SUI;

/// Sui signature scheme flag for ed25519, prefixed to the pubkey when deriving
/// an address.
const ED25519_FLAG: u8 = 0;

const VERSION: u64 = 22;
const BACKEND_PUBKEY_LENGTH: u64 = 32;

const EIncorrectVersion: u64 = 0;
const ENotUpgraded: u64 = 1;
const EInvalidBackendPubkey: u64 = 2;

public struct Config has key {
    id: UID,
    version: u64,
    backend_pubkey: vector<u8>,
    fees: Balance<SUI>,
}

public fun initialize_config(
    _admin_cap: &AdminCap,
    backend_pubkey: vector<u8>,
    ctx: &mut TxContext,
) {
    assert!(backend_pubkey.length() == BACKEND_PUBKEY_LENGTH, EInvalidBackendPubkey);
    transfer::share_object(Config {
        id: object::new(ctx),
        version: VERSION,
        backend_pubkey,
        fees: balance::zero(),
    });
}

public fun update_backend(config: &mut Config, _admin_cap: &AdminCap, backend_pubkey: vector<u8>) {
    config.assert_version();
    assert!(backend_pubkey.length() == BACKEND_PUBKEY_LENGTH, EInvalidBackendPubkey);
    config.backend_pubkey = backend_pubkey;
}

entry fun migrate(config: &mut Config, _admin_cap: &AdminCap) {
    assert!(config.version < VERSION, ENotUpgraded);
    config.version = VERSION;
}

public(package) fun assert_version(config: &Config) {
    assert!(config.version == VERSION, EIncorrectVersion);
}

public(package) fun backend_pubkey(config: &Config): &vector<u8> {
    &config.backend_pubkey
}

public(package) fun backend_address(config: &Config): address {
    let mut preimage = vector[ED25519_FLAG];
    preimage.append(config.backend_pubkey);
    sui::address::from_bytes(hash::blake2b256(&preimage))
}

public(package) fun fees_join(config: &mut Config, b: Balance<SUI>) {
    config.fees.join(b);
}

public fun withdraw_commission(
    config: &mut Config,
    _admin_cap: &AdminCap,
    ctx: &mut TxContext,
): Coin<SUI> {
    config.fees.withdraw_all().into_coin(ctx)
}
