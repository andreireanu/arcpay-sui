module arcpay::constants;

const VERSION: u64 = 1;
const BACKEND_PUBKEY_LENGTH: u64 = 32;
const UUID_LENGTH: u64 = 16;

const EUnauthorized: u64 = 0;
const EIncorrectVersion: u64 = 1;
const ENotUpgraded: u64 = 2;
const EInvalidBackendPubkey: u64 = 3;
const EAuthorizationExpired: u64 = 4;
const EInvalidAuthorizationSignature: u64 = 5;
const EInvalidPayment: u64 = 6;
const EInvalidUuid: u64 = 7;

public(package) fun get_VERSION(): u64 { VERSION }
public(package) fun get_BACKEND_PUBKEY_LENGTH(): u64 { BACKEND_PUBKEY_LENGTH }
public(package) fun get_UUID_LENGTH(): u64 { UUID_LENGTH }

public(package) fun get_EUnauthorized(): u64 { EUnauthorized }
public(package) fun get_EIncorrectVersion(): u64 { EIncorrectVersion }
public(package) fun get_ENotUpgraded(): u64 { ENotUpgraded }
public(package) fun get_EInvalidBackendPubkey(): u64 { EInvalidBackendPubkey }
public(package) fun get_EAuthorizationExpired(): u64 { EAuthorizationExpired }
public(package) fun get_EInvalidAuthorizationSignature(): u64 { EInvalidAuthorizationSignature }
public(package) fun get_EInvalidPayment(): u64 { EInvalidPayment }
public(package) fun get_EInvalidUuid(): u64 { EInvalidUuid }
