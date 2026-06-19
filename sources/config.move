/// Protocol configuration: the shared, admin-owned object that every entry point
/// reads from.
///
/// `Config` holds the backend's ed25519 public key (used to verify the signed
/// authorizations in `auth`), an on-chain version used for upgrade gating, and
/// the running balance of protocol fees accrued from buys and settlements.
///
/// All mutating functions here are gated by the `AdminCap` from `arcpay`.
module arcpay::config;

use arcpay::arcpay::AdminCap;
use sui::balance::{Self, Balance};
use sui::coin::Coin;
use sui::hash;
use sui::sui::SUI;

/// Sui signature scheme flag for ed25519, prefixed to the pubkey when deriving
/// an address.
const ED25519_FLAG: u8 = 0;

/// Current on-chain version. Entry points assert against this so that a stale
/// `Config` (one not yet migrated after a package upgrade) is rejected.
const VERSION: u64 = 22;
/// Expected length, in bytes, of a raw ed25519 public key.
const BACKEND_PUBKEY_LENGTH: u64 = 32;

// ==================== Errors ====================
const EIncorrectVersion: u64 = 0;
const ENotUpgraded: u64 = 1;
const EInvalidBackendPubkey: u64 = 2;

// ==================== Structures ====================

/// Shared singleton holding all protocol-wide settings and accrued fees.
public struct Config has key {
    id: UID,
    version: u64,
    backend_pubkey: vector<u8>,
    fees: Balance<SUI>,
}

// ==================== Public functions ====================

/// Creates and shares the protocol `Config`. Called once by the admin after
/// publish to bootstrap the protocol with the backend's signing key.
///
/// # Arguments
/// - _admin_cap: proof of admin authority
/// - backend_pubkey: the backend's 32-byte ed25519 public key
/// - ctx: transaction context
///
/// # Aborts
/// - If `backend_pubkey` is not exactly 32 bytes
public fun initialize_config(
    _admin_cap: &AdminCap,
    backend_pubkey: vector<u8>,
    ctx: &mut TxContext,
) {
    assert!(backend_pubkey.length() == BACKEND_PUBKEY_LENGTH, EInvalidBackendPubkey);
    transfer::share_object(Config {
        id: object::new(ctx),
        version: VERSION,
        backend_pubkey,
        fees: balance::zero(),
    });
}

/// Rotates the backend signing key.
///
/// # Arguments
/// - config: the protocol configuration to update
/// - _admin_cap: proof of admin authority
/// - backend_pubkey: the new 32-byte ed25519 public key
///
/// # Aborts
/// - If the config version does not match the current package version
/// - If `backend_pubkey` is not exactly 32 bytes
public fun update_backend(config: &mut Config, _admin_cap: &AdminCap, backend_pubkey: vector<u8>) {
    config.assert_version();
    assert!(backend_pubkey.length() == BACKEND_PUBKEY_LENGTH, EInvalidBackendPubkey);
    config.backend_pubkey = backend_pubkey;
}

/// Bumps a previously published `Config` to the current package version after an
/// upgrade, re-enabling the version-gated entry points.
///
/// # Arguments
/// - config: the protocol configuration to migrate
/// - _admin_cap: proof of admin authority
///
/// # Aborts
/// - If the config is already at (or beyond) the current version
entry fun migrate(config: &mut Config, _admin_cap: &AdminCap) {
    assert!(config.version < VERSION, ENotUpgraded);
    config.version = VERSION;
}

/// Withdraws the entire accrued fee balance and returns it as a coin.
///
/// Returns the coin rather than transferring it so the call composes inside a
/// PTB; a plain `sui client call` auto-transfers the returned coin to the
/// sender. Deliberately not version-gated so fees can never be trapped behind a
/// pending migration.
///
/// # Arguments
/// - config: the protocol configuration
/// - _admin_cap: proof of admin authority
/// - ctx: transaction context
///
/// # Returns
/// - a coin holding the full fee balance (zero-valued if no fees have accrued)
public fun withdraw_commission(
    config: &mut Config,
    _admin_cap: &AdminCap,
    ctx: &mut TxContext,
): Coin<SUI> {
    config.fees.withdraw_all().into_coin(ctx)
}

// ==================== Package functions ====================

/// Asserts the config is at the current package version. Entry points call this
/// to refuse execution against a config left stale by a pending migration.
///
/// # Arguments
/// - config: the protocol configuration to check
///
/// # Aborts
/// - If the config version does not match the current package version
public(package) fun assert_version(config: &Config) {
    assert!(config.version == VERSION, EIncorrectVersion);
}

/// Returns a reference to the backend's ed25519 public key, used by `auth` to
/// verify signed authorizations.
///
/// # Arguments
/// - config: the protocol configuration
///
/// # Returns
/// - reference to the stored 32-byte public key
public(package) fun backend_pubkey(config: &Config): &vector<u8> {
    &config.backend_pubkey
}

/// Derives the Sui address controlled by the backend signing key.
///
/// The address is `blake2b256(0x00 || pubkey)`, matching Sui's ed25519 address
/// derivation (scheme flag `0x00` prefixed to the raw public key). Settlement
/// checks the transaction sender against this address.
///
/// # Arguments
/// - config: the protocol configuration
///
/// # Returns
/// - the backend's on-chain address
public(package) fun backend_address(config: &Config): address {
    let mut preimage = vector[ED25519_FLAG];
    preimage.append(config.backend_pubkey);
    sui::address::from_bytes(hash::blake2b256(&preimage))
}

/// Adds a balance to the accrued protocol fees. Called by the buy and settlement
/// flows when they split a fee off a payment.
///
/// # Arguments
/// - config: the protocol configuration
/// - b: the SUI balance to add to the fee pool
public(package) fun fees_join(config: &mut Config, b: Balance<SUI>) {
    config.fees.join(b);
}
