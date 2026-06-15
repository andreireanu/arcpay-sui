/// Signed message layout (56 bytes), little-endian:
///   [0..32] seller | [32..48] uuid | [48..56] expiry_ms
module arcpay::auth_accept_offer;

use arcpay::constant::{get_EAuthorizationExpired, get_EInvalidAuthorizationSignature};
use std::bcs;
use sui::clock::Clock;
use sui::ed25519;

public(package) fun verify(
    backend_pubkey: &vector<u8>,
    signature: &vector<u8>,
    seller: address,
    uuid: vector<u8>,
    expiry_ms: u64,
    clock: &Clock,
) {
    assert!(clock.timestamp_ms() < expiry_ms, get_EAuthorizationExpired());

    let mut msg = sui::address::to_bytes(seller);
    msg.append(uuid);
    msg.append(bcs::to_bytes(&expiry_ms));

    assert!(
        ed25519::ed25519_verify(signature, backend_pubkey, &msg),
        get_EInvalidAuthorizationSignature(),
    );
}
