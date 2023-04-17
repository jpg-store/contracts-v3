use aiken/transaction.{ScriptContext}
use aiken/transaction/value.{PolicyId}
use marketplace/types.{VerificationKeyHash}

type Trait {
}

type Datum {
  CollectionOffer(PolicyId, Option<Trait>)
  AssetOffer

  BidPool(VerificationKeyHash)
}

validator {
  fn spend(datum: Datum, redeemer: Data, ctx: ScriptContext) -> Bool {

    

    todo
  }

  fn mint(redeemer: Data, ctx: ScriptContext) -> Bool {
    todo
    // - Token can only go to the script
    // - 
  }
}
