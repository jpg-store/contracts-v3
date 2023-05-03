use aiken/builtin.{blake2b_256, serialise_data}
use aiken/cbor.{serialise}
use aiken/transaction.{DatumHash,
  InlineDatum, ScriptContext, Spend, Transaction}
use jpg/types.{Payout, VerificationKeyHash}
use jpg/utils.{hex_encode, is_signed_by, reduce_over_tagged_outputs}

type Datum {
  private_buyer: Option<VerificationKeyHash>,
  payouts: List<Payout>,
  owner: VerificationKeyHash,
}

type Redeemer {
  Buy
  CancelOrUpdate
}

validator {
  fn spend(datum: Datum, redeemer: Redeemer, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction, purpose } =
      ctx

    let Transaction { outputs, extra_signatories, .. } =
      transaction

    when redeemer is {
      Buy -> {
        expect Spend(out_ref) =
          purpose

        let tag_datum =
          out_ref |> InlineDatum

        let Datum { private_buyer, payouts, .. } =
          datum

        let is_correct_private_buyer =
          when private_buyer is {
            Some(private_buyer) ->
              is_signed_by(extra_signatories, private_buyer)
            None ->
              True
          }

        reduce_over_tagged_outputs(outputs, payouts, tag_datum) && is_correct_private_buyer
      }

      CancelOrUpdate ->
        is_signed_by(extra_signatories, datum.owner)
    }
  }
}
