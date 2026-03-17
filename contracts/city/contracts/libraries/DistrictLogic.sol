// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/CityErrors.sol";
import "../interfaces/IPIT.sol";
import "../core/CityConfig.sol";
import "../core/CityRegistry.sol";
import "../interfaces/ICityStatus.sol";

contract CityMaintenance is Ownable {
    CityConfig public immutable cityConfig;
    CityRegistry public immutable cityRegistry;
    ICityStatus public cityStatus;

    mapping(address => bool) public authorizedCallers;
    mapping(uint256 => uint256) public lastPitPaymentOf;

    event AuthorizedCallerSet(address indexed caller, bool allowed);
    event MaintenancePaid(
        uint256 indexed plotId,
        address indexed payer,
        uint256 amount,
        uint256 timestamp
    );

    constructor(
        address initialOwner,
        address cityConfigAddress,
        address cityRegistryAddress,
        address cityStatusAddress
    ) Ownable(initialOwner) {
        if (
            initialOwner == address(0) ||
            cityConfigAddress == address(0) ||
            cityRegistryAddress == address(0) ||
            cityStatusAddress == address(0)
        ) {
            revert CityErrors.ZeroAddress();
        }

        cityConfig = CityConfig(cityConfigAddress);
        cityRegistry = CityRegistry(cityRegistryAddress);
        cityStatus = ICityStatus(cityStatusAddress);
    }

    modifier onlyAuthorized() {
        if (!(msg.sender == owner() || authorizedCallers[msg.sender])) {
            revert CityErrors.NotAuthorized();
        }
        _;
    }

    function setAuthorizedCaller(address caller, bool allowed) external onlyOwner {
        if (caller == address(0)) revert CityErrors.ZeroAddress();
        authorizedCallers[caller] = allowed;
        emit AuthorizedCallerSet(caller, allowed);
    }

    function payMaintenance(uint256 plotId, uint256 amount) external {
        if (amount == 0) revert CityErrors.InvalidValue();

        // validiert Plot-Existenz
        cityRegistry.getPlotCore(plotId);

        address pitAddr = cityConfig.getAddressConfig(cityConfig.KEY_PITRONE());
        address treasury = cityConfig.getAddressConfig(cityConfig.KEY_TREASURY());

        if (pitAddr == address(0) || treasury == address(0)) {
            revert CityErrors.InvalidConfig();
        }

        bool ok = IPIT(pitAddr).transferFrom(msg.sender, treasury, amount);
        if (!ok) revert CityErrors.InvalidValue();

        lastPitPaymentOf[plotId] = block.timestamp;
        cityStatus.recordMaintenance(plotId);

        emit MaintenancePaid(plotId, msg.sender, amount, block.timestamp);
    }

    function adminRecordMaintenance(uint256 plotId) external onlyAuthorized {
        cityRegistry.getPlotCore(plotId);
        cityStatus.recordMaintenance(plotId);
    }
}