use aiken/transaction/credential.{Address, Inline, VerificationKeyCredential}
use jpg/types.{VerificationKeyHash}

pub const marketplace_stake_vkh: VerificationKeyHash =
  #"1e78aae7c90cc36d624f7b3bb6d86b52696dc84e490f343eba89005f"

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

pub fn authorizers() -> List<VerificationKeyHash> {
  []
}

pub const marketplace_pct: Int = 20

pub const min_payout: Int = 1000000
