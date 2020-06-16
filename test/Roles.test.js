const { accounts, contract } = require('@openzeppelin/test-environment');
const { expect } = require('chai');
const RewardPool = contract.fromArtifact('RewardPool');
let pool = null;

describe('Roles', function() {
    const [owner] = accounts;

    before(async () => {
        pool = await RewardPool.new({ from: owner });

        await pool.initialize(owner);
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
