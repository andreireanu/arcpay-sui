module arcpay::admin_cap;

public struct AdminCap has key, store {
    id: UID,
}

public(package) fun new_admin_cap(ctx: &mut TxContext): AdminCap {
    AdminCap { id: object::new(ctx) }
}

public(package) fun create_and_transfer_admin_cap(admin: address, ctx: &mut TxContext): ID {
    let admin_cap = new_admin_cap(ctx);
    let admin_cap_id = object::id(&admin_cap);
    transfer::public_transfer(admin_cap, admin);
    admin_cap_id
}

public(package) fun get_admin_cap_id(admin_cap: &AdminCap): ID {
    object::id(admin_cap)
}

#[test_only]
public fun mint_for_testing(ctx: &mut TxContext): AdminCap {
    new_admin_cap(ctx)
}
