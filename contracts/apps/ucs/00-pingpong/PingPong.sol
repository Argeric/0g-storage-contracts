pragma solidity ^0.8.27;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "../../Base.sol";
import "../../../core/25-handler/IBCHandler.sol";
import "../03-zkgm/IEurekaModule.sol";

// Protocol specific packet
struct PingPongPacket {
    bool ping;
}

library PingPongLib {
    bytes1 public constant ACK_SUCCESS = 0x01;

    error ErrOnlyOneChannel();
    error ErrInvalidAck();
    error ErrNoChannel();
    error ErrInfiniteGame();
    error ErrOnlyZKGM();

    event Ring(bool ping);
    event TimedOut();
    event Acknowledged();
    event Zkgoblim(uint32 channelId, bytes sender, bytes message);

    function encode(
        PingPongPacket memory packet
    ) internal pure returns (bytes memory) {
        return abi.encode(packet.ping);
    }

    function decode(
        bytes memory packet
    ) internal pure returns (PingPongPacket memory) {
        bool ping = abi.decode(packet, (bool));
        return PingPongPacket({ping: ping});
    }
}

contract PingPong is
    IBCAppBase,
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    IEurekaModule
{
    using PingPongLib for *;

    IIBCPacket private ibcHandler;
    uint32 private _gap0;
    uint64 private timeout;
    address private zkgmProtocol;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        IIBCPacket _ibcHandler,
        address admin,
        uint64 _timeout
    ) public initializer {
        __Ownable_init(admin);
        ibcHandler = _ibcHandler;
        timeout = _timeout;
    }

    function ibcAddress() public view virtual override returns (address) {
        return address(ibcHandler);
    }

    function initiate(
        PingPongPacket memory packet,
        uint32 channelId,
        uint64 localTimeout
    ) public {
        ibcHandler.sendPacket(
            channelId,
            // No height timeout
            0,
            // Timestamp timeout
            localTimeout,
            // Raw protocol packet
            packet.encode()
        );
    }

    function onRecvPacket(
        IBCPacket calldata packet,
        address,
        bytes calldata
    )
        external
        virtual
        override
        onlyIBC
        returns (bytes memory acknowledgement)
    {
        PingPongPacket memory pp = PingPongLib.decode(packet.data);

        emit PingPongLib.Ring(pp.ping);

        uint64 localTimeout = uint64(block.timestamp * 1e9) + timeout;

        // Send back the packet after having reversed the bool and set the counterparty timeout
        initiate(
            PingPongPacket({ping: !pp.ping}),
            packet.destinationChannelId,
            localTimeout
        );

        // Return protocol specific successful acknowledgement
        return abi.encodePacked(PingPongLib.ACK_SUCCESS);
    }

    function onAcknowledgementPacket(
        IBCPacket calldata,
        bytes calldata acknowledgement,
        address
    ) external virtual override onlyIBC {
        /*
            In practice, a more sophisticated protocol would check
            and execute code depending on the counterparty outcome (refund etc...).
            In our case, the acknowledgement will always be ACK_SUCCESS
        */
        if (
            keccak256(acknowledgement)
                != keccak256(abi.encodePacked(PingPongLib.ACK_SUCCESS))
        ) {
            revert PingPongLib.ErrInvalidAck();
        }
        emit PingPongLib.Acknowledged();
    }

    function onTimeoutPacket(
        IBCPacket calldata,
        address
    ) external virtual override onlyIBC {
        /*
            Similarly to the onAcknowledgementPacket function, this indicates a failure to deliver the packet in expected time.
            A sophisticated protocol would revert the action done before sending this packet.
        */
        emit PingPongLib.TimedOut();
    }

    function onChanOpenInit(
        uint32,
        uint32,
        string calldata,
        address
    ) external virtual override onlyIBC {}

    function onChanOpenTry(
        uint32,
        uint32,
        uint32,
        string calldata,
        string calldata,
        address
    ) external virtual override onlyIBC {}

    function onChanOpenAck(
        uint32 channelId,
        uint32,
        string calldata,
        address
    ) external virtual override onlyIBC {}

    function onChanOpenConfirm(
        uint32 channelId,
        address
    ) external virtual override onlyIBC {}

    function onChanCloseInit(
        uint32,
        address
    ) external virtual override onlyIBC {
        // The ping-pong is infinite, closing the channel is disallowed.
        revert PingPongLib.ErrInfiniteGame();
    }

    function onChanCloseConfirm(
        uint32,
        address
    ) external virtual override onlyIBC {
        // Symmetric to onChanCloseInit
        revert PingPongLib.ErrInfiniteGame();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function setZkgm(
        address zkgm
    ) public onlyOwner {
        zkgmProtocol = zkgm;
    }

    function onZkgm(
        uint32 channelId,
        bytes calldata sender,
        bytes calldata message
    ) public {
        if (msg.sender != zkgmProtocol) {
            revert PingPongLib.ErrOnlyZKGM();
        }
        emit PingPongLib.Zkgoblim(channelId, sender, message);
    }
}
