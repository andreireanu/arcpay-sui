module arcpay::buy;

use arcpay::auth;
use arcpay::config::Config;
use sui::clock::Clock;
use sui::coin::Coin;
use sui::event;
use sui::sui::SUI;

const UUID_LENGTH: u64 = 16;

const EInvalidUuid: u64 = 0;
const EInvalidPayment: u64 = 1;

public struct BuyCompleted has copy, drop {
    offer_id: vector<u8>,
    buyer: address,
    seller: address,
    seller_amount: u64,
    fee_amount: u64,
    timestamp: u64,
}

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
    assert!(offer_id.length() == UUID_LENGTH, EInvalidUuid);
    let buyer = ctx.sender();

    auth::verify_buy(
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

    assert!(payment.value() == seller_amount + fee_amount, EInvalidPayment);

    if (fee_amount > 0) {
        config.fees_join(payment.balance_mut().split(fee_amount));
    };
    transfer::public_transfer(payment, seller);

    event::emit(BuyCompleted {
        offer_id,
        buyer,
        seller,
        seller_amount,
        fee_amount,
        timestamp: clock.timestamp_ms(),
    });
}
