module arcpay::events;

use sui::event;

public struct BuyCompleted has copy, drop {
    offer_id: vector<u8>,
    buyer: address,
    seller: address,
    seller_amount: u64,
    fee_amount: u64,
    timestamp: u64,
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
