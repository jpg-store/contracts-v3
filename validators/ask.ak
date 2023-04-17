use aiken/list
use aiken/transaction.{ScriptContext}
use marketplace/constants.{marketplace_pct, marketplace_vkh}
use marketplace/types.{RoyaltyReceiver, VerificationKeyHash}
use marketplace/utils.{is_correct_split, must_be_signed_by}

type Datum {
  price: Int,
  owner: VerificationKeyHash,
  is_private_listing: Option<VerificationKeyHash>,
  royalty_receivers: Option<List<RoyaltyReceiver>>,
}

type Redeemer {
  Buy
  CancelOrUpdate
}

// TODO: Fix double satisfaction
validator {
  fn spend(datum: Datum, redeemer: Redeemer, ctx: ScriptContext) -> Bool {
    let tx =
      ctx.transaction

    when redeemer is {
      Buy -> {
        let marketplace_receiver =
          RoyaltyReceiver {
            owner: marketplace_vkh,
            percentage_thousands: marketplace_pct,
          }

        let all_receivers =
          when datum.royalty_receivers is {
            Some(receivers) ->
              list.concat([marketplace_receiver], receivers)
            None ->
              [marketplace_receiver]
          }

        is_correct_split(datum.price, all_receivers, datum.owner, tx.outputs, 0)
      }

      CancelOrUpdate ->
        must_be_signed_by(tx, datum.owner)
    }
  }
}
