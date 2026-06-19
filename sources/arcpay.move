/// Package entry module: publishes the protocol and mints the admin capability.
///
/// On publish the module claims the `Publisher` object (via the one-time witness)
/// and hands the deployer an `AdminCap`. Holding the `AdminCap` is the sole proof
/// of admin authority across the protocol — it gates configuration in `config`.
module arcpay::arcpay;

use sui::package;

/// One-time witness for this package. Consumed once in `init` to claim the
/// `Publisher`; its uniqueness guarantees `init` can never run twice.
public struct ARCPAY has drop {}

/// Capability granting admin rights over the protocol configuration.
///
/// Possession of this object is the authorization check itself — any function
/// taking `&AdminCap` can only be called by whoever holds it.
public struct AdminCap has key, store {
    id: UID,
}

/// Module initializer: runs once at publish time.
///
/// Claims the `Publisher` for the deployer and transfers the freshly minted
/// `AdminCap` to them.
///
/// # Arguments
/// - otw: the one-time witness proving this is the publish transaction
/// - ctx: transaction context
fun init(otw: ARCPAY, ctx: &mut TxContext) {
    package::claim_and_keep(otw, ctx);
    transfer::public_transfer(new_admin_cap(ctx), ctx.sender());
}

/// Creates a fresh `AdminCap`.
///
/// # Arguments
/// - ctx: transaction context
///
/// # Returns
/// - a new `AdminCap` object
fun new_admin_cap(ctx: &mut TxContext): AdminCap {
    AdminCap { id: object::new(ctx) }
}

// ==================== Test-only functions ====================

#[test_only]
/// Test helper that runs the module initializer with a dummy witness.
public fun init_for_testing(ctx: &mut TxContext) {
    init(ARCPAY {}, ctx);
}

#[test_only]
/// Test helper that mints a standalone `AdminCap` without running `init`.
public fun mint_for_testing(ctx: &mut TxContext): AdminCap {
    new_admin_cap(ctx)
}
