module arcpay::config;

use arcpay::arcpay::AdminCap;
use arcpay::constants::{
    get_VERSION,
    get_BACKEND_PUBKEY_LENGTH,
    get_EIncorrectVersion,
    get_ENotUpgraded,
    get_EInvalidBackendPubkey,
};
use sui::balance::{Self, Balance};
use sui::sui::SUI;

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
    assert!(backend_pubkey.length() == get_BACKEND_PUBKEY_LENGTH(), get_EInvalidBackendPubkey());
    transfer::share_object(Config {
        id: object::new(ctx),
        version: get_VERSION(),
        backend_pubkey,
        fees: balance::zero(),
    });
}

public fun update_backend(config: &mut Config, _admin_cap: &AdminCap, backend_pubkey: vector<u8>) {
    config.assert_version();
    assert!(backend_pubkey.length() == get_BACKEND_PUBKEY_LENGTH(), get_EInvalidBackendPubkey());
    config.backend_pubkey = backend_pubkey;
}


entry fun migrate(config: &mut Config, _admin_cap: &AdminCap) {
    assert!(config.version < get_VERSION(), get_ENotUpgraded());
    config.version = get_VERSION();
}

public(package) fun assert_version(config: &Config) {
    assert!(config.version == get_VERSION(), get_EIncorrectVersion());
}

public(package) fun backend_pubkey(config: &Config): &vector<u8> {
    &config.backend_pubkey
}

public(package) fun fees_join(config: &mut Config, b: Balance<SUI>) {
    config.fees.join(b);
}
