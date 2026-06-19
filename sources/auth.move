/// Authorization layer: verifies the backend's ed25519 signatures over the
/// off-chain order data.
///
/// The backend co-signs every privileged action so the chain can enforce that an
/// on-chain call matches an order the backend actually approved. Each function
/// reconstructs the exact byte string the backend signed, checks the expiry, and
/// verifies the signature against the configured backend public key. The signing
/// key lives in `config`; these helpers are package-internal and called from the
/// `offer` and `buy` flows.
module arcpay::auth;

use std::bcs;
use sui::clock::Clock;
use sui::ed25519;

// ==================== Errors ====================
const EAuthorizationExpired: u64 = 0;
const EInvalidAuthorizationSignature: u64 = 1;

// ==================== Package functions ====================

/// Verifies the backend's authorization for an instant buy.
///
/// Signed message layout (104 bytes), little-endian:
///   [0..32] buyer | [32..64] seller | [64..80] offer_id
///   [80..88] seller_amount | [88..96] fee_amount | [96..104] expiry_ms
///
/// # Arguments
/// - backend_pubkey: the backend's ed25519 public key
/// - signature: the backend signature over the message below
/// - buyer: the buyer's address
/// - seller: the seller's address
/// - offer_id: the 16-byte off-chain order identifier
/// - seller_amount: amount destined for the seller
/// - fee_amount: protocol fee taken from the payment
/// - expiry_ms: timestamp (ms) after which the authorization is no longer valid
/// - clock: the shared clock, used to read the current time
///
/// # Aborts
/// - If the authorization has expired
/// - If the signature does not verify against `backend_pubkey`
public(package) fun verify_buy(
    backend_pubkey: &vector<u8>,
    signature: &vector<u8>,
    buyer: address,
    seller: address,
    offer_id: vector<u8>,
    seller_amount: u64,
    fee_amount: u64,
    expiry_ms: u64,
    clock: &Clock,
) {
    assert!(clock.timestamp_ms() < expiry_ms, EAuthorizationExpired);

    let mut msg = sui::address::to_bytes(buyer);
    msg.append(sui::address::to_bytes(seller));
    msg.append(offer_id);
    msg.append(bcs::to_bytes(&seller_amount));
    msg.append(bcs::to_bytes(&fee_amount));
    msg.append(bcs::to_bytes(&expiry_ms));

    assert!(
        ed25519::ed25519_verify(signature, backend_pubkey, &msg),
        EInvalidAuthorizationSignature,
    );
}

/// Verifies the backend's authorization for a seller-initiated action.
///
/// Shared by seller accept and seller cancel — the backend attests the offer
/// belongs to the seller.
///
/// Signed message layout (56 bytes), little-endian:
///   [0..32] seller | [32..48] offer_id | [48..56] expiry_ms
///
/// # Arguments
/// - backend_pubkey: the backend's ed25519 public key
/// - signature: the backend signature over the message below
/// - seller: the seller's address
/// - offer_id: the 16-byte off-chain order identifier
/// - expiry_ms: timestamp (ms) after which the authorization is no longer valid
/// - clock: the shared clock, used to read the current time
///
/// # Aborts
/// - If the authorization has expired
/// - If the signature does not verify against `backend_pubkey`
public(package) fun verify_seller_auth(
    backend_pubkey: &vector<u8>,
    signature: &vector<u8>,
    seller: address,
    offer_id: vector<u8>,
    expiry_ms: u64,
    clock: &Clock,
) {
    assert!(clock.timestamp_ms() < expiry_ms, EAuthorizationExpired);

    let mut msg = sui::address::to_bytes(seller);
    msg.append(offer_id);
    msg.append(bcs::to_bytes(&expiry_ms));

    assert!(
        ed25519::ed25519_verify(signature, backend_pubkey, &msg),
        EInvalidAuthorizationSignature,
    );
}

/// Verifies the backend's authorization for creating an escrowed offer.
///
/// Signed message layout (96 bytes), little-endian:
///   [0..32] buyer | [32..64] seller | [64..80] uuid
///   [80..88] amount | [88..96] expiry_ms
///
/// # Arguments
/// - backend_pubkey: the backend's ed25519 public key
/// - signature: the backend signature over the message below
/// - buyer: the buyer's address
/// - seller: the seller's address
/// - uuid: the 16-byte off-chain order identifier
/// - amount: the SUI amount to be escrowed
/// - expiry_ms: timestamp (ms) after which the authorization is no longer valid
/// - clock: the shared clock, used to read the current time
///
/// # Aborts
/// - If the authorization has expired
/// - If the signature does not verify against `backend_pubkey`
public(package) fun verify_offer(
    backend_pubkey: &vector<u8>,
    signature: &vector<u8>,
    buyer: address,
    seller: address,
    uuid: vector<u8>,
    amount: u64,
    expiry_ms: u64,
    clock: &Clock,
) {
    assert!(clock.timestamp_ms() < expiry_ms, EAuthorizationExpired);

    let mut msg = sui::address::to_bytes(buyer);
    msg.append(sui::address::to_bytes(seller));
    msg.append(uuid);
    msg.append(bcs::to_bytes(&amount));
    msg.append(bcs::to_bytes(&expiry_ms));

    assert!(
        ed25519::ed25519_verify(signature, backend_pubkey, &msg),
        EInvalidAuthorizationSignature,
    );
}
