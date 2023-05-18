use aiken/builtin.{tail_list}
use aiken/dict
use aiken/list
use aiken/transaction.{Datum, DatumHash, Output, OutputReference, TransactionId}
use aiken/transaction/credential.{Address, VerificationKeyCredential}
use aiken/transaction/value.{to_list_advanced_usage}
use jpg/constants.{marketplace_addr}
use jpg/types.{Payout}

/// Find the outputs that match the list of payouts.
/// We use a heuristic function combined with the given 
/// redeemer offset to jump 10 at a time towards first output to validate.
/// This saves a massive amount in budget allowing us to support 40+ inputs.
/// If the wrong offset is given then the script will fail or cost more.
/// The resulting `Output` list may contain more outputs than payouts. But
/// we expect the transaction to NOT have alternating payout outputs and random
/// outputs. This means you cannot construct transactions that have outputs
/// like this: `[payout, random, payout]`. An example of a valid set of outputs
/// would be: `[random, payout, payout, random]`.
/// This is pretty much `list.drop` but optimized for our situation.
pub fn find_payout_outputs(
  outputs: List<a>,
  payout_outputs_offset: Int,
) -> List<a> {
  if payout_outputs_offset >= 10 {
    outputs
      |> skip_10_items
      |> find_payout_outputs(payout_outputs_offset - 10)
  } else {
    do_find_payout_outputs(outputs, payout_outputs_offset)
  }
}

fn do_find_payout_outputs(outputs: List<a>, current_index: Int) -> List<a> {
  if current_index == 0 {
    outputs
  } else {
    outputs
      |> tail_list
      |> do_find_payout_outputs(current_index - 1)
  }
}

test find_payout_outputs_1() {
  find_payout_outputs([1, 2, 3, 4], 2) == [3, 4]
}

test find_payout_outputs_2() {
  find_payout_outputs([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], 10) == [11]
}

/// Small utility to skip 10 items in a list.
/// Used by `find_payout_outputs`.
fn skip_10_items(some_list: List<a>) -> List<a> {
  some_list
    |> tail_list
    |> tail_list
    |> tail_list
    |> tail_list
    |> tail_list
    |> tail_list
    |> tail_list
    |> tail_list
    |> tail_list
    |> tail_list
}

test skip_10_items_1() {
  skip_10_items([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) == [11]
}

/// This function is used only if `marketplace_fee`
/// is greater than `0`. The main different from
/// `check_payouts` is that we make sure the
/// output address matches a hardcoded marketplace address
/// along with confirming that the output value equals
/// the marketplace_fee. In this case there is no `Payout`
/// to compare to.
pub fn check_marketplace_payout(
  output: Output,
  marketplace_fee: Int,
  datum_tag: Datum,
) -> Bool {
  let Output { address: output_address, value, datum, .. } =
    output

  let datum_check =
    datum == datum_tag

  // Match hardcoded marketplace address
  let address_check =
    output_address == marketplace_addr()

  expect [(policy, tokens)] =
    to_list_advanced_usage(value)

  expect [(_, quantity)] =
    dict.to_list(tokens)

  let policy_check =
    policy == ""

  // Output value quantity must equal the marketplace fee
  // this prevents people from not paying a fee by submitting
  // transactions not constructed by Jpg.
  let quantity_check =
    quantity >= marketplace_fee

  datum_check && address_check && quantity_check && policy_check
}

test check_marketplace_payout_1() {
  let datum_tag =
    OutputReference {
      transaction_id: TransactionId { hash: #"00" },
      output_index: 0,
    }
      |> builtin.serialise_data
      |> builtin.blake2b_256
      |> DatumHash

  let output =
    Output {
      address: marketplace_addr(),
      value: value.from_lovelace(2000000),
      datum: datum_tag,
      reference_script: None,
    }

  check_marketplace_payout(output, 2000000, datum_tag)
}

/// Check that payouts and payout outputs
/// are correct. Payouts are stored in the datum
/// when assets are listed. On buy a transaction
/// with matching payout outputs needs to be constructed.
/// We also require that outputs are in the same order as the
/// payouts in the datum.
pub fn check_payouts(
  outputs: List<Output>,
  payouts: List<Payout>,
  datum_tag: Datum,
) -> Bool {
  expect [first_output, ..rest_outputs] =
    outputs

  let Output { address: output_address, value, datum, .. } =
    first_output

  if datum == datum_tag {
    expect [payout, ..rest_payouts] =
      payouts

    let Payout { address: payout_address, amount_lovelace } =
      payout

    // The `Output` address must match
    // the address specified in the corresponding
    // payout from the datum.
    let address_check =
      payout_address == output_address

    expect [(policy, tokens)] =
      to_list_advanced_usage(value)

    expect [(_, quantity)] =
      dict.to_list(tokens)

    let policy_check =
      policy == ""

    // The quantity in the output must equal
    // the amount specified in the corresponding
    // payout from the datum.
    let quantity_check =
      quantity >= amount_lovelace

    let rest_outputs_check =
      when rest_payouts is {
        // the base case
        [] ->
          // if rest is empty we are done
          True
        _ ->
          // continue with remaining outputs and payouts
          check_payouts(rest_outputs, rest_payouts, datum_tag)
      }

    address_check && policy_check && quantity_check && rest_outputs_check
  } else {
    False
  }
}

test check_payouts_1() {
  let test_royalty_addr =
    Address {
      payment_credential: VerificationKeyCredential(
        #"80f60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a81",
      ),
      stake_credential: None,
    }

  let test_seller_addr =
    Address {
      payment_credential: VerificationKeyCredential(
        #"90f60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a81",
      ),
      stake_credential: None,
    }

  let test_random_addr =
    Address {
      payment_credential: VerificationKeyCredential(
        #"fff60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a81",
      ),
      stake_credential: None,
    }

  let test_royalty_payouts =
    [
      Payout { address: test_royalty_addr, amount_lovelace: 3000000 },
      Payout { address: test_seller_addr, amount_lovelace: 95000000 },
    ]

  let datum_tag =
    OutputReference {
      transaction_id: TransactionId { hash: #"00" },
      output_index: 0,
    }
      |> builtin.serialise_data
      |> builtin.blake2b_256
      |> DatumHash

  // 5% royalties
  let out_1 =
    Output {
      address: test_royalty_addr,
      value: value.from_lovelace(3000000),
      datum: datum_tag,
      reference_script: None,
    }

  let out_2 =
    Output {
      address: test_seller_addr,
      value: value.from_lovelace(95000000),
      datum: datum_tag,
      reference_script: None,
    }

  let out_random =
    Output {
      address: test_random_addr,
      value: value.from_lovelace(1000000),
      datum: datum_tag,
      reference_script: None,
    }

  let outputs =
    list.concat([out_1, out_2], list.repeat(out_random, 100))

  check_payouts(outputs, test_royalty_payouts, datum_tag)
}
