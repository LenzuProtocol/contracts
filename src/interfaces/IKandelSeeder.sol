// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IKandelSeeder
 * @notice Interface for Elix (Mangrove) Kandel market-making strategy seeder
 * @dev Deployed at 0x5abc9f2f694269eb24fd27321a00445cc0e7b4c4 on Somnia testnet
 */
struct KandelParams {
    address base;
    address quote;
    uint256 spread;
    uint256 pricePoints;
    uint256 stepSize;
}

interface IKandelSeeder {
    /**
     * @notice Seeds a new Kandel market-making strategy
     * @param vault The vault that will hold the funds
     * @param baseAmount Amount of base tokens to provision
     * @param quoteAmount Amount of quote tokens to provision
     * @param params Strategy parameters
     * @return kandel Address of the deployed Kandel instance
     */
    function seed(address vault, uint256 baseAmount, uint256 quoteAmount, KandelParams calldata params)
        external
        returns (address kandel);
}
