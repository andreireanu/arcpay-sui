module arcpay::offer;

use arcpay::auth;
use arcpay::config::Config;
use sui::balance::Balance;
use sui::clock::Clock;
use sui::coin::Coin;
use sui::event;
use sui::sui::SUI;

const UUID_LENGTH: u64 = 16;

const EInvalidUuid: u64 = 0;
const EInvalidAmount: u64 = 1;
const EInvalidPayment: u64 = 2;
const EUnauthorized: u64 = 3;

public struct Offer has key {
    id: UID,
    uuid: vector<u8>,
    buyer: address,
    seller: address,
    escrow: Balance<SUI>,
}

public struct OfferCreated has copy, drop {
    offer_id: ID,
    uuid: vector<u8>,
    buyer: address,
    amount: u64,
    timestamp: u64,
}

public struct BuyerOfferCanceled has copy, drop {
    offer_id: ID,
    uuid: vector<u8>,
    buyer: address,
    seller: address,
    amount: u64,
    timestamp: u64,
}

public struct SellerOfferCanceled has copy, drop {
    offer_id: vector<u8>,
    seller: address,
    timestamp: u64,
}

public struct OfferAccepted has copy, drop {
    offer_id: vector<u8>,
    seller: address,
    timestamp: u64,
}

/// Backend settlement of an accepted offer: escrow (minus fee) paid to the seller.
public struct OfferBought has copy, drop {
    offer_id: ID,
    uuid: vector<u8>,
    buyer: address,
    seller: address,
    seller_amount: u64,
    fee_amount: u64,
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

public fun buyer_cancel_offer(offer: Offer, clock: &Clock, ctx: &mut TxContext) {
    assert!(ctx.sender() == offer.buyer, EUnauthorized);
    let (offer_id, uuid, buyer, seller, amount) = delete_offer(offer, ctx);

    event::emit(BuyerOfferCanceled {
        offer_id,
        uuid,
        buyer,
        seller,
        amount,
        timestamp: clock.timestamp_ms(),
    });
}

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

public fun admin_settle_offer(
    config: &mut Config,
    offer: Offer,
    to_seller: bool,
    fee_amount: u64,
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
            timestamp,
        });
    } else {
        assert!(fee_amount == 0, EInvalidAmount);
        transfer::public_transfer(escrow.into_coin(ctx), buyer);
        event::emit(OfferRefunded { offer_id, uuid, buyer, seller, amount, timestamp });
    };

    id.delete();
}

fun delete_offer(offer: Offer, ctx: &mut TxContext): (ID, vector<u8>, address, address, u64) {
    let offer_id = object::id(&offer);
    let Offer { id, uuid, buyer, seller, escrow } = offer;
    let amount = escrow.value();

    transfer::public_transfer(escrow.into_coin(ctx), buyer);
    id.delete();

    (offer_id, uuid, buyer, seller, amount)
}
