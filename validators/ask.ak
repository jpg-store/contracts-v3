use aiken/list
use aiken/transaction.{ScriptContext}

use marketplace/constants.{marketplace_vkh}
use marketplace/types.{Payout, TagDatum, VerificationKeyHash}
use marketplace/utils.{
  calculate_marketplace_payout, get_own_input, is_correct_split, is_signed_by,
}

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
    let tx =
      ctx.transaction
    let own_input =
      get_own_input(ctx)
    let tag_datum =
      TagDatum { output_reference: own_input.output_reference }

    when redeemer is {
      Buy -> {
        let marketplace_payout =
          Payout {
            vkh: marketplace_vkh,
            amount_lovelace: calculate_marketplace_payout(
              datum.payouts,
              datum.owner,
            ),
          }

        let all_payouts =
          list.push(datum.payouts, marketplace_payout)

        let correct_private_buyer =
          when datum.private_buyer is {
            Some(private_buyer) ->
              is_signed_by(tx, private_buyer)
            None ->
              True
          }

        is_correct_split(all_payouts, tx.outputs, tag_datum, 0) && correct_private_buyer
      }

      CancelOrUpdate ->
        is_signed_by(tx, datum.owner)
    }
  }
}
