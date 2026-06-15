module arcpay::withdraw_commission;

use arcpay::admin_cap::AdminCap;
use arcpay::config::{Self, Config};
use arcpay::constant::get_EInsufficientCommissionBalance;

public fun withdraw_commission(
    config: &mut Config,
    cap: &AdminCap,
    amount: u64,
    ctx: &mut TxContext,
) {
    config.is_correct_version();
    config.assert_admin(cap);
    assert!(amount <= config.fees_value(), get_EInsufficientCommissionBalance());
    config::pay_out(config.fees_split(amount), ctx.sender(), ctx);
}
