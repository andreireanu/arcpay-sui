/// Instant buy: settle an order in a single transaction, no escrow.
///
/// The buyer pays `seller_amount + fee_amount` up front; the seller's share is
/// transferred immediately and the protocol fee is retained in `config`. The
/// backend co-signs the order via `auth::verify_buy`, so this path needs no
/// seller interaction. For the deferred, escrowed flow see `offer`.
module arcpay::buy;

use arcpay::auth;
use arcpay::config::Config;
use sui::clock::Clock;
use sui::coin::Coin;
use sui::event;
use sui::sui::SUI;

/// Expected length, in bytes, of an off-chain order identifier.
const UUID_LENGTH: u64 = 16;

// ==================== Errors ====================
const EInvalidUuid: u64 = 0;
const EInvalidPayment: u64 = 1;

// ==================== Events ====================

/// Emitted when an instant buy settles successfully.
public struct BuyCompleted has copy, drop {
    offer_id: vector<u8>,
    buyer: address,
    seller: address,
    seller_amount: u64,
    fee_amount: u64,
    timestamp: u64,
}

// ==================== Public functions ====================

/// Settles an order instantly: pays the seller and retains the protocol fee.
///
/// The caller (buyer) supplies a payment coin worth exactly
/// `seller_amount + fee_amount`. The fee, if any, is split into the config's fee
/// pool and the remainder is transferred to the seller.
///
/// # Arguments
/// - config: the protocol configuration (also collects the fee)
/// - payment: the buyer's payment coin; must equal `seller_amount + fee_amount`
/// - seller: the recipient of the seller's share
/// - seller_amount: amount destined for the seller
/// - fee_amount: protocol fee retained by the config
/// - offer_id: the 16-byte off-chain order identifier
/// - expiry_ms: timestamp (ms) after which the backend authorization is invalid
/// - signature: the backend's signature authorizing this buy
/// - clock: the shared clock, used for expiry checks and event timestamps
/// - ctx: transaction context
///
/// # Aborts
/// - If the config version does not match the current package version
/// - If `offer_id` is not exactly 16 bytes
/// - If the authorization has expired or its signature is invalid
/// - If the payment value does not equal `seller_amount + fee_amount`
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
