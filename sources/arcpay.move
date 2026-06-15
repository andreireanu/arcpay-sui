module arcpay::arcpay;

use sui::package;

public struct ARCPAY has drop {}

public struct AdminCap has key, store {
    id: UID,
}

fun init(otw: ARCPAY, ctx: &mut TxContext) {
    package::claim_and_keep(otw, ctx);
    transfer::public_transfer(new_admin_cap(ctx), ctx.sender());
}

fun new_admin_cap(ctx: &mut TxContext): AdminCap {
    AdminCap { id: object::new(ctx) }
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ARCPAY {}, ctx);
}

#[test_only]
public fun mint_for_testing(ctx: &mut TxContext): AdminCap {
    new_admin_cap(ctx)
}
