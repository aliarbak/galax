const ethers = require('ethers');

let singletonWeb3Provider;
function getWeb3Provider() {
    if (singletonWeb3Provider) {
        return singletonWeb3Provider;
    }

    singletonWeb3Provider = new ethers.providers.Web3Provider(web3.currentProvider);
    return singletonWeb3Provider;
}

async function characterSign(
    charactersContractAddress,
    characterAddress,
    planetId,
    nonce,
    signatureType
) {
    const chainId = 1;
    const web3Provider = getWeb3Provider();
    const message = ethers.utils.solidityPack(
        ["address", "uint256", "address", "uint256", "uint256", "uint256"],
        [charactersContractAddress, chainId.toString(), characterAddress, planetId, nonce.toString(), signatureType.toString()]
    );
    const hashedMessage = ethers.utils.solidityKeccak256(["bytes"], [message]);
    const finalMessage = ethers.utils.arrayify(hashedMessage);

    const signer = web3Provider.getSigner(characterAddress);
    const signatureData = await signer.signMessage(finalMessage);
    return signatureData;
}

async function getCharacterNonce(characters, characterAddress) {
    return (await characters.character(characterAddress)).nonce.toString();
}

module.exports = {
    getWeb3Provider,
    characterSign,
    getCharacterNonce
}