/// Signed message layout (104 bytes), little-endian:
///   [0..32] buyer | [32..64] seller | [64..80] offer_id
///   [80..88] seller_amount | [88..96] fee_amount | [96..104] expiry_ms
module arcpay::auth_buy;

use arcpay::constants::{get_EAuthorizationExpired, get_EInvalidAuthorizationSignature};
use std::bcs;
use sui::clock::Clock;
use sui::ed25519;

public(package) fun verify(
    backend_pubkey: &vector<u8>,
    signature: &vector<u8>,
    buyer: address,
    seller: address,
    offer_id: vector<u8>,
    seller_amount: u64,
    fee_amount: u64,
    expiry_ms: u64,
    clock: &Clock,
) {
    assert!(clock.timestamp_ms() < expiry_ms, get_EAuthorizationExpired());

    let mut msg = sui::address::to_bytes(buyer);
    msg.append(sui::address::to_bytes(seller));
    msg.append(offer_id);
    msg.append(bcs::to_bytes(&seller_amount));
    msg.append(bcs::to_bytes(&fee_amount));
    msg.append(bcs::to_bytes(&expiry_ms));

    assert!(
        ed25519::ed25519_verify(signature, backend_pubkey, &msg),
        get_EInvalidAuthorizationSignature(),
    );
}
