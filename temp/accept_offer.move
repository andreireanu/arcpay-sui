module arcpay::accept_offer;

use arcpay::auth_accept_offer;
use arcpay::config::{Self, Config};
use arcpay::constant::{get_UUID_LENGTH, get_EInvalidUuid};
use arcpay::events;
use sui::clock::Clock;

public fun accept_offer(
    config: &Config,
    uuid: vector<u8>,
    expiry_ms: u64,
    signature: vector<u8>,
    clock: &Clock,
    ctx: &TxContext,
) {
    config.is_correct_version();
    assert!(uuid.length() == get_UUID_LENGTH(), get_EInvalidUuid());
    let seller = ctx.sender();

    auth_accept_offer::verify(config.backend_pubkey(), &signature, seller, uuid, expiry_ms, clock);

    events::emit_offer_accepted(uuid, seller, clock.timestamp_ms());
}
