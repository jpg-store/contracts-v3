import * as colors from "https://deno.land/std@0.184.0/fmt/colors.ts";
import * as cbor from "https://deno.land/x/cbor@v1.4.1/index.js";
import {
  fromHex,
  SpendingValidator,
  toHex,
  TxSigned,
} from "https://deno.land/x/lucid@0.10.1/mod.ts";

import blueprint from "../plutus.json" assert { type: "json" };

const MAX_TX_EX_STEPS = 10000000000;
const MAX_TX_EX_MEM = 14000000;
const MAX_TX_SIZE = 16384;

export function readValidator(): SpendingValidator {
  const validator = blueprint.validators[0];

  return {
    type: "PlutusV2",
    script: toHex(cbor.encode(fromHex(validator.compiledCode))),
  };
}

export function printExecutionDetails(tx: TxSigned, name: string) {
  const redeemers = tx.txSigned.witness_set().redeemers()!;
  let steps = 0;
  let mem = 0;

  for (let i = 0; i < redeemers.len(); i++) {
    const red = redeemers.get(i);
    steps += parseInt(red.ex_units().steps().to_str(), 10);
    mem += parseInt(red.ex_units().mem().to_str(), 10);
  }

  const remainingMem = MAX_TX_EX_MEM - mem;
  const remainingSteps = MAX_TX_EX_STEPS - steps;
  const txBytes = tx.txSigned.to_bytes().length;
  const remainingTxBytes = MAX_TX_SIZE - txBytes;
  const fee = tx.txSigned.body().fee().to_str();

  const text = `
  ${colors.bold(colors.brightMagenta(name))} - ${colors.green("passed")}
  
    ${colors.bold(colors.blue("mem"))}:       ${
    colors.brightGreen(mem.toString())
  }
    ${colors.bold(colors.blue("remaining"))}: ${
    colors.brightCyan(remainingMem.toString())
  }
    
    ${colors.bold(colors.blue("cpu"))}:       ${
    colors.brightGreen(steps.toString())
  }
    ${colors.bold(colors.blue("remaining"))}: ${
    colors.brightCyan(remainingSteps.toString())
  }
    
    ${colors.bold(colors.blue("tx size"))}:   ${
    colors.brightGreen(txBytes.toString())
  }
    ${colors.bold(colors.blue("remaining"))}: ${
    colors.brightCyan(remainingTxBytes.toString())
  }
    
    ${colors.bold(colors.blue("fee"))}: ${
    colors.brightGreen(fee.toUpperCase())
  }`;

  console.log(text);

  if (remainingMem < 0) {
    console.log(colors.red("  Out of mem"));
  }

  if (remainingSteps < 0) {
    console.log(colors.red("  Out of cpu"));
  }

  if (remainingTxBytes < 0) {
    console.log(colors.red("  Out of tx space"));
  }
}

export function randomAssetId() {
  const bytes = new Uint8Array(48);
  crypto.getRandomValues(bytes);
  return toHex(bytes);
}
