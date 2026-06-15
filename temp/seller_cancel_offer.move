/// Event-only consent that the seller is cancelling their listing; refund is
/// driven by the backend via `admin_settle_offer`.
module arcpay::seller_cancel_offer;

use arcpay::events;
use sui::clock::Clock;

public fun seller_cancel_offer(offer_id: vector<u8>, clock: &Clock, ctx: &TxContext) {
    events::emit_seller_offer_canceled(offer_id, ctx.sender(), clock.timestamp_ms());
}
