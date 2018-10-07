pragma solidity 0.4.24;

import "./SafeMath.sol";
import "./BidLibrary.sol";

library CommitmentLibrary {
	using SafeMath for uint;

	// Both numbers are inclusive
	uint8 constant MIN_VALIDATOR_COUNT = 2;
	// This is an arbitrary number, but we impose this limit to restrict on-chain load; also to ensure the *3 operation is safe
	uint8 constant MAX_VALIDATOR_COUNT = 50;

	// keccak256("Commitment(bytes32 bid,address tokenAddr,uint256 tokenAmount,uint256 validUntil,address advertiser,address publisher,address[] validators,uint[] validatorRewards)");
	bytes32 constant public SCHEMA_HASH = 0x8aa1fb0e671ad6f7d73ad552eff29b7b79186e0143b91e48a013151a34ae50dd;

	struct Commitment {
		// because it contains the bidId, we don't need to hash address(this)
		bytes32 bidId;

		address tokenAddr;
		uint tokenAmount;

		uint validUntil;

		address advertiser; // buyer
		address publisher; // seller

		address[] validators;
		uint[] validatorRewards;
	}

	function hash(Commitment memory commitment) internal pure returns (bytes32) {
		// In this version of solidity, we can no longer keccak256() directly
		return keccak256(abi.encode(
			SCHEMA_HASH,
			commitment.bidId,
			commitment.tokenAddr,
			commitment.tokenAmount,
			commitment.validUntil,
			commitment.advertiser,
			commitment.publisher,
			commitment.validators,
			commitment.validatorRewards
		));
	}

	function isValid(Commitment memory commitment)
		internal
		pure
		returns (bool)
	{
		if (commitment.validators.length != commitment.validatorRewards.length) {
			return false;
		}
		if (commitment.validators.length < MIN_VALIDATOR_COUNT) {
			return false;
		}
		if (commitment.validators.length > MAX_VALIDATOR_COUNT) {
			return false;
		}

		// Validator reward sum is checked
		// if we don't do that, finalize will always fail but we will end up with a stuck bid that can only be timed out
		uint totalReward = 0;
		for (uint i=0; i<commitment.validatorRewards.length; i++) {
			totalReward = totalReward.add(commitment.validatorRewards[i]);
		}
		if (totalReward > commitment.tokenAmount) {
			return false;
		}

		return true;
	}

	function fromValues(bytes32[6] values, address[] validators, uint[] validatorRewards)
		internal
		pure
		returns (Commitment memory)
	{
		return Commitment({
			bidId: values[0],
			tokenAddr: address(values[1]),
			tokenAmount: uint(values[2]),
			validUntil: uint(values[3]),
			advertiser: address(values[4]),
			publisher: address(values[5]),
			validators: validators,
			validatorRewards: validatorRewards
		});
	}

	function fromBid(BidLibrary.Bid memory bid, bytes32 bidId, address publisher, address extraValidator)
		internal
		view
		returns (Commitment memory)
	{
		address[] memory validators = bid.validators;
		uint[] memory validatorRewards = bid.validatorRewards;

		// publishers are allowed to add up to one extra validator
		if (extraValidator != 0x0) {
			uint validatorLen = bid.validators.length;
			validators = new address[](validatorLen + 1);
			validatorRewards = new uint[](validatorLen + 1);
			for (uint i=0; i<validatorLen; i++) {
				validators[i] = bid.validators[i];
				validatorRewards[i] = bid.validatorRewards[i];
			}
			validators[validatorLen] = extraValidator;
			// The extra validator rewards needs to be 0, explicitly, cause otherwise the publisher can set all the remaining reward
			// as their own validator reward, therefore getting it merely by voting the same as the majority (no matter if true or false)
			validatorRewards[validatorLen] = 0;
		}

		return Commitment({
			bidId: bidId,
			tokenAddr: bid.tokenAddr,
			tokenAmount: bid.tokenAmount,
			validUntil: now + bid.timeout,
			advertiser: bid.advertiser,
			publisher: publisher,
			validators: validators,
			validatorRewards: validatorRewards
		});
	}
}
