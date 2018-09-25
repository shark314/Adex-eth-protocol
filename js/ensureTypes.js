const web3 = require('web3')

function Uint256(x) {
	if (x === undefined) throw 'undefined value given for uint256'
	const bn = web3.utils.toBN(x)
	if (bn.isNegative()) throw 'uint256 expected, negative number given'
}
function Address(x) {
	if (x === undefined) throw 'undefined value given for address'
	return web3.utils.toChecksumAddress(x)
}
function Bytes32(x) {
	if (x === undefined) throw 'undefined value given for bytes32'
	const bytes = web3.utils.toHex(x)
	if (x.length !== 66) throw 'invalid length given for bytes32'
	return bytes
}

module.exports = { Uint256, Bytes32, Address }
