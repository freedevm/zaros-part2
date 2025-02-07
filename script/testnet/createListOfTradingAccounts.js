// npm install ethers dotenv

const { ethers } = require("ethers");
const fs = require("fs");
require("dotenv").config(); // Load environment variables from .env file

// Step 1: Set up the provider using Infura or any other Ethereum node provider
const provider = new ethers.JsonRpcProvider(process.env.ALCHEMY_URL);

// Step 2: Create a signer using your private key
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

// Step 3: Define the ABI for the smart contract function you want to call
const contractABI = [
  {
    constant: false,
    inputs: [
      { name: "sender", type: "address" },
      { name: "referralCode", type: "bytes" },
      { name: "isCustomReferralCode", type: "bool" },
    ],
    name: "createTradingAccountWithSender",
    outputs: [{ name: "tradingAccountId", type: "uint128" }],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
];

// Step 4: Define the smart contract address
const contractAddress = "0x6f7b7e54a643E1285004AaCA95f3B2e6F5bcC1f3"; // Replace with your smart contract address

// Step 5: Create a contract instance
const contract = new ethers.Contract(contractAddress, contractABI, wallet);

// Step 6: Read the JSON file containing the input data
const jsonData = JSON.parse(fs.readFileSync("accounts_updated.json", "utf8")).data;

// Step 7: Function to call the smart contract function for each entry in the JSON array
async function createTradingAccounts() {
  const abiCoder = new ethers.AbiCoder();

  for (let index = 0; index < jsonData.length; index++) {
    const entry = jsonData[index];

    const { sender, shouldUseReferrerField } = entry;

    let referralCodeBytes;

    try {
      // Convert the referral code to bytes format
      if (shouldUseReferrerField) {
        referralCodeBytes = abiCoder.encode(["address"], [entry.referrer]);
      } else {
        referralCodeBytes = ethers.toUtf8Bytes("");
      }

      console.log("--------------------------------------------------------------------------------");
      console.log(`Index: ${index}`);
      console.log(`Sender: ${sender}`);
      console.log(`referrer: ${entry.referrer}`);
      console.log(`shouldUseReferrerField: ${shouldUseReferrerField}`);

      // Call the smart contract function
      const tx = await contract.createTradingAccountWithSender(sender, referralCodeBytes, false);
      console.log(`Transaction sent: ${tx.hash}`);

      // Wait for the transaction to be mined before proceeding to the next one
      await tx.wait();
    } catch (error) {
      let tryAgain = true;

      while (tryAgain) {
        // Try again
        try {
          console.log("Try again index: ", index);
          // Call the smart contract function
          const tx = await contract.createTradingAccountWithSender(sender, referralCodeBytes, false);
          console.log(`Transaction sent: ${tx.hash}`);

          // Wait for the transaction to be mined before proceeding to the next one
          await tx.wait();

          tryAgain = false;
        } catch (error) {
          console.log("ERROORRRRRRRRRRR");
          console.log(`Index: ${index}`);
          console.error(`Error creating trading account for sender ${sender}:`, error);
        }
      }
    }
  }
}

// Step 8: Run the function
createTradingAccounts();
