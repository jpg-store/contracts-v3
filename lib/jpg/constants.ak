use aiken/transaction/credential.{Address, Inline, ScriptCredential}
use jpg/types.{ScriptHash, VerificationKeyHash}

pub const marketplace_stake_sh: ScriptHash =
  #"2c967f4bd28944b06462e13c5e3f5d5fa6e03f8567569438cd833e6d"

pub const marketplace_sh: ScriptHash =
  #"84cc25ea4c29951d40b443b95bbc5676bc425470f96376d1984af9ab"

pub fn marketplace_addr() -> Address {
  Address {
    payment_credential: ScriptCredential(marketplace_sh),
    stake_credential: Some(Inline(ScriptCredential(marketplace_stake_sh))),
  }
}

pub fn authorizers() -> List<VerificationKeyHash> {
  [
    #"15df89fe62968415bac4de9d8576da39c34db4717f46332572aca3eb",
    #"53391ebae9fa352a1108e2769df9baf0d3efcab0f49404bd6ac56bd4",
  ]
}

pub const marketplace_pct: Int = 20

pub const min_payout: Int = 1000000
