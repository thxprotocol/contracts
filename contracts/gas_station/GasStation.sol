// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.4;

import '../libraries/Signature.sol';

contract GasStation {
    constructor(address _admin) public {
        admin = _admin;
    }

    address private admin;

    mapping(address => uint256) private signerNonce;

    event Result(bool success, bytes data);

    /**
     * @dev Get the latest nonce of a given signer
     * @param _signer Address of the signer
     */
    function getLatestNonce(address _signer) public view returns (uint256) {
        return signerNonce[_signer];
    }

    /**
     * @dev Validate a given nonce, reverts if nonce is not right
     * @param _signer Address of the signer
     * @param _nonce Nonce of the signer
     */
    function validateNonce(address _signer, uint256 _nonce) private {
        uint256 lastNonce = signerNonce[_signer];
        require(lastNonce + 1 == _nonce, 'INVALID_NONCE');
        signerNonce[_signer] = _nonce;
    }

    // Multinonce? https://github.com/PISAresearch/metamask-comp#multinonce
    function call(
        bytes memory _call,
        address _to,
        uint256 _nonce,
        bytes memory _sig
    ) public {
        require(msg.sender == admin, 'ONLY_ADMIN');

        bytes32 message = Signature.prefixed(keccak256(abi.encodePacked(_call, _to, this, _nonce)));
        address signer = Signature.recoverSigner(message, _sig);

        validateNonce(signer, _nonce);
        (bool success, bytes memory returnData) = _to.call(abi.encodePacked(_call, signer));
        emit Result(success, returnData);
    }
}
