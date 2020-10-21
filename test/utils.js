function hex2a(hex) {
    var str = '';
    for (var i = 0; i < hex.length; i += 2) {
        var v = parseInt(hex.substr(i, 2), 16);
        if (v == 16) continue // http://www.fileformat.info/info/unicode/char/0010/index.htm
        if (v) str += String.fromCharCode(v);
    }
    return str.trim();
}

module.exports = {
    helpSign: async(gasStation, object, name, args, account) => {
        nonce = await gasStation.getLatestNonce(account.getAddress());
        nonce = parseInt(nonce) + 1;
        const call = object.interface.encodeFunctionData(name, args);
        const hash = web3.utils.soliditySha3(call, object.address, gasStation.address, nonce)
        const sig = await account.signMessage(ethers.utils.arrayify(hash))
        tx = await gasStation.call(call, object.address, nonce, sig);
        tx = await tx.wait();

        //Result event from gasSation
        const event =  await gasStation.interface.parseLog(tx.logs[0])
        res = event.args
        if (res.success) {
          // parse log from object?
        } else {
          // remove initial string that indicates this is an error
          // then parse it to hex --> ascii
          error = hex2a(res.data.substr(10))
          return {
              events: null,
              error: error
          }
        }
    }
}