
use aiken/transaction.{ScriptContext}
use aiken/transaction/value.{PolicyId}

use marketplace/types.{VerificationKeyHash}

type Trait {}

type Datum {
    CollectionOffer(PolicyId, Option<Trait>)
    AssetOffer()

    BidPool(VerificationKeyHash)
}

type Redeemer {}

validator {

    fn spend(datum: Datum, redeemer: Redeemer, ctx: ScriptContext) -> Bool {

    }

    fn mint(_, ctx: ScriptContext) -> Bool {
        // - Token can only go to the script
        // - 
    }
}