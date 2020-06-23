const { accounts, contract } = require('@openzeppelin/test-environment');
const { expect } = require('chai');
const THXToken = contract.fromArtifact('THXToken');
const RewardPool = contract.fromArtifact('RewardPool');
const gateway = '0xF19D543f5ca6974b8b9b39Fcb923286dE4e9D975';

let token = null;
let pool = null;

describe('Roles', function() {
    const [owner] = accounts;

    before(async () => {
        token = await THXToken.new(gateway, owner, { from: owner });
        pool = await RewardPool.new({ from: owner });

        await pool.initialize(owner, token.address);
    });

    it('can verify account to be a member', async function() {
        expect(await pool.isMember(accounts[1], { from: owner })).to.be.false;
    });

    it('can add a member', async function() {
        expect(await pool.isMember(accounts[1], { from: owner })).to.be.false;

        await pool.addMember(accounts[1], { from: owner });

        expect(await pool.isMember(accounts[1], { from: owner })).to.be.true;
    });

    it('can remove a member', async function() {
        expect(await pool.isMember(accounts[1], { from: owner })).to.be.true;

        await pool.removeMember(accounts[1], { from: owner });

        expect(await pool.isMember(accounts[1], { from: owner })).to.be.false;
    });

    it('can verify account to be a manager', async function() {
        expect(await pool.isManager(accounts[1], { from: owner })).to.be.false;
    });

    it('can add a manager', async function() {
        expect(await pool.isManager(accounts[1], { from: owner })).to.be.false;

        await pool.addManager(accounts[1], { from: owner });

        expect(await pool.isManager(accounts[1], { from: owner })).to.be.true;
    });

    it('can remove a manager', async function() {
        expect(await pool.isManager(accounts[1], { from: owner })).to.be.true;

        await pool.removeManager(accounts[1], { from: owner });

        expect(await pool.isManager(accounts[1], { from: owner })).to.be.false;
    });
});
