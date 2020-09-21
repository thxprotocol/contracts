const { accounts, contract } = require('@openzeppelin/test-environment');
const { expect } = require('chai');
const THXToken = contract.fromArtifact('THXToken');
const RewardPool = contract.fromArtifact('RewardPool');

let token = null;
let pool = null;

describe('Roles', function() {
    const [from] = accounts;

    before(async () => {
        token = await THXToken.new({ from });
        pool = await RewardPool.new({ from });

        await pool.initialize(from, token.address);
    });

    it('can verify account to be a member', async function() {
        expect(await pool.isMember(from, { from })).to.be.true;
    });

    it('can add a member', async function() {
        expect(await pool.isMember(accounts[1], { from })).to.be.false;

        await pool.addMember(accounts[1], { from });

        expect(await pool.isMember(accounts[1], { from })).to.be.true;
    });

    it('can remove a member', async function() {
        expect(await pool.isMember(accounts[1], { from })).to.be.true;

        await pool.removeMember(accounts[1], { from });

        expect(await pool.isMember(accounts[1], { from })).to.be.false;
    });

    it('can verify account to be a manager', async function() {
        expect(await pool.isManager(accounts[1], { from })).to.be.false;
    });

    it('can add a manager', async function() {
        expect(await pool.isManager(accounts[1], { from })).to.be.false;

        await pool.addManager(accounts[1], { from });

        expect(await pool.isManager(accounts[1], { from })).to.be.true;
    });

    it('can remove a manager', async function() {
        expect(await pool.isManager(accounts[1], { from })).to.be.true;

        await pool.removeManager(accounts[1], { from });

        expect(await pool.isManager(accounts[1], { from })).to.be.false;
    });
});
