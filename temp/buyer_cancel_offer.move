module arcpay::buyer_cancel_offer;

use arcpay::config::{Self, Config};
use arcpay::constant::get_EUnauthorized;
use arcpay::events;
use sui::clock::Clock;

public fun buyer_cancel_offer(
    config: &mut Config,
    uuid: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    config.is_correct_version();
    let (buyer, seller, escrow) = config.remove_offer(uuid);
    assert!(buyer == ctx.sender(), get_EUnauthorized());

    let amount = escrow.value();
    config::pay_out(escrow, buyer, ctx);

    events::emit_buyer_offer_canceled(uuid, buyer, seller, amount, clock.timestamp_ms());
}
