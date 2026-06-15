/// Backend-driven settlement of one offer record.
///   to_seller = true  — amount − fee → seller, fee → config
///   to_seller = false — amount → buyer (refund)
/// Targets and amount come from the record, so a compromised backend can only
/// route escrow to the buyer's chosen seller or back to the buyer.
module arcpay::admin_settle_offer;

use arcpay::config::{Self, Config};
use arcpay::constant::{get_EUnauthorized, get_EInvalidAmount};
use arcpay::events;
use sui::clock::Clock;

public fun admin_settle_offer(
    config: &mut Config,
    uuid: vector<u8>,
    to_seller: bool,
    fee_amount: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    config.is_correct_version();
    assert!(ctx.sender() == config.backend_address(), get_EUnauthorized());

    let (buyer, seller, mut escrow) = config.remove_offer(uuid);
    let amount = escrow.value();
    let timestamp = clock.timestamp_ms();

    if (to_seller) {
        assert!(fee_amount <= amount, get_EInvalidAmount());
        let seller_amount = amount - fee_amount;
        if (fee_amount > 0) {
            config.fees_join(escrow.split(fee_amount));
        };
        config::pay_out(escrow, seller, ctx);

        events::emit_offer_bought(uuid, buyer, seller, seller_amount, fee_amount, timestamp);
    } else {
        assert!(fee_amount == 0, get_EInvalidAmount());
        config::pay_out(escrow, buyer, ctx);

        events::emit_offer_refunded(uuid, buyer, seller, amount, timestamp);
    }
}
