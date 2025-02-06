import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { CONTRACTS, deployDirectly } from "../utils/utils";

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    await deployDirectly(hre, CONTRACTS.StateLensIcs23SmtLib);
};

deploy.tags = [CONTRACTS.StateLensIcs23SmtLib.name, "union"];
deploy.dependencies = [];
export default deploy;
