// Generates fixed ed25519 test vectors for the arcpay Move tests.
//
// @noble isn't installed in arcpay-sui, so run this from a dir that has it,
// e.g.:  cp tests/gen_vectors.mjs ../arcpay-solana/ && node ../arcpay-solana/gen_vectors.mjs
//
// Message layouts (little-endian), matching sources/auth.move:
//   verify_offer  (96):  buyer(32) seller(32) uuid(16) amount(8) expiry(8)
//   verify_buy   (104):  buyer(32) seller(32) offer_id(16) seller_amount(8) fee(8) expiry(8)
//   verify_seller (56):  seller(32) offer_id(16) expiry(8)
// backend address = blake2b256(0x00 || pubkey)  (config.move)

import { ed25519 } from '@noble/curves/ed25519';
import { blake2b } from '@noble/hashes/blake2b';

const SEED = new Uint8Array(32).fill(7); // fixed backend key seed
const pubkey = ed25519.getPublicKey(SEED);

// fixed 32-byte addresses (right-aligned, matching Sui @0x... encoding)
const addr = (hex) => {
  const b = new Uint8Array(32);
  const h = hex.padStart(64, '0');
  for (let i = 0; i < 32; i++) b[i] = parseInt(h.slice(i * 2, i * 2 + 2), 16);
  return b;
};
const BUYER = addr('cafe');
const SELLER = addr('beef');
const UUID = new Uint8Array(16).fill(0xab);

const AMOUNT = 1000n;
const SELLER_AMOUNT = 900n;
const FEE = 100n;
const EXPIRY = 9_000_000_000_000n;

const u64le = (n) => {
  const b = new Uint8Array(8);
  let v = n;
  for (let i = 0; i < 8; i++) { b[i] = Number(v & 0xffn); v >>= 8n; }
  return b;
};
const cat = (...arrs) => {
  const total = arrs.reduce((s, a) => s + a.length, 0);
  const out = new Uint8Array(total);
  let o = 0;
  for (const a of arrs) { out.set(a, o); o += a.length; }
  return out;
};
const hex = (b) => Buffer.from(b).toString('hex');
const sign = (msg) => ed25519.sign(msg, SEED);

const offerMsg = cat(BUYER, SELLER, UUID, u64le(AMOUNT), u64le(EXPIRY));
const buyMsg = cat(BUYER, SELLER, UUID, u64le(SELLER_AMOUNT), u64le(FEE), u64le(EXPIRY));
const buyNoFeeMsg = cat(BUYER, SELLER, UUID, u64le(AMOUNT), u64le(0n), u64le(EXPIRY));
const sellerMsg = cat(SELLER, UUID, u64le(EXPIRY));

const backendAddr = blake2b(cat(new Uint8Array([0]), pubkey), { dkLen: 32 });

console.log(`BACKEND_PUBKEY  x"${hex(pubkey)}"`);
console.log(`BACKEND_ADDRESS @0x${hex(backendAddr)}`);
console.log(`BUYER           @0x${hex(BUYER)}`);
console.log(`SELLER          @0x${hex(SELLER)}`);
console.log(`UUID            x"${hex(UUID)}"`);
console.log(`AMOUNT          ${AMOUNT}`);
console.log(`SELLER_AMOUNT   ${SELLER_AMOUNT}`);
console.log(`FEE             ${FEE}`);
console.log(`EXPIRY          ${EXPIRY}`);
console.log(`OFFER_SIG       x"${hex(sign(offerMsg))}"`);
console.log(`BUY_SIG         x"${hex(sign(buyMsg))}"`);
console.log(`BUY_NOFEE_SIG   x"${hex(sign(buyNoFeeMsg))}"`);
console.log(`SELLER_SIG      x"${hex(sign(sellerMsg))}"`);
