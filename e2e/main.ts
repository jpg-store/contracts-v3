import "https://deno.land/std@0.184.0/dotenv/load.ts";
import * as colors from "https://deno.land/std@0.184.0/fmt/colors.ts";
import {
  Assets,
  Blockfrost,
  C,
  Constr,
  Data,
  Emulator,
  fromHex,
  generatePrivateKey,
  getAddressDetails,
  Lucid,
  PROTOCOL_PARAMETERS_DEFAULT,
  SpendingValidator,
  toHex,
  TxSigned,
} from "https://deno.land/x/lucid@0.10.1/mod.ts";
import * as cbor from "https://deno.land/x/cbor@v1.4.1/index.js";

import blueprint from "../plutus.json" assert { type: "json" };

const validator = readValidator();

const sellerPk = generatePrivateKey();
const refPk = generatePrivateKey();
const buyerPk = generatePrivateKey();
const royaltyPk = generatePrivateKey();

const l = await Lucid.new(
  new Blockfrost(
    "https://cardano-preview.blockfrost.io/api/v0",
    Deno.env.get("BLOCKFROST_API_KEY"),
  ),
  "Preview",
);

const myAsset = {
  ["627c22b8a13e0f7dad08ea3cc25ac6f254822acf9ded1b52b8578b413d0acfbf35c28c6346d8de3e27b7ebeab19022a24d9cedb87e08078b03a6dd13"]:
    1n,
};

const BULK_PURCHASE_SIZE = 43;
const MAX_TX_EX_STEPS = 10000000000;
const MAX_TX_EX_MEM = 14000000;
const MAX_TX_SIZE = 16384;

const bulkPurchaseAssets: Assets = new Array(BULK_PURCHASE_SIZE)
  .fill(0)
  .reduce((acc) => {
    acc[randomAssetId()] = 1n;
    return acc;
  }, {});

const sellerAddr = await l
  .selectWalletFromPrivateKey(sellerPk)
  .wallet.address();

const refAddr = await l
  .selectWalletFromPrivateKey(refPk)
  .wallet.address();

const marketplacePkh =
  "70e60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a72";

const marketplaceAddress = C.EnterpriseAddress.new(
  0,
  C.StakeCredential.from_keyhash(C.Ed25519KeyHash.from_hex(marketplacePkh)),
)
  .to_address()
  .to_bech32("addr_test");

const royaltyAddress = await l
  .selectWalletFromPrivateKey(royaltyPk)
  .wallet.address();

const buyerAddress = await l
  .selectWalletFromPrivateKey(buyerPk)
  .wallet.address();

const { paymentCredential } = getAddressDetails(sellerAddr);
const { paymentCredential: royaltyPaymentCred } = getAddressDetails(
  royaltyAddress,
);

const emulator = new Emulator(
  [
    {
      address: sellerAddr,
      assets: { lovelace: BigInt(1e14), ...myAsset, ...bulkPurchaseAssets },
    },
    {
      address: buyerAddress,
      assets: { lovelace: BigInt(1e14) },
    },
    {
      address: refAddr,
      assets: { lovelace: BigInt(1e14) },
    },
  ],
  {
    ...PROTOCOL_PARAMETERS_DEFAULT,
    // maxTxExSteps: BigInt(MAX_TX_EX_STEPS),
  },
);

const lucid = await Lucid.new(emulator);

const contractAddress = lucid.utils.validatorToAddress(validator);

lucid.selectWalletFromPrivateKey(sellerPk);

const price = 5000000n;

const makePayout = (cred: string, amount: bigint) => {
  const address = new Constr(0, [new Constr(0, [cred]), new Constr(1, [])]);

  return new Constr(0, [address, amount]);
};

const datum = Data.to(
  new Constr(0, [
    new Constr(1, []),
    [
      makePayout(paymentCredential?.hash!, price - 2000000n),
      makePayout(royaltyPaymentCred?.hash!, 1000000n),
    ],
    1000000n,
    paymentCredential?.hash!,
  ]),
);

const tx = await lucid
  .newTx()
  .payToContract(contractAddress, { asHash: datum }, myAsset)
  .complete();

const signed = await tx.sign().complete();

await signed.submit();

emulator.awaitBlock(4);

const txRef = await lucid
  .newTx()
  .payToAddressWithData(refAddr, { scriptRef: validator }, {
    lovelace: 100000000n,
  })
  .complete();

const signedRef = await txRef.sign().complete();

await signedRef.submit();

emulator.awaitBlock(16);

const contractUtxos = await lucid.utxosAt(contractAddress);

const refUtxos = await lucid.utxosAt(refAddr);

const tx2 = await lucid
  .newTx()
  .collectFrom(contractUtxos, Data.to(new Constr(1, [])))
  .attachSpendingValidator(validator)
  .addSigner(sellerAddr)
  .complete();

const signed2 = await tx2.sign().complete();

printExecutionDetails(signed2, "Withdraw ask (best case scenario)");

emulator.awaitBlock(8);

lucid.selectWalletFromPrivateKey(buyerPk);

const datumTag = Data.to(
  new Constr(0, [new Constr(0, [tx.toHash()]), BigInt(0)]),
);

const tx3 = await lucid
  .newTx()
  .collectFrom(contractUtxos, Data.to(new Constr(0, [BigInt(0)])))
  .readFrom(refUtxos)
  .payToAddressWithData(
    marketplaceAddress,
    { asHash: datumTag },
    {
      lovelace: 1000000n,
    },
  )
  .payToAddressWithData(
    sellerAddr,
    { asHash: datumTag },
    {
      lovelace: 3000000n,
    },
  )
  .payToAddressWithData(
    royaltyAddress,
    { asHash: datumTag },
    {
      lovelace: 1000000n,
    },
  )
  .addSigner(buyerAddress)
  .complete();

const signed3 = await tx3.sign().complete();

printExecutionDetails(signed3, "Purchase (best case scenario)");

// Simulate a bulk purchase

lucid.selectWalletFromPrivateKey(sellerPk);

let bulkLockTx = lucid.newTx();

// Lock all the assets in different utxos
for (const [unit, qty] of Object.entries(bulkPurchaseAssets)) {
  // 100 ADA each
  const myPrice = 100000000n;

  const datum = Data.to(
    new Constr(0, [
      new Constr(1, []),
      [
        makePayout(paymentCredential?.hash!, myPrice - 4000000n),
        makePayout(royaltyPaymentCred?.hash!, 2000000n),
      ],
      2000000n,
      paymentCredential?.hash!,
    ]),
  );

  bulkLockTx = bulkLockTx.payToContract(
    contractAddress,
    { asHash: datum },
    {
      [unit]: qty,
    },
  );
}

const bulkLockComplete = await bulkLockTx.complete();
const bulkLockSigned = await bulkLockComplete.sign().complete();

await bulkLockSigned.submit();

emulator.awaitBlock(16);

const contractUtxos2 = await lucid.utxosAt(contractAddress);

lucid.selectWalletFromPrivateKey(buyerPk);

let bulkPurchaseTx = contractUtxos2.filter((u) =>
  u.txHash === bulkLockSigned.toHash()
).map((utxo, index) => {
  return lucid
    .newTx()
    .collectFrom(
      [utxo],
      Data.to(new Constr(0, [BigInt(index * 3)])),
    )
    .readFrom(refUtxos)
    .addSigner(buyerAddress);
}).reduce((acc, mappedTx) => {
  return acc.compose(mappedTx);
}, lucid.newTx());

for (let i = 1; i < BULK_PURCHASE_SIZE + 1; i++) {
  const oIndex = contractUtxos2[i].outputIndex;
  const datumTag = Data.to(
    new Constr(0, [new Constr(0, [bulkLockSigned.toHash()]), BigInt(oIndex)]),
  );

  bulkPurchaseTx = bulkPurchaseTx
    .payToAddressWithData(
      marketplaceAddress,
      { asHash: datumTag },
      {
        lovelace: 2000000n,
      },
    )
    .payToAddressWithData(
      sellerAddr,
      { asHash: datumTag },
      {
        lovelace: 96000000n,
      },
    )
    .payToAddressWithData(
      royaltyAddress,
      { asHash: datumTag },
      {
        lovelace: 2000000n,
      },
    );
}

const completed = await bulkPurchaseTx.complete();
const signed4 = await completed.sign().complete();

printExecutionDetails(signed4, "Bulk purchase (worst case scenario)");

// Utiility functions

function readValidator(): SpendingValidator {
  const validator = blueprint.validators[0];

  return {
    type: "PlutusV2",
    script: toHex(cbor.encode(fromHex(validator.compiledCode))),
  };
}

function printExecutionDetails(tx: TxSigned, name: string) {
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
${colors.bold(colors.brightMagenta(name))}

${colors.bold(colors.blue("mem"))}:       ${colors.brightGreen(mem.toString())}
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

${colors.bold(colors.blue("fee"))}: ${colors.brightGreen(fee.toUpperCase())}
`;

  console.log(text);

  if (remainingMem < 0) {
    throw new Error("Out of mem");
  }

  if (remainingSteps < 0) {
    throw new Error("Out of cpu");
  }

  if (remainingTxBytes < 0) {
    throw new Error("Out of tx space");
  }
}

function randomAssetId() {
  const bytes = new Uint8Array(48);
  crypto.getRandomValues(bytes);
  return toHex(bytes);
}
