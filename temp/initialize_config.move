module arcpay::initialize_config;

use arcpay::admin_cap;
use arcpay::arcpay::{Self, ARCPAY};
use arcpay::constants::{get_ED25519_PUBKEY_LENGTH, get_EUnauthorized, get_EInvalidBackendPubkey};
use sui::package::Publisher;

public fun initialize_config(
    publisher: &Publisher,
    backend_pubkey: vector<u8>,
    ctx: &mut TxContext,
) {
    assert!(publisher.from_package<ARCPAY>(), get_EUnauthorized());
    assert!(backend_pubkey.length() == get_ED25519_PUBKEY_LENGTH(), get_EInvalidBackendPubkey());

    let admin_cap_id = admin_cap::create_and_transfer_admin_cap(ctx.sender(), ctx);
    arcpay::create_and_share_config(backend_pubkey, admin_cap_id, ctx);
}
