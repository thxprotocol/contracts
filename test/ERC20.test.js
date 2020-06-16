const { accounts, contract } = require('@openzeppelin/test-environment');
const { expect } = require('chai');
const THXToken = contract.fromArtifact('THXToken'); // Loads a compiled contract
const gateway = '0xF19D543f5ca6974b8b9b39Fcb923286dE4e9D975';
let token;

describe('THXToken', function() {
    const [owner] = accounts;

    before(async () => {
        token = await THXToken.new(gateway, owner, { from: owner });
    });

    it('has gateways set to ' + gateway, async function() {
        expect(await token.gateway()).to.equal(gateway);
    });

    it('can mint 1000 THX', async function() {
        expect((await token.balanceOf(owner)).toNumber()).to.equal(0);

        await token.mint(owner, 1000, { from: owner });

        expect((await token.balanceOf(owner)).toNumber()).to.equal(1000);
    });

    it('can send 1000 THX', async function() {
        await token.approve(accounts[1], 1000, { from: owner });
        await token.transfer(accounts[1], 1000, { from: owner });

        expect((await token.balanceOf(owner)).toNumber()).to.equal(0);
        expect((await token.balanceOf(accounts[1])).toNumber()).to.equal(1000);
    });
});
