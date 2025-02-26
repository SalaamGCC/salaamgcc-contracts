// Execute this script using Node.js:
// node script/encodeData.js
// Or using Bun:
// bun script/encodeData.js
import { ethers } from "ethers";

const abi = ["function mint(address,uint256)"];

const iface = new ethers.Interface(abi);
const tokenWallet_1 = iface.encodeFunctionData("mint", [
  "0x4E9Ff90564C9D6B89d63197A0034c09A50e53190",
  ethers.parseEther("2000000000"), // 2B SGCC
]);

const tokenWallet_2 = iface.encodeFunctionData("mint", [
  "0x08D8B7852a03e775BE9C0D2137A59E417A4B3e5B",
  ethers.parseEther("2000000000"), // 2B SGCC
]);

const tokenWallet_3 = iface.encodeFunctionData("mint", [
  "0x062f6869e5FC2f56f52a817eAd98c1d6576412F4",
  ethers.parseEther("2000000000"), // 2B SGCC
]);

console.log("Token Wallet 1:", tokenWallet_1); // Hex-encoded calldata
console.log("Token Wallet 2:", tokenWallet_2); // Hex-encoded calldata
console.log("Token Wallet 3:", tokenWallet_3); // Hex-encoded calldata

// Token Wallet 1: 0x40c10f190000000000000000000000004e9ff90564c9d6b89d63197a0034c09a50e53190000000000000000000000000000000000000000006765c793fa10079d0000000
// Token Wallet 2: 0x40c10f1900000000000000000000000008d8b7852a03e775be9c0d2137a59e417a4b3e5b000000000000000000000000000000000000000006765c793fa10079d0000000
// Token Wallet 3: 0x40c10f19000000000000000000000000062f6869e5fc2f56f52a817ead98c1d6576412f4000000000000000000000000000000000000000006765c793fa10079d0000000
