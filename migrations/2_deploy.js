const IterableMapping = artifacts.require("IterableMapping");
const NFTDescriptor = artifacts.require("NFTDescriptor");
const LuvNFT = artifacts.require("LuvNFT");

// const fs = require("fs");

// const svg_ny = fs.readFileSync("../assets/ny.svg", "utf8");
// const svg_london = fs.readFileSync("../assets/lodon.svg", "utf8");
// const svg_mumbai = fs.readFileSync("../assets/mumbai.svg", "utf8");
// const svg_cape = fs.readFileSync("../assets/capeTown.svg", "utf8");
// const svg_melbourne = fs.readFileSync("../assets/melbourne.svg", "utf8");
// const svg_paris = fs.readFileSync("../assets/paris.svg", "utf8");
// const svg_dubai = fs.readFileSync("../assets/dubai.svg", "utf8");
// const svg_saopaulo = fs.readFileSync("../assets/sao_paulo.svg", "utf8");
// const svg_telaviv = fs.readFileSync("../assets/tel_aviv.svg", "utf8");
// const svg_sf = fs.readFileSync("../assets/sf.svg", "utf8");

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(IterableMapping);
  await deployer.link(IterableMapping, LuvNFT);
  await deployer.deploy(NFTDescriptor);
  await deployer.link(NFTDescriptor, LuvNFT);
  await deployer.deploy(LuvNFT, { gas: 10000000 });
  await LuvNFT.deployed();
  // let nftInstance = await LuvNFT.deployed();
  // await nftInstance.mint("New York", svg_ny);
  // await nftInstance.mint("London", svg_london);
  // await nftInstance.mint("Mumbai", svg_mumbai);
  // await nftInstance.mint("Cape Town", svg_cape);
  // await nftInstance.mint("Melbourne", svg_melbourne);
  // await nftInstance.mint("Dubai", svg_dubai);
  // await nftInstance.mint("Sao Paulo", svg_saopaulo);
  // await nftInstance.mint("Paris", svg_paris);
  // await nftInstance.mint("Tel Aviv", svg_telaviv);
  // await nftInstance.mint("San Francisco", svg_sf);
};
