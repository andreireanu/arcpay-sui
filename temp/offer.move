module arcpay::offer;

use arcpay::auth_offer;
use arcpay::config::{Self, Config};
use arcpay::constant::{get_UUID_LENGTH, get_EInvalidUuid, get_EInvalidAmount, get_EInvalidPayment};
use arcpay::events;
use sui::clock::Clock;
use sui::coin::Coin;
use sui::sui::SUI;

public fun offer(
    config: &mut Config,
    payment: Coin<SUI>,
    seller: address,
    uuid: vector<u8>,
    amount: u64,
    expiry_ms: u64,
    signature: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    config.is_correct_version();
    assert!(uuid.length() == get_UUID_LENGTH(), get_EInvalidUuid());
    assert!(amount > 0, get_EInvalidAmount());
    let buyer = ctx.sender();

    auth_offer::verify(
        config.backend_pubkey(),
        &signature,
        buyer,
        seller,
        uuid,
        amount,
        expiry_ms,
        clock,
    );

    assert!(payment.value() == amount, get_EInvalidPayment());

    config.add_offer(uuid, buyer, seller, payment.into_balance());

    events::emit_offer_created(uuid, buyer, amount, clock.timestamp_ms());
}
