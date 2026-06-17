#[test_only]
module arcpay::arcpay_tests;

use arcpay::arcpay::{Self, AdminCap};
use arcpay::auth;
use arcpay::buy;
use arcpay::config::{Self, Config};
use arcpay::offer::{Self, Offer};
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::test_scenario as ts;

// Abort codes mirrored from the source modules (consts there are module-private,
// so they can't be referenced directly in expected_failure attributes).
const E_PUBKEY_LEN: u64 = 2; // config::EInvalidBackendPubkey
const E_NOT_UPGRADED: u64 = 1; // config::ENotUpgraded
const E_OFFER_UUID: u64 = 0; // offer::EInvalidUuid
const E_OFFER_AMOUNT: u64 = 1; // offer::EInvalidAmount
const E_OFFER_PAYMENT: u64 = 2; // offer::EInvalidPayment
const E_OFFER_UNAUTH: u64 = 3; // offer::EUnauthorized
const E_BUY_UUID: u64 = 0; // buy::EInvalidUuid
const E_BUY_PAYMENT: u64 = 1; // buy::EInvalidPayment
const E_AUTH_EXPIRED: u64 = 0; // auth::EAuthorizationExpired
const E_AUTH_SIG: u64 = 1; // auth::EInvalidAuthorizationSignature

// Fixed test vectors from tests/gen_vectors.mjs (backend seed = 32 bytes of 0x07).
const BACKEND_PUBKEY: vector<u8> = x"ea4a6c63e29c520abef5507b132ec5f9954776aebebe7b92421eea691446d22c";
const BACKEND: address = @0xa0ccc8bcc83f6c628340134f8546a21e0618fd1aaa02432bba454c4a2c2233da;
const BUYER: address = @0xcafe;
const SELLER: address = @0xbeef;
const ADMIN: address = @0xad;
const UUID: vector<u8> = x"abababababababababababababababab";
const ALT_PUBKEY: vector<u8> = x"0909090909090909090909090909090909090909090909090909090909090909";

const AMOUNT: u64 = 1000;
const SELLER_AMOUNT: u64 = 900;
const FEE: u64 = 100;
const EXPIRY: u64 = 9000000000000;

const OFFER_SIG: vector<u8> = x"33a313f81f521609077f80264e6075941ace97c845af5dd5c0f0d16e396b5e379c7068af85fd82d2351e2687fc34482c957bf6c8ceaf7c83d0af544cb70ad50b";
const BUY_SIG: vector<u8> = x"71bc952cc86ea0418a4bbf49c2ac13180dd80a6112caeef3df29a3d88e8a23eb70ef8a3f38927dba2b9abec6f50f9dea34dc0c21ce7beb2ca4e689167ed8a805";
const BUY_NOFEE_SIG: vector<u8> = x"1fe5d5cd7825de80eb27bf86b8f5d11fa5b509eafc95aa6bb6b21de087bd42a5f31a94cf97cbf109f7fb05c029bda9e48389d5e8fcc2a3e37c4a2d79f6524c05";
const SELLER_SIG: vector<u8> = x"7ba6bcde5bb429a166b1c07ec869c64cdee023fcb5d06577bdc375fdf61e2368e28ab7e30951bb8d21e31a36b6563e9e5a61160e1264a0c5d394297b515bce0a";

// === helpers ===

// Deploy + initialize_config, leaving the shared Config in place.
fun setup(): ts::Scenario {
    let mut sc = ts::begin(ADMIN);
    arcpay::init_for_testing(sc.ctx());
    sc.next_tx(ADMIN);
    {
        let cap = sc.take_from_sender<AdminCap>();
        config::initialize_config(&cap, BACKEND_PUBKEY, sc.ctx());
        sc.return_to_sender(cap);
    };
    sc.next_tx(ADMIN);
    sc
}

// Buyer creates the standard offer (escrows AMOUNT for SELLER under UUID).
fun create_offer(sc: &mut ts::Scenario, clock: &Clock) {
    sc.next_tx(BUYER);
    let cfg = sc.take_shared<Config>();
    let payment = coin::mint_for_testing<SUI>(AMOUNT, sc.ctx());
    offer::offer(&cfg, payment, SELLER, UUID, AMOUNT, EXPIRY, OFFER_SIG, clock, sc.ctx());
    ts::return_shared(cfg);
}

fun assert_received(sc: &mut ts::Scenario, who: address, amount: u64) {
    sc.next_tx(who);
    let c = sc.take_from_sender<Coin<SUI>>();
    assert!(c.value() == amount, 0);
    sc.return_to_sender(c);
}

// === config ===

#[test]
fun test_initialize_config() {
    let mut sc = setup();
    let cfg = sc.take_shared<Config>();
    // Validates the on-chain backend-address derivation matches the off-chain one.
    assert!(cfg.backend_address() == BACKEND, 0);
    ts::return_shared(cfg);
    sc.end();
}

#[test]
#[expected_failure(abort_code = E_PUBKEY_LEN, location = config)]
fun test_initialize_config_bad_pubkey_len_fails() {
    let mut sc = ts::begin(ADMIN);
    arcpay::init_for_testing(sc.ctx());
    sc.next_tx(ADMIN);
    let cap = sc.take_from_sender<AdminCap>();
    config::initialize_config(&cap, x"0011", sc.ctx());
    sc.return_to_sender(cap);
    sc.end();
}

#[test]
#[expected_failure(abort_code = E_NOT_UPGRADED, location = config)]
fun test_migrate_not_upgraded_fails() {
    let mut sc = setup();
    let mut cfg = sc.take_shared<Config>();
    let cap = sc.take_from_address<AdminCap>(ADMIN);
    config::migrate(&mut cfg, &cap);
    ts::return_to_address(ADMIN, cap);
    ts::return_shared(cfg);
    sc.end();
}

#[test]
fun test_update_backend() {
    let mut sc = setup();
    sc.next_tx(ADMIN);
    let mut cfg = sc.take_shared<Config>();
    let cap = sc.take_from_sender<AdminCap>();
    config::update_backend(&mut cfg, &cap, ALT_PUBKEY);
    assert!(cfg.backend_address() != BACKEND, 0);
    sc.return_to_sender(cap);
    ts::return_shared(cfg);
    sc.end();
}

// === offer / buyer cancel ===

#[test]
fun test_offer_then_buyer_cancel() {
    let mut sc = setup();
    let clock = clock::create_for_testing(sc.ctx());
    create_offer(&mut sc, &clock);

    sc.next_tx(BUYER);
    {
        let off = sc.take_shared<Offer>();
        offer::buyer_cancel_offer(off, &clock, sc.ctx());
    };
    assert_received(&mut sc, BUYER, AMOUNT);

    clock.destroy_for_testing();
    sc.end();
}

#[test]
#[expected_failure(abort_code = E_OFFER_UUID, location = offer)]
fun test_offer_bad_uuid_len_fails() {
    let mut sc = setup();
    let clock = clock::create_for_testing(sc.ctx());
    sc.next_tx(BUYER);
    let cfg = sc.take_shared<Config>();
    let payment = coin::mint_for_testing<SUI>(AMOUNT, sc.ctx());
    offer::offer(&cfg, payment, SELLER, x"00", AMOUNT, EXPIRY, OFFER_SIG, &clock, sc.ctx());
    ts::return_shared(cfg);
    clock.destroy_for_testing();
    sc.end();
}

#[test]
#[expected_failure(abort_code = E_OFFER_AMOUNT, location = offer)]
fun test_offer_zero_amount_fails() {
    let mut sc = setup();
    let clock = clock::create_for_testing(sc.ctx());
    sc.next_tx(BUYER);
    let cfg = sc.take_shared<Config>();
    let payment = coin::mint_for_testing<SUI>(0, sc.ctx());
    offer::offer(&cfg, payment, SELLER, UUID, 0, EXPIRY, OFFER_SIG, &clock, sc.ctx());
    ts::return_shared(cfg);
    clock.destroy_for_testing();
    sc.end();
}

#[test]
#[expected_failure(abort_code = E_AUTH_SIG, location = auth)]
fun test_offer_wrong_signature_fails() {
    let mut sc = setup();
    let clock = clock::create_for_testing(sc.ctx());
    sc.next_tx(BUYER);
    let cfg = sc.take_shared<Config>();
    let payment = coin::mint_for_testing<SUI>(AMOUNT, sc.ctx());
    offer::offer(&cfg, payment, SELLER, UUID, AMOUNT, EXPIRY, SELLER_SIG, &clock, sc.ctx());
    ts::return_shared(cfg);
    clock.destroy_for_testing();
    sc.end();
}

#[test]
#[expected_failure(abort_code = E_OFFER_PAYMENT, location = offer)]
fun test_offer_wrong_payment_fails() {
    let mut sc = setup();
    let clock = clock::create_for_testing(sc.ctx());
    sc.next_tx(BUYER);
    let cfg = sc.take_shared<Config>();
    let payment = coin::mint_for_testing<SUI>(AMOUNT - 1, sc.ctx());
    offer::offer(&cfg, payment, SELLER, UUID, AMOUNT, EXPIRY, OFFER_SIG, &clock, sc.ctx());
    ts::return_shared(cfg);
    clock.destroy_for_testing();
    sc.end();
}

#[test]
#[expected_failure(abort_code = E_AUTH_EXPIRED, location = auth)]
fun test_offer_expired_fails() {
    let mut sc = setup();
    let mut clock = clock::create_for_testing(sc.ctx());
    clock.set_for_testing(EXPIRY + 1);
    sc.next_tx(BUYER);
    let cfg = sc.take_shared<Config>();
    let payment = coin::mint_for_testing<SUI>(AMOUNT, sc.ctx());
    offer::offer(&cfg, payment, SELLER, UUID, AMOUNT, EXPIRY, OFFER_SIG, &clock, sc.ctx());
    ts::return_shared(cfg);
    clock.destroy_for_testing();
    sc.end();
}

#[test]
#[expected_failure(abort_code = E_OFFER_UNAUTH, location = offer)]
fun test_buyer_cancel_wrong_sender_fails() {
    let mut sc = setup();
    let clock = clock::create_for_testing(sc.ctx());
    create_offer(&mut sc, &clock);

    sc.next_tx(SELLER);
    let off = sc.take_shared<Offer>();
    offer::buyer_cancel_offer(off, &clock, sc.ctx());

    clock.destroy_for_testing();
    sc.end();
}

// === buy ===

#[test]
fun test_buy_with_fee() {
    let mut sc = setup();
    let clock = clock::create_for_testing(sc.ctx());
    sc.next_tx(BUYER);
    {
        let mut cfg = sc.take_shared<Config>();
        let payment = coin::mint_for_testing<SUI>(SELLER_AMOUNT + FEE, sc.ctx());
        buy::buy(&mut cfg, payment, SELLER, SELLER_AMOUNT, FEE, UUID, EXPIRY, BUY_SIG, &clock, sc.ctx());
        ts::return_shared(cfg);
    };
    assert_received(&mut sc, SELLER, SELLER_AMOUNT);
    clock.destroy_for_testing();
    sc.end();
}

#[test]
fun test_buy_no_fee() {
    let mut sc = setup();
    let clock = clock::create_for_testing(sc.ctx());
    sc.next_tx(BUYER);
    {
        let mut cfg = sc.take_shared<Config>();
        let payment = coin::mint_for_testing<SUI>(AMOUNT, sc.ctx());
        buy::buy(&mut cfg, payment, SELLER, AMOUNT, 0, UUID, EXPIRY, BUY_NOFEE_SIG, &clock, sc.ctx());
        ts::return_shared(cfg);
    };
    assert_received(&mut sc, SELLER, AMOUNT);
    clock.destroy_for_testing();
    sc.end();
}

#[test]
#[expected_failure(abort_code = E_BUY_UUID, location = buy)]
fun test_buy_bad_uuid_len_fails() {
    let mut sc = setup();
    let clock = clock::create_for_testing(sc.ctx());
    sc.next_tx(BUYER);
    let mut cfg = sc.take_shared<Config>();
    let payment = coin::mint_for_testing<SUI>(SELLER_AMOUNT + FEE, sc.ctx());
    buy::buy(&mut cfg, payment, SELLER, SELLER_AMOUNT, FEE, x"00", EXPIRY, BUY_SIG, &clock, sc.ctx());
    ts::return_shared(cfg);
    clock.destroy_for_testing();
    sc.end();
}

#[test]
#[expected_failure(abort_code = E_AUTH_SIG, location = auth)]
fun test_buy_wrong_signature_fails() {
    let mut sc = setup();
    let clock = clock::create_for_testing(sc.ctx());
    sc.next_tx(BUYER);
    let mut cfg = sc.take_shared<Config>();
    let payment = coin::mint_for_testing<SUI>(SELLER_AMOUNT + FEE, sc.ctx());
    buy::buy(&mut cfg, payment, SELLER, SELLER_AMOUNT, FEE, UUID, EXPIRY, OFFER_SIG, &clock, sc.ctx());
    ts::return_shared(cfg);
    clock.destroy_for_testing();
    sc.end();
}

#[test]
#[expected_failure(abort_code = E_BUY_PAYMENT, location = buy)]
fun test_buy_wrong_payment_fails() {
    let mut sc = setup();
    let clock = clock::create_for_testing(sc.ctx());
    sc.next_tx(BUYER);
    let mut cfg = sc.take_shared<Config>();
    let payment = coin::mint_for_testing<SUI>(SELLER_AMOUNT, sc.ctx());
    buy::buy(&mut cfg, payment, SELLER, SELLER_AMOUNT, FEE, UUID, EXPIRY, BUY_SIG, &clock, sc.ctx());
    ts::return_shared(cfg);
    clock.destroy_for_testing();
    sc.end();
}

#[test]
#[expected_failure(abort_code = E_AUTH_EXPIRED, location = auth)]
fun test_buy_expired_fails() {
    let mut sc = setup();
    let mut clock = clock::create_for_testing(sc.ctx());
    clock.set_for_testing(EXPIRY + 1);
    sc.next_tx(BUYER);
    let mut cfg = sc.take_shared<Config>();
    let payment = coin::mint_for_testing<SUI>(SELLER_AMOUNT + FEE, sc.ctx());
    buy::buy(&mut cfg, payment, SELLER, SELLER_AMOUNT, FEE, UUID, EXPIRY, BUY_SIG, &clock, sc.ctx());
    ts::return_shared(cfg);
    clock.destroy_for_testing();
    sc.end();
}

// === admin settle ===

#[test]
fun test_admin_settle_to_seller_with_fee() {
    let mut sc = setup();
    let clock = clock::create_for_testing(sc.ctx());
    create_offer(&mut sc, &clock);

    sc.next_tx(BACKEND);
    {
        let mut cfg = sc.take_shared<Config>();
        let off = sc.take_shared<Offer>();
        offer::admin_settle_offer(&mut cfg, off, true, FEE, &clock, sc.ctx());
        ts::return_shared(cfg);
    };
    assert_received(&mut sc, SELLER, AMOUNT - FEE);

    clock.destroy_for_testing();
    sc.end();
}

#[test]
fun test_admin_settle_to_seller_no_fee() {
    let mut sc = setup();
    let clock = clock::create_for_testing(sc.ctx());
    create_offer(&mut sc, &clock);

    sc.next_tx(BACKEND);
    {
        let mut cfg = sc.take_shared<Config>();
        let off = sc.take_shared<Offer>();
        offer::admin_settle_offer(&mut cfg, off, true, 0, &clock, sc.ctx());
        ts::return_shared(cfg);
    };
    assert_received(&mut sc, SELLER, AMOUNT);

    clock.destroy_for_testing();
    sc.end();
}

#[test]
fun test_admin_settle_refund() {
    let mut sc = setup();
    let clock = clock::create_for_testing(sc.ctx());
    create_offer(&mut sc, &clock);

    sc.next_tx(BACKEND);
    {
        let mut cfg = sc.take_shared<Config>();
        let off = sc.take_shared<Offer>();
        offer::admin_settle_offer(&mut cfg, off, false, 0, &clock, sc.ctx());
        ts::return_shared(cfg);
    };
    assert_received(&mut sc, BUYER, AMOUNT);

    clock.destroy_for_testing();
    sc.end();
}

#[test]
#[expected_failure(abort_code = E_OFFER_AMOUNT, location = offer)]
fun test_admin_settle_refund_with_fee_fails() {
    let mut sc = setup();
    let clock = clock::create_for_testing(sc.ctx());
    create_offer(&mut sc, &clock);

    sc.next_tx(BACKEND);
    let mut cfg = sc.take_shared<Config>();
    let off = sc.take_shared<Offer>();
    offer::admin_settle_offer(&mut cfg, off, false, FEE, &clock, sc.ctx());
    ts::return_shared(cfg);

    clock.destroy_for_testing();
    sc.end();
}

#[test]
#[expected_failure(abort_code = E_OFFER_AMOUNT, location = offer)]
fun test_admin_settle_fee_exceeds_amount_fails() {
    let mut sc = setup();
    let clock = clock::create_for_testing(sc.ctx());
    create_offer(&mut sc, &clock);

    sc.next_tx(BACKEND);
    let mut cfg = sc.take_shared<Config>();
    let off = sc.take_shared<Offer>();
    offer::admin_settle_offer(&mut cfg, off, true, AMOUNT + 1, &clock, sc.ctx());
    ts::return_shared(cfg);

    clock.destroy_for_testing();
    sc.end();
}

#[test]
#[expected_failure(abort_code = E_OFFER_UNAUTH, location = offer)]
fun test_admin_settle_wrong_caller_fails() {
    let mut sc = setup();
    let clock = clock::create_for_testing(sc.ctx());
    create_offer(&mut sc, &clock);

    sc.next_tx(BUYER);
    let mut cfg = sc.take_shared<Config>();
    let off = sc.take_shared<Offer>();
    offer::admin_settle_offer(&mut cfg, off, true, FEE, &clock, sc.ctx());
    ts::return_shared(cfg);

    clock.destroy_for_testing();
    sc.end();
}

// === seller accept / cancel (event-only) ===

#[test]
fun test_seller_accept_and_cancel() {
    let mut sc = setup();
    sc.next_tx(SELLER);
    let clock = clock::create_for_testing(sc.ctx());
    {
        let cfg = sc.take_shared<Config>();
        offer::seller_accept_offer(&cfg, UUID, EXPIRY, SELLER_SIG, &clock, sc.ctx());
        offer::seller_cancel_offer(&cfg, UUID, EXPIRY, SELLER_SIG, &clock, sc.ctx());
        ts::return_shared(cfg);
    };
    clock.destroy_for_testing();
    sc.end();
}

#[test]
#[expected_failure(abort_code = E_AUTH_SIG, location = auth)]
fun test_seller_accept_wrong_signature_fails() {
    let mut sc = setup();
    sc.next_tx(SELLER);
    let clock = clock::create_for_testing(sc.ctx());
    let cfg = sc.take_shared<Config>();
    offer::seller_accept_offer(&cfg, UUID, EXPIRY, OFFER_SIG, &clock, sc.ctx());
    ts::return_shared(cfg);
    clock.destroy_for_testing();
    sc.end();
}

#[test]
#[expected_failure(abort_code = E_AUTH_SIG, location = auth)]
fun test_seller_auth_wrong_sender_fails() {
    let mut sc = setup();
    // Signature is over SELLER, but BUYER submits → derived msg mismatches.
    sc.next_tx(BUYER);
    let clock = clock::create_for_testing(sc.ctx());
    let cfg = sc.take_shared<Config>();
    offer::seller_cancel_offer(&cfg, UUID, EXPIRY, SELLER_SIG, &clock, sc.ctx());
    ts::return_shared(cfg);
    clock.destroy_for_testing();
    sc.end();
}

#[test]
#[expected_failure(abort_code = E_AUTH_EXPIRED, location = auth)]
fun test_seller_auth_expired_fails() {
    let mut sc = setup();
    sc.next_tx(SELLER);
    let mut clock = clock::create_for_testing(sc.ctx());
    clock.set_for_testing(EXPIRY + 1);
    let cfg = sc.take_shared<Config>();
    offer::seller_cancel_offer(&cfg, UUID, EXPIRY, SELLER_SIG, &clock, sc.ctx());
    ts::return_shared(cfg);
    clock.destroy_for_testing();
    sc.end();
}
