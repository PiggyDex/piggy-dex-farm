import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const Deploy = buildModule("Deploy", (m) => {
  const piggy = m.contract("Piggy");
  const devAddress = "0xCD20fD26911F7378aecdBaD35dC5ea40fD175a51";
  const firstLpToken = "0x8a961ec47bde8639350c9fd39b66de1bbd2ba7dd";

  const piggyDexV2Farm = m.contract("PiggyDexV2Farm");
  m.call(piggyDexV2Farm, "initialize", [
    piggy,
    1000,
    devAddress,
    firstLpToken,
    piggy,
    0,
  ])

  return { piggy, piggyDexV2Farm };
});

export default Deploy;
