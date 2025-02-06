import { DeployFunction, Libraries } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { CONTRACTS, deployDirectlyWithLibrary, getTypedContract } from "../utils/utils";

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const stateLensIcs23SmtLib = await getTypedContract(hre, CONTRACTS.StateLensIcs23SmtLib);
    const stateLensIcs23SmtLibAddress = await stateLensIcs23SmtLib.getAddress();

    const libraries: Libraries = {
        'StateLensIcs23SmtLib': stateLensIcs23SmtLibAddress
    }

    console.log(`deploying with libraries..\n${JSON.stringify(libraries)}`)
    await deployDirectlyWithLibrary(hre, CONTRACTS.StateLensIcs23SmtClient, libraries);
};

deploy.tags = [CONTRACTS.StateLensIcs23SmtClient.name, "union"];
deploy.dependencies = [CONTRACTS.StateLensIcs23SmtLib.name];
export default deploy;
