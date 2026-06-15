/// Program events and their emitters.
module arcpay::events;

use sui::event;

public struct OfferCreated has copy, drop {
    uuid: vector<u8>,
    buyer: address,
    amount: u64,
    timestamp: u64,
}

public struct BuyCompleted has copy, drop {
    offer_id: vector<u8>,
    buyer: address,
    seller: address,
    seller_amount: u64,
    fee_amount: u64,
    timestamp: u64,
}

public struct OfferAccepted has copy, drop {
    uuid: vector<u8>,
    seller: address,
    timestamp: u64,
}

public struct BuyerOfferCanceled has copy, drop {
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

/// Backend-driven settlement of an accepted offer: escrow paid to the seller
/// (minus fee).
public struct OfferBought has copy, drop {
    uuid: vector<u8>,
    buyer: address,
    seller: address,
    seller_amount: u64,
    fee_amount: u64,
    timestamp: u64,
}

/// Backend-driven refund of an offer (listing cancel / expiry): escrow returned
/// to the buyer.
public struct OfferRefunded has copy, drop {
    uuid: vector<u8>,
    buyer: address,
    seller: address,
    amount: u64,
    timestamp: u64,
}

// === Emitters ===

public(package) fun emit_offer_created(
    uuid: vector<u8>,
    buyer: address,
    amount: u64,
    timestamp: u64,
) {
    event::emit(OfferCreated { uuid, buyer, amount, timestamp });
}

public(package) fun emit_buy_completed(
    offer_id: vector<u8>,
    buyer: address,
    seller: address,
    seller_amount: u64,
    fee_amount: u64,
    timestamp: u64,
) {
    event::emit(BuyCompleted { offer_id, buyer, seller, seller_amount, fee_amount, timestamp });
}

public(package) fun emit_offer_accepted(uuid: vector<u8>, seller: address, timestamp: u64) {
    event::emit(OfferAccepted { uuid, seller, timestamp });
}

public(package) fun emit_buyer_offer_canceled(
    uuid: vector<u8>,
    buyer: address,
    seller: address,
    amount: u64,
    timestamp: u64,
) {
    event::emit(BuyerOfferCanceled { uuid, buyer, seller, amount, timestamp });
}

public(package) fun emit_seller_offer_canceled(
    offer_id: vector<u8>,
    seller: address,
    timestamp: u64,
) {
    event::emit(SellerOfferCanceled { offer_id, seller, timestamp });
}

public(package) fun emit_offer_bought(
    uuid: vector<u8>,
    buyer: address,
    seller: address,
    seller_amount: u64,
    fee_amount: u64,
    timestamp: u64,
) {
    event::emit(OfferBought { uuid, buyer, seller, seller_amount, fee_amount, timestamp });
}

public(package) fun emit_offer_refunded(
    uuid: vector<u8>,
    buyer: address,
    seller: address,
    amount: u64,
    timestamp: u64,
) {
    event::emit(OfferRefunded { uuid, buyer, seller, amount, timestamp });
}
