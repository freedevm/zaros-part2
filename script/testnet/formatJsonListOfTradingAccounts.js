const fs = require("fs");
const web3 = require("web3"); // Import web3

function formartAddress(address) {
  const formattedAddress = web3.utils.toChecksumAddress(address);
  return  formattedAddress ;
}

// Read JSON file
fs.readFile("accounts_updated.json", "utf8", (err, data) => {
  if (err) {
    console.error("Error reading file:", err);
    return;
  }

  // Parse JSON data
  const jsonData = JSON.parse(data);

  for (let i = 0; i < jsonData.length; i++) {
    const { sender, referrer } = jsonData[i];

    if(typeof sender == "string" && sender.length > 0){
      jsonData[i].sender = formartAddress(sender);
    }

    if(typeof referrer == "string" && referrer.length > 0){
      jsonData[i].shouldUseReferrerField = true;
      jsonData[i].referrer = formartAddress(referrer);
    }else {
      jsonData[i].shouldUseReferrerField = false;
      jsonData[i].referrer = jsonData[i].sender;
    }

    const newObj = {
      sender: jsonData[i].sender,
      referrer: jsonData[i].referrer,
      shouldUseReferrerField: jsonData[i].shouldUseReferrerField,
    }

    jsonData[i] = newObj;
  }

  fs.writeFile(
    "accounts_updated.json",
    JSON.stringify(jsonData, null, 2),
    "utf8",
    (err) => {
      if (err) {
        console.error("Error writing file:", err);
      } else {
        console.log("Addresses formatted and file updated!");
      }
    }
  );
});
