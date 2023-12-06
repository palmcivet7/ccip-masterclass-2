// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

// had to replace original imports with these which ended up not being able to transfer the tokens
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
contract CCIPTokenSender_Unsafe is OwnerIsCreator {
    using SafeERC20 for IERC20;

    IRouterClient ccipRouter;
    LinkTokenInterface linkToken;

    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);

    event TokensTransferred(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address receiver,
        address token,
        uint256 tokenAmount,
        address feeToken,
        uint256 fees
    );

    constructor(address ccipRouterAddress, address linkTokenAddress) {
        ccipRouter = IRouterClient(ccipRouterAddress);
        linkToken = LinkTokenInterface(linkTokenAddress);
    }

    function transfer(uint64 _destinationChainSelector, address _receiver, address _tokenToSend, uint256 _amountToSend)
        external
        onlyOwner
        returns (bytes32 messageId)
    {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({token: _tokenToSend, amount: _amountToSend});
        tokenAmounts[0] = tokenAmount;

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: "",
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                // Gas limit is 0 because the receiver is an EOA, not smart contract
                Client.EVMExtraArgsV1({gasLimit: 0})
                ),
            feeToken: address(linkToken)
        });

        uint256 fees = ccipRouter.getFee(_destinationChainSelector, message);

        if (fees > linkToken.balanceOf(address(this))) {
            revert NotEnoughBalance(linkToken.balanceOf(address(this)), fees);
        }

        linkToken.approve(address(ccipRouter), fees);

        IERC20(_tokenToSend).safeTransferFrom(msg.sender, address(this), _amountToSend);
        IERC20(_tokenToSend).approve(address(ccipRouter), _amountToSend);

        // Send CCIP Message
        messageId = ccipRouter.ccipSend(_destinationChainSelector, message);

        emit TokensTransferred(
            messageId, _destinationChainSelector, _receiver, _tokenToSend, _amountToSend, address(linkToken), fees
        );
    }
}
