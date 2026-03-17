// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library CitySignature {
    function toEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
    }

    function recoverSigner(bytes32 ethSignedMessageHash, bytes memory signature)
        internal
        pure
        returns (address)
    {
        if (signature.length != 65) {
            return address(0);
        }

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        if (v != 27 && v != 28) {
            return address(0);
        }

        return ecrecover(ethSignedMessageHash, v, r, s);
    }

    function verify(
        address expectedSigner,
        bytes32 messageHash,
        bytes memory signature
    ) internal pure returns (bool) {
        bytes32 ethSignedMessageHash = toEthSignedMessageHash(messageHash);
        return recoverSigner(ethSignedMessageHash, signature) == expectedSigner;
    }

    function hashAddressUint(address user, uint256 value) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, value));
    }

    function hashAddressUintUint(
        address user,
        uint256 value1,
        uint256 value2
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, value1, value2));
    }

    function hashBytes32(bytes32 value) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(value));
    }
}