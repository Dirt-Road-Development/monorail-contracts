// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

error MessageAlreadyProcessed(bytes32 messageGuid);

contract LayerZeroMessageTracker {
	mapping(bytes32 => bool) public processedMessages;

	function _processMessage(bytes32 messageGuid) internal {
		if (processedMessages[messageGuid]) revert MessageAlreadyProcessed(messageGuid);
		processedMessages[messageGuid] = true;
	}
}