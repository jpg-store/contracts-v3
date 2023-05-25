use aiken/transaction/credential.{Address, VerificationKeyCredential}
use jpg/types.{VerificationKeyHash}

pub const marketplace_vkh: VerificationKeyHash =
  #"70e60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a72"

pub fn marketplace_addr() -> Address {
  Address {
    payment_credential: VerificationKeyCredential(marketplace_vkh),
    stake_credential: None,
  }
}

pub const marketplace_pct: Int = 20

pub const min_payout: Int = 1000000
