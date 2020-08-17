const { accounts, contract } = require('@openzeppelin/test-environment');
const { expect } = require('chai');
const { GATEWAY } = require('./config.js');
const THXToken = contract.fromArtifact('THXToken');
const Web3 = require('web3');
const Utils = new Web3().utils;

let token;

describe('THXToken', function() {
    const [owner] = accounts;

    before(async () => {
        token = await THXToken.new(GATEWAY, owner, { from: owner });
    });

    it('has gateways set to ' + GATEWAY, async function() {
        expect(await token.gateway()).to.equal(GATEWAY);
    });

    it('can mint 1000 THX', async function() {
        const amount = await Utils.toWei('1000');

        expect(Utils.fromWei(await token.balanceOf(owner))).to.equal('0');

        await token.mint(owner, amount, { from: owner });

        expect(Utils.fromWei(await token.balanceOf(owner))).to.equal('1000');
    });

    it('can send 1000 THX', async function() {
        const amount = await Utils.toWei('1000');

        await token.approve(accounts[1], amount, { from: owner });
        await token.transfer(accounts[1], amount, { from: owner });

        expect(Utils.fromWei(await token.balanceOf(owner))).to.equal('0');
        expect(Utils.fromWei(await token.balanceOf(accounts[1]))).to.equal('1000');
    });
});
