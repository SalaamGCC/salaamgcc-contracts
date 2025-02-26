import { ethers } from "ethers";

const abi = ["function mint(address,uint256)"];

const iface = new ethers.Interface(abi);
const functionData = iface.encodeFunctionData("mint", [
  "0x4E9Ff90564C9D6B89d63197A0034c09A50e53190",
  ethers.parseEther("2000000000"), // Example 1 ETH
]);

console.log(functionData); // Hex-encoded calldata

// Execute this script using Node.js:
// node script/encodeData.js
//
// Or using Bun:
// bun script/encodeData.js
//
// Make sure you have ethers.js installed:
// npm install ethers
// or
// bun add ethers
