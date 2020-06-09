const { accounts, contract } = require("@openzeppelin/test-environment");
const { expect } = require("chai");
const THXToken = contract.fromArtifact("THXToken"); // Loads a compiled contract
const gateway = "0xF19D543f5ca6974b8b9b39Fcb923286dE4e9D975";

describe("THXToken", function() {
  const [owner] = accounts;

  it("gateway is set to " + gateway, async function() {
    const token = await THXToken.new(gateway, owner, { from: owner });
    expect(await token.gateway()).to.equal(gateway);
  });
});
