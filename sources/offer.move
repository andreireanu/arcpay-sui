/// Escrowed offer lifecycle: a buyer locks funds, the seller responds, and the
/// backend settles.
///
/// Terminology — the word "offer" refers to two distinct things here, in flow
/// order:
///   - Seller offer (off-chain): the seller's own listing/intent — the first
///     step in the flow. It has no on-chain object and is referenced only by its
///     `offer_id`. The seller acts on it with `seller_accept_offer` /
///     `seller_cancel_offer` (events only, no funds move).
///   - Buyer offer (on-chain escrow): the `Offer` object a buyer creates with
///     `offer` in response, locking funds in escrow. In product terms this is the
///     buyer's *counteroffer*. It carries its own id, independent of the seller
///     offer's `offer_id`. The backend resolves it with `admin_settle_offer`, or
///     the buyer reclaims it with `buyer_cancel_offer`.
///
/// The two are never linked on-chain: only the backend database knows which buyer
/// offer answers which seller offer, so buyer offers stay anonymous on-chain. A
/// buyer offer resolves several ways:
///   - the buyer cancels and reclaims the escrow (`buyer_cancel_offer`);
///   - the backend finalizes with `admin_settle_offer`, either paying the seller
///     (minus fee) or refunding the buyer.
///
/// A seller's acceptance is only a consent signal; the backend's settlement is
/// the authoritative movement of funds. For the single-transaction, no-escrow
/// path see `buy`.
module arcpay::offer;

use arcpay::auth;
use arcpay::config::Config;
use sui::balance::Balance;
use sui::clock::Clock;
use sui::coin::Coin;
use sui::event;
use sui::sui::SUI;

/// Expected length, in bytes, of an off-chain order identifier.
const UUID_LENGTH: u64 = 16;

// ==================== Errors ====================
const EInvalidUuid: u64 = 0;
const EInvalidAmount: u64 = 1;
const EInvalidPayment: u64 = 2;
const EUnauthorized: u64 = 3;

// ==================== Structures ====================

/// A buyer offer: the on-chain escrow object (a "counteroffer" in product terms)
/// holding the buyer's locked funds while the offer is outstanding.
public struct Offer has key {
    id: UID,
    uuid: vector<u8>,
    buyer: address,
    seller: address,
    escrow: Balance<SUI>,
}

// ==================== Events ====================

/// Emitted when a buyer creates and escrows a new buyer offer.
public struct OfferCreated has copy, drop {
    offer_id: ID,
    uuid: vector<u8>,
    buyer: address,
    amount: u64,
    timestamp: u64,
}

/// Emitted when a buyer cancels their own buyer offer and reclaims the escrow.
public struct BuyerOfferCanceled has copy, drop {
    offer_id: ID,
    uuid: vector<u8>,
    buyer: address,
    seller: address,
    amount: u64,
    timestamp: u64,
}

/// Emitted when a seller withdraws their seller offer (consent signal only; no
/// funds move).
public struct SellerOfferCanceled has copy, drop {
    offer_id: vector<u8>,
    seller: address,
    timestamp: u64,
}

/// Emitted when a seller accepts a buyer offer (consent signal only; funds move
/// only once the backend settles).
public struct OfferAccepted has copy, drop {
    offer_id: vector<u8>,
    seller: address,
    timestamp: u64,
}

/// Backend settlement of an accepted offer: escrow (minus fee) paid to the seller.
///
/// `auto` distinguishes how the settlement was triggered: `true` when the
/// backend's auto-accept rule fired, `false` when a seller manually accepted.
public struct OfferBought has copy, drop {
    offer_id: ID,
    uuid: vector<u8>,
    buyer: address,
    seller: address,
    seller_amount: u64,
    fee_amount: u64,
    auto: bool,
    timestamp: u64,
}

/// Backend settlement of a canceled offer: escrow refunded to the buyer.
public struct OfferRefunded has copy, drop {
    offer_id: ID,
    uuid: vector<u8>,
    buyer: address,
    seller: address,
    amount: u64,
    timestamp: u64,
}

// ==================== Public functions ====================

/// Creates a buyer offer, locking the buyer's payment in a shared escrow `Offer`.
///
/// The backend co-signs the order via `auth::verify_offer`; the full payment is
/// taken into escrow and the new buyer offer is shared so the backend can settle
/// it later.
///
/// # Arguments
/// - config: the protocol configuration (provides the backend key and version)
/// - payment: the buyer's payment coin; must equal `amount`
/// - seller: the counterparty the offer is addressed to
/// - uuid: the 16-byte off-chain order identifier
/// - amount: the SUI amount to escrow
/// - expiry_ms: timestamp (ms) after which the backend authorization is invalid
/// - signature: the backend's signature authorizing this offer
/// - clock: the shared clock, used for expiry checks and event timestamps
/// - ctx: transaction context
///
/// # Aborts
/// - If the config version does not match the current package version
/// - If `uuid` is not exactly 16 bytes
/// - If `amount` is zero
/// - If the authorization has expired or its signature is invalid
/// - If the payment value does not equal `amount`
public fun offer(
    config: &Config,
    payment: Coin<SUI>,
    seller: address,
    uuid: vector<u8>,
    amount: u64,
    expiry_ms: u64,
    signature: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    config.assert_version();
    assert!(uuid.length() == UUID_LENGTH, EInvalidUuid);
    assert!(amount > 0, EInvalidAmount);
    let buyer = ctx.sender();

    auth::verify_offer(
        config.backend_pubkey(),
        &signature,
        buyer,
        seller,
        uuid,
        amount,
        expiry_ms,
        clock,
    );

    assert!(payment.value() == amount, EInvalidPayment);

    let offer = Offer {
        id: object::new(ctx),
        uuid,
        buyer,
        seller,
        escrow: payment.into_balance(),
    };
    let offer_id = object::id(&offer);
    transfer::share_object(offer);

    event::emit(OfferCreated { offer_id, uuid, buyer, amount, timestamp: clock.timestamp_ms() });
}

/// Cancels a buyer offer and returns the full escrow to the buyer.
///
/// Only the buyer who created the offer may call this. The `Offer` object is
/// consumed and deleted.
///
/// # Arguments
/// - offer: the offer to cancel (consumed)
/// - clock: the shared clock, used for the event timestamp
/// - ctx: transaction context
///
/// # Aborts
/// - If the caller is not the buyer who owns the offer
public fun buyer_cancel_offer(offer: Offer, clock: &Clock, ctx: &mut TxContext) {
    assert!(ctx.sender() == offer.buyer, EUnauthorized);

    let offer_id = object::id(&offer);
    let Offer { id, uuid, buyer, seller, escrow } = offer;
    let amount = escrow.value();

    transfer::public_transfer(escrow.into_coin(ctx), buyer);
    id.delete();

    event::emit(BuyerOfferCanceled {
        offer_id,
        uuid,
        buyer,
        seller,
        amount,
        timestamp: clock.timestamp_ms(),
    });
}

/// Records a seller withdrawing their own seller offer (event only; no funds
/// move).
///
/// This acts on the seller's off-chain offer, referenced only by `offer_id` —
/// note it takes no on-chain `Offer`, which is the separate buyer offer (escrow).
/// The backend co-signs to attest the seller offer belongs to this seller. Any
/// linked buyer offer is settled separately by the backend via
/// `admin_settle_offer`.
///
/// # Arguments
/// - config: the protocol configuration (provides the backend key)
/// - offer_id: the 16-byte off-chain order identifier
/// - expiry_ms: timestamp (ms) after which the backend authorization is invalid
/// - signature: the backend's signature authorizing this action
/// - clock: the shared clock, used for the expiry check and event timestamp
/// - ctx: transaction context
///
/// # Aborts
/// - If the authorization has expired or its signature is invalid
public fun seller_cancel_offer(
    config: &Config,
    offer_id: vector<u8>,
    expiry_ms: u64,
    signature: vector<u8>,
    clock: &Clock,
    ctx: &TxContext,
) {
    let seller = ctx.sender();
    auth::verify_seller_auth(config.backend_pubkey(), &signature, seller, offer_id, expiry_ms, clock);

    event::emit(SellerOfferCanceled { offer_id, seller, timestamp: clock.timestamp_ms() });
}

/// Records a seller accepting a buyer offer against their seller offer (event
/// only; no funds move).
///
/// This acts on the seller's off-chain offer, referenced only by `offer_id` —
/// note it takes no on-chain `Offer`, which is the separate buyer offer (escrow).
/// The backend co-signs to attest the seller offer belongs to this seller. The
/// linked buyer offer's escrow is released to the seller separately by the
/// backend via `admin_settle_offer`.
///
/// # Arguments
/// - config: the protocol configuration (provides the backend key)
/// - offer_id: the 16-byte off-chain order identifier
/// - expiry_ms: timestamp (ms) after which the backend authorization is invalid
/// - signature: the backend's signature authorizing this action
/// - clock: the shared clock, used for the expiry check and event timestamp
/// - ctx: transaction context
///
/// # Aborts
/// - If the authorization has expired or its signature is invalid
public fun seller_accept_offer(
    config: &Config,
    offer_id: vector<u8>,
    expiry_ms: u64,
    signature: vector<u8>,
    clock: &Clock,
    ctx: &TxContext,
) {
    let seller = ctx.sender();
    auth::verify_seller_auth(config.backend_pubkey(), &signature, seller, offer_id, expiry_ms, clock);

    event::emit(OfferAccepted { offer_id, seller, timestamp: clock.timestamp_ms() });
}

/// Backend-only settlement of a buyer offer (the on-chain escrow).
///
/// When `to_seller` is true the escrow is paid to the seller, with `fee_amount`
/// retained by the protocol; otherwise the full escrow is refunded to the buyer.
/// The `Offer` object is consumed and deleted either way. Authorization is the
/// transaction sender matching the backend address derived in `config`.
///
/// # Arguments
/// - config: the protocol configuration (also collects the fee)
/// - offer: the offer to settle (consumed)
/// - to_seller: true to pay the seller, false to refund the buyer
/// - fee_amount: protocol fee to retain (only when paying the seller)
/// - auto: true if the backend's auto-accept rule triggered this settlement,
///   false if a seller manually accepted. Recorded on `OfferBought`; does not
///   affect control flow.
/// - clock: the shared clock, used for event timestamps
/// - ctx: transaction context
///
/// # Aborts
/// - If the caller is not the backend
/// - If paying the seller and `fee_amount` exceeds the escrowed amount
/// - If refunding the buyer and `fee_amount` is non-zero
public fun admin_settle_offer(
    config: &mut Config,
    offer: Offer,
    to_seller: bool,
    fee_amount: u64,
    auto: bool,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(ctx.sender() == config.backend_address(), EUnauthorized);

    let offer_id = object::id(&offer);
    let Offer { id, uuid, buyer, seller, mut escrow } = offer;
    let amount = escrow.value();
    let timestamp = clock.timestamp_ms();

    if (to_seller) {
        assert!(fee_amount <= amount, EInvalidAmount);
        if (fee_amount > 0) {
            config.fees_join(escrow.split(fee_amount));
        };
        let seller_amount = escrow.value();
        transfer::public_transfer(escrow.into_coin(ctx), seller);
        event::emit(OfferBought {
            offer_id,
            uuid,
            buyer,
            seller,
            seller_amount,
            fee_amount,
            auto,
            timestamp,
        });
    } else {
        assert!(fee_amount == 0, EInvalidAmount);
        transfer::public_transfer(escrow.into_coin(ctx), buyer);
        event::emit(OfferRefunded { offer_id, uuid, buyer, seller, amount, timestamp });
    };

    id.delete();
}
