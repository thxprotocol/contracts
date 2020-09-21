const { accounts, contract } = require('@openzeppelin/test-environment');
const { expect } = require('chai');
const THXToken = contract.fromArtifact('THXToken');
const Web3 = require('web3');
const Utils = new Web3().utils;

let token;

describe('THXToken', function() {
    const [from] = accounts;

    before(async () => {
        token = await THXToken.new({ from });
    });

    it('can mint 1000 THX', async function() {
        const amount = await Utils.toWei('1000');

        expect(Utils.fromWei(await token.balanceOf(from))).to.equal('0');

        await token.mint(from, amount, { from });

        expect(Utils.fromWei(await token.balanceOf(from))).to.equal('1000');
    });

    it('can send 1000 THX', async function() {
        const amount = await Utils.toWei('1000');

        await token.approve(accounts[1], amount, { from });
        await token.transfer(accounts[1], amount, { from });

        expect(Utils.fromWei(await token.balanceOf(from))).to.equal('0');
        expect(Utils.fromWei(await token.balanceOf(accounts[1]))).to.equal('1000');
    });
});
