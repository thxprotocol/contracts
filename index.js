const Web3 = require("web3");
const {
  ZWeb3,
  ProxyAdminProject,
  Contracts,
} = require("@openzeppelin/upgrades");

const web3 = new Web3("http://localhost:7545");

async function main() {
  // Set up web3 object, connected to the local development network, initialize the Upgrades library
  ZWeb3.initialize(web3.currentProvider);

  // Take the first account ganache returns as the from account.
  const [from] = await ZWeb3.eth.getAccounts();

  console.log(from);  
}

main();
