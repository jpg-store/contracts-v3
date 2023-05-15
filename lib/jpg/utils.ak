use aiken/builtin.{tail_list}
use aiken/dict
use aiken/transaction.{Datum, Output}
use aiken/transaction/value.{to_list_advanced_usage}
use jpg/constants.{marketplace_vkh}
use jpg/types.{Payout}

pub fn find_payout_outputs(
  outputs: List<Output>,
  leading_output_index: Int,
) -> List<Output> {
  if leading_output_index >= 10 {
    outputs
      |> skip_10_items
      |> find_payout_outputs(leading_output_index - 10)
  } else {
    do_find_payout_outputs(outputs, leading_output_index)
  }
}

fn do_find_payout_outputs(
  outputs: List<Output>,
  current_index: Int,
) -> List<Output> {
  if current_index == 0 {
    outputs
  } else {
    outputs
      |> tail_list
      |> do_find_payout_outputs(current_index - 1)
  }
}

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

    // I'd recommend keeping stake key info too
    let address_check =
      payout_address == output_address

    expect [(policy, tokens)] =
      to_list_advanced_usage(value)

    expect [(_, quantity)] =
      dict.to_list(tokens)

    let policy_check =
      policy == ""

    let quantity_check =
      quantity >= amount_lovelace

    let rest_outputs_check =
      when rest_payouts is {
        [] ->
          True
        _ ->
          check_payouts(rest_outputs, rest_payouts, datum_tag)
      }

    address_check && policy_check && quantity_check && rest_outputs_check
  } else {
    check_payouts(rest_outputs, payouts, datum_tag)
  }
}
// test is_correct_split_1() {
//   let test_royalty_vkh =
//     #"80f60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a81"
//   let test_seller_vkh =
//     #"90f60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a81"

//   let test_royalty_payouts =
//     [
//       Payout { vkh: test_royalty_vkh, amount_lovelace: 3000000 },
//       Payout { vkh: test_seller_vkh, amount_lovelace: 95000000 },
//       Payout { vkh: marketplace_vkh, amount_lovelace: 2000000 },
//     ]

//   let tag_datum =
//     TagDatum {
//       output_reference: OutputReference {
//         transaction_id: TransactionId { hash: #"00" },
//         output_index: 0,
//       },
//     }

//   // 5% royalties 
//   let marketplace_addr =
//     Address {
//       payment_credential: VerificationKeyCredential(marketplace_vkh),
//       stake_credential: None,
//     }

//   let royalty_addr =
//     Address {
//       payment_credential: VerificationKeyCredential(test_royalty_vkh),
//       stake_credential: None,
//     }

//   let seller_addr =
//     Address {
//       payment_credential: VerificationKeyCredential(test_seller_vkh),
//       stake_credential: None,
//     }

//   let out_1 =
//     Output {
//       address: royalty_addr,
//       value: value.from_lovelace(3000000),
//       datum: InlineDatum(tag_datum),
//       reference_script: None,
//     }

//   let out_2 =
//     Output {
//       address: marketplace_addr,
//       value: value.from_lovelace(2000000),
//       datum: InlineDatum(tag_datum),
//       reference_script: None,
//     }

//   let out_3 =
//     Output {
//       address: seller_addr,
//       value: value.from_lovelace(95000000),
//       datum: InlineDatum(tag_datum),
//       reference_script: None,
//     }

//   let outputs =
//     [out_1, out_2, out_3]

//   is_correct_split(test_royalty_payouts, outputs, tag_datum) == // calculate_marketplace_payout(test_royalty_payouts),
//   // False,
//   True
// }

// test is_correct_split_scaling() {
//   let test_royalty_vkh =
//     #"80f60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a81"
//   let test_seller_vkh =
//     #"90f60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a81"
//   let test_random_vkh =
//     #"fff60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a81"

//   let payouts =
//     [
//       Payout { vkh: test_royalty_vkh, amount_lovelace: 5000000 },
//       Payout { vkh: test_seller_vkh, amount_lovelace: 93000000 },
//     ]

//   let marketplace_payout =
//     Payout { vkh: marketplace_vkh, amount_lovelace: 2000000 }

//   let tag_datum =
//     TagDatum {
//       output_reference: OutputReference {
//         transaction_id: TransactionId { hash: #"00" },
//         output_index: 0,
//       },
//     }

//   let marketplace_addr =
//     Address {
//       payment_credential: VerificationKeyCredential(marketplace_vkh),
//       stake_credential: None,
//     }

//   let royalty_addr =
//     Address {
//       payment_credential: VerificationKeyCredential(test_royalty_vkh),
//       stake_credential: None,
//     }

//   let seller_addr =
//     Address {
//       payment_credential: VerificationKeyCredential(test_seller_vkh),
//       stake_credential: None,
//     }

//   let random_addr =
//     Address {
//       payment_credential: VerificationKeyCredential(test_random_vkh),
//       stake_credential: None,
//     }

//   let out_1 =
//     Output {
//       address: royalty_addr,
//       value: value.from_lovelace(5000000),
//       datum: InlineDatum(tag_datum),
//       reference_script: None,
//     }

//   let out_2 =
//     Output {
//       address: marketplace_addr,
//       value: value.from_lovelace(2000000),
//       datum: InlineDatum(tag_datum),
//       reference_script: None,
//     }

//   let out_3 =
//     Output {
//       address: seller_addr,
//       value: value.from_lovelace(93000000),
//       datum: InlineDatum(tag_datum),
//       reference_script: None,
//     }

//   let out_random =
//     Output {
//       address: random_addr,
//       value: value.from_lovelace(1000000),
//       datum: InlineDatum(tag_datum),
//       reference_script: None,
//     }

//   let outputs =
//     list.concat([out_1, out_2, out_3], list.repeat(out_random, 100))

//   let all_payouts =
//     list.push(payouts, marketplace_payout)

//   is_correct_split(all_payouts, outputs, tag_datum) == True
// }
