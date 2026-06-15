module arcpay::update_backend;

use arcpay::admin_cap::AdminCap;
use arcpay::config::{Self, Config};
use arcpay::constant::{get_ED25519_PUBKEY_LENGTH, get_EInvalidBackendPubkey};

public fun update_backend(config: &mut Config, cap: &AdminCap, backend_pubkey: vector<u8>) {
    config.is_correct_version();
    config.assert_admin(cap);
    assert!(backend_pubkey.length() == get_ED25519_PUBKEY_LENGTH(), get_EInvalidBackendPubkey());
    config.set_backend_pubkey(backend_pubkey);
}
