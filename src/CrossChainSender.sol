// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/token/ERC20/IERC20.sol";
import {SafeERC20} from
    "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/token/ERC20/utils/SafeERC20.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
contract CrossChainSender is OwnerIsCreator {
    using SafeERC20 for IERC20;

    mapping(address onBehalfOf => uint256 ccipLnMAmount) public liquidTokensAmount;

    enum PayFeesIn {
        Native,
        LINK
    }

    IRouterClient immutable i_ccipRouter;
    LinkTokenInterface immutable i_link;
    IERC20 immutable i_stakingToken;

    // Mapping to keep track of allowlisted destination chains.
    mapping(uint64 chainSelector => bool isAllowlisted) public allowlistedDestinationChains;

    error DestinationChainNotAllowlisted(uint64 destinationChainSelector); // Used when the destination chain has not been allowlisted by the contract owner.
    error NotEnoughBalanceForFees(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance to cover the fees.
    error NothingToWithdraw(); // Used when trying to withdraw Ether but there's nothing to withdraw.
    error FailedToWithdrawEth(address owner, address target, uint256 value); // Used when the withdrawal of Ether fails.

    event MessageSent(
        bytes32 indexed messageId,
        uint64 destinationChainSelector,
        address receiver,
        address onBehalfOf,
        address token,
        uint256 amount,
        PayFeesIn payFeesIn,
        uint256 fees
    );

    constructor(address ccipRouterAddress, address linkAddress, address stakingTokenAddress) {
        i_ccipRouter = IRouterClient(ccipRouterAddress);
        i_link = LinkTokenInterface(linkAddress);
        i_stakingToken = IERC20(stakingTokenAddress);
    }

    receive() external payable {}

    modifier onlyAllowlistedDestinationChain(uint64 _destinationChainSelector) {
        if (!allowlistedDestinationChains[_destinationChainSelector]) {
            revert DestinationChainNotAllowlisted(_destinationChainSelector);
        }
        _;
    }

    /// @dev Updates the allowlist status of a destination chain for transactions.
    /// @notice This function can only be called by the owner.
    /// @param _destinationChainSelector The selector of the destination chain to be updated.
    /// @param allowed The allowlist status to be set for the destination chain.
    function allowlistDestinationChain(uint64 _destinationChainSelector, bool allowed) external onlyOwner {
        allowlistedDestinationChains[_destinationChainSelector] = allowed;
    }

    function send(
        uint64 _destinationChainSelector,
        address _receiver,
        address _onBehalfOf,
        uint256 _amount,
        PayFeesIn _payFeesIn,
        uint256 _gasLimit
    ) external onlyAllowlistedDestinationChain(_destinationChainSelector) returns (bytes32 messageId) {
        // Set the token amounts
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount =
            Client.EVMTokenAmount({token: address(i_stakingToken), amount: _amount});
        tokenAmounts[0] = tokenAmount;

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver), // ABI-encoded receiver address
            data: abi.encode(_onBehalfOf), // ABI-encoded string
            tokenAmounts: tokenAmounts, // The amount and type of token being transferred
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit and non-strict sequencing mode
                Client.EVMExtraArgsV1({gasLimit: _gasLimit, strict: false})
                ),
            // Set the feeToken, address(linkToken) means fees are paid in LINK, address(0) means fees are paid in native gas
            feeToken: _payFeesIn == PayFeesIn.LINK ? address(i_link) : address(0)
        });

        // Get the fee required to send the CCIP message
        uint256 fees = i_ccipRouter.getFee(_destinationChainSelector, message);

        if (_payFeesIn == PayFeesIn.LINK) {
            if (fees > i_link.balanceOf(address(this))) {
                revert NotEnoughBalanceForFees(i_link.balanceOf(address(this)), fees);
            }

            // Approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
            i_link.approve(address(i_ccipRouter), fees);

            i_stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
            i_stakingToken.approve(address(i_ccipRouter), _amount);

            // Send the message through the router and store the returned message ID
            messageId = i_ccipRouter.ccipSend(_destinationChainSelector, message);
        } else {
            if (fees > address(this).balance) {
                revert NotEnoughBalanceForFees(address(this).balance, fees);
            }

            i_stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
            i_stakingToken.approve(address(i_ccipRouter), _amount);

            // Send the message through the router and store the returned message ID
            messageId = i_ccipRouter.ccipSend{value: fees}(_destinationChainSelector, message);
        }

        emit MessageSent(
            messageId,
            _destinationChainSelector,
            _receiver,
            _onBehalfOf,
            address(i_stakingToken),
            _amount,
            _payFeesIn,
            fees
        );
    }

    /// @notice Allows the contract owner to withdraw the entire balance of Ether from the contract.
    /// @dev This function reverts if there are no funds to withdraw or if the transfer fails.
    /// It should only be callable by the owner of the contract.
    /// @param _beneficiary The address to which the Ether should be sent.
    function withdraw(address _beneficiary) public onlyOwner {
        // Retrieve the balance of this contract
        uint256 amount = address(this).balance;

        // Revert if there is nothing to withdraw
        if (amount == 0) revert NothingToWithdraw();

        // Attempt to send the funds, capturing the success status and discarding any return data
        (bool sent,) = _beneficiary.call{value: amount}("");

        // Revert if the send failed, with information about the attempted transfer
        if (!sent) revert FailedToWithdrawEth(msg.sender, _beneficiary, amount);
    }

    /// @notice Allows the owner of the contract to withdraw all tokens of a specific ERC20 token.
    /// @dev This function reverts with a 'NothingToWithdraw' error if there are no tokens to withdraw.
    /// @param _beneficiary The address to which the tokens will be sent.
    /// @param _token The contract address of the ERC20 token to be withdrawn.
    function withdrawToken(address _beneficiary, address _token) public onlyOwner {
        // Retrieve the balance of this contract
        uint256 amount = IERC20(_token).balanceOf(address(this));

        // Revert if there is nothing to withdraw
        if (amount == 0) revert NothingToWithdraw();

        IERC20(_token).transfer(_beneficiary, amount);
    }
}
