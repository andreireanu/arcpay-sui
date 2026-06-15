module arcpay::constants;

const VERSION: u64 = 1;
const ED25519_FLAG: u8 = 0;
const UUID_LENGTH: u64 = 16;
const ED25519_PUBKEY_LENGTH: u64 = 32;

const EUnauthorized: u64 = 0;
const EAuthorizationExpired: u64 = 1;
const EInvalidAuthorizationSignature: u64 = 2;
const EInsufficientCommissionBalance: u64 = 3;
const EInvalidAmount: u64 = 4;
const EInvalidPayment: u64 = 5;
const EInvalidUuid: u64 = 6;
const EInvalidBackendPubkey: u64 = 7;
const EIncorrectVersion: u64 = 8;
const ENotUpgrade: u64 = 9;

public(package) fun get_VERSION(): u64 { VERSION }
public(package) fun get_ED25519_FLAG(): u8 { ED25519_FLAG }
public(package) fun get_UUID_LENGTH(): u64 { UUID_LENGTH }
public(package) fun get_ED25519_PUBKEY_LENGTH(): u64 { ED25519_PUBKEY_LENGTH }

public(package) fun get_EUnauthorized(): u64 { EUnauthorized }
public(package) fun get_EAuthorizationExpired(): u64 { EAuthorizationExpired }
public(package) fun get_EInvalidAuthorizationSignature(): u64 { EInvalidAuthorizationSignature }
public(package) fun get_EInsufficientCommissionBalance(): u64 { EInsufficientCommissionBalance }
public(package) fun get_EInvalidAmount(): u64 { EInvalidAmount }
public(package) fun get_EInvalidPayment(): u64 { EInvalidPayment }
public(package) fun get_EInvalidUuid(): u64 { EInvalidUuid }
public(package) fun get_EInvalidBackendPubkey(): u64 { EInvalidBackendPubkey }
public(package) fun get_EIncorrectVersion(): u64 { EIncorrectVersion }
public(package) fun get_ENotUpgrade(): u64 { ENotUpgrade }
