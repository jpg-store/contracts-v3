use aiken/builtin.{blake2b_256, serialise_data}
use aiken/transaction.{DatumHash, ScriptContext, Spend, Transaction}
use jpg/types.{Payout, VerificationKeyHash}
use jpg/utils.{is_signed_by, reduce_over_tagged_outputs}

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

        let tag_hash =
          DatumHash(out_ref |> serialise_data |> blake2b_256)

        let Datum { private_buyer, payouts, .. } =
          datum

        let is_correct_private_buyer =
          when private_buyer is {
            Some(private_buyer) ->
              is_signed_by(extra_signatories, private_buyer)
            None ->
              True
          }

        expect [first_output, ..rest_outputs] =
          outputs

        reduce_over_tagged_outputs(
          first_output,
          rest_outputs,
          payouts,
          tag_hash,
        ) && is_correct_private_buyer
      }

      CancelOrUpdate ->
        is_signed_by(extra_signatories, datum.owner)
    }
  }
}
