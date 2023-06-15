use aiken/transaction/credential.{Address, Inline, VerificationKeyCredential}
use jpg/types.{VerificationKeyHash}

pub const marketplace_stake_vkh: VerificationKeyHash =
  #"81728e7ed4cf324e1323135e7e6d931f01e30792d9cdf17129cb806d"

pub const marketplace_vkh: VerificationKeyHash =
  #"70e60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a72"

pub fn marketplace_addr() -> Address {
  Address {
    payment_credential: VerificationKeyCredential(marketplace_vkh),
    stake_credential: Some(
      Inline(VerificationKeyCredential(marketplace_stake_vkh)),
    ),
  }
}

pub const marketplace_pct: Int = 20

pub const min_payout: Int = 1000000
