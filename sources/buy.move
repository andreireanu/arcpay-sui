module arcpay::buy;

use arcpay::auth_buy;
use arcpay::config::Config;
use arcpay::constants::{get_UUID_LENGTH, get_EInvalidUuid, get_EInvalidPayment};
use arcpay::events;
use sui::clock::Clock;
use sui::coin::Coin;
use sui::sui::SUI;

public fun buy(
    config: &mut Config,
    mut payment: Coin<SUI>,
    seller: address,
    seller_amount: u64,
    fee_amount: u64,
    offer_id: vector<u8>,
    expiry_ms: u64,
    signature: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    config.assert_version();
    assert!(offer_id.length() == get_UUID_LENGTH(), get_EInvalidUuid());
    let buyer = ctx.sender();

    auth_buy::verify(
        config.backend_pubkey(),
        &signature,
        buyer,
        seller,
        offer_id,
        seller_amount,
        fee_amount,
        expiry_ms,
        clock,
    );

    assert!(payment.value() == seller_amount + fee_amount, get_EInvalidPayment());

    if (fee_amount > 0) {
        config.fees_join(payment.balance_mut().split(fee_amount));
    };
    transfer::public_transfer(payment, seller);

    events::emit_buy_completed(
        offer_id,
        buyer,
        seller,
        seller_amount,
        fee_amount,
        clock.timestamp_ms(),
    );
}
