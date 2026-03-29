// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/ICityConfig.sol";
import "../interfaces/ICityRegistryRead.sol";
import "../interfaces/ICityStatus.sol";
import "../interfaces/ICityPoints.sol";
import "../libraries/CityTypes.sol";

contract CityMaintenance is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint8 public constant CATEGORY_UPKEEP_POINTS = 4;

    ICityConfig public immutable cityConfig;
    ICityRegistryRead public immutable cityRegistry;
    ICityStatus public cityStatus;

    mapping(address => bool) public authorizedCallers;
    mapping(uint256 => uint256) public lastPitPaymentOf;
    mapping(uint256 => uint32) public paymentCountOf;
    mapping(uint8 => uint256) public feeByPlotType;
    mapping(uint8 => uint256) public pointsByPlotType;

    uint256 public minSecondsBetweenPayments;
    bool public allowThirdPartyPayer;
    address public cityPoints;

    event AuthorizedCallerSet(address indexed caller, bool allowed);
    event MaintenancePaid(
        uint256 indexed plotId,
        address indexed payer,
        uint256 amount,
        uint256 timestamp
    );
    event PlotTypeFeeSet(uint8 indexed plotType, uint256 feeAmount, uint256 pointsAwarded);
    event MinSecondsBetweenPaymentsSet(uint256 newValue);
    event AllowThirdPartyPayerSet(bool allowed);
    event CityPointsSet(address indexed cityPointsAddress);
    event CityStatusSet(address indexed cityStatusAddress);

    error NotAuthorized();
    error InvalidValue();
    error InvalidConfig();
    error IncorrectMaintenanceAmount(uint256 expectedAmount, uint256 providedAmount);
    error MaintenanceTooSoon(uint256 plotId, uint256 nextAllowedAt);

    constructor(
        address initialOwner,
        address cityConfigAddress,
        address cityRegistryAddress,
        address cityStatusAddress
    ) Ownable(initialOwner) {
        if (
            cityConfigAddress == address(0) ||
            cityRegistryAddress == address(0) ||
            cityStatusAddress == address(0)
        ) {
            revert InvalidValue();
        }

        cityConfig = ICityConfig(cityConfigAddress);
        cityRegistry = ICityRegistryRead(cityRegistryAddress);
        cityStatus = ICityStatus(cityStatusAddress);
        minSecondsBetweenPayments = 1 days;
        allowThirdPartyPayer = true;
    }

    modifier onlyAuthorized() {
        if (!(msg.sender == owner() || authorizedCallers[msg.sender])) {
            revert NotAuthorized();
        }
        _;
    }

    function setAuthorizedCaller(address caller, bool allowed) external onlyOwner {
        if (caller == address(0)) revert InvalidValue();
        authorizedCallers[caller] = allowed;
        emit AuthorizedCallerSet(caller, allowed);
    }

    function setCityStatus(address cityStatusAddress) external onlyOwner {
        if (cityStatusAddress == address(0)) revert InvalidValue();
        cityStatus = ICityStatus(cityStatusAddress);
        emit CityStatusSet(cityStatusAddress);
    }

    function setCityPoints(address cityPointsAddress) external onlyOwner {
        cityPoints = cityPointsAddress;
        emit CityPointsSet(cityPointsAddress);
    }

    function setPlotTypeFee(
        uint8 plotType,
        uint256 feeAmount,
        uint256 pointsAwarded
    ) external onlyOwner {
        feeByPlotType[plotType] = feeAmount;
        pointsByPlotType[plotType] = pointsAwarded;
        emit PlotTypeFeeSet(plotType, feeAmount, pointsAwarded);
    }

    function setMinSecondsBetweenPayments(uint256 newValue) external onlyOwner {
        if (newValue == 0) revert InvalidValue();
        minSecondsBetweenPayments = newValue;
        emit MinSecondsBetweenPaymentsSet(newValue);
    }

    function setAllowThirdPartyPayer(bool allowed) external onlyOwner {
        allowThirdPartyPayer = allowed;
        emit AllowThirdPartyPayerSet(allowed);
    }

    function previewMaintenanceCost(uint256 plotId) public view returns (uint256) {
        CityTypes.PlotCore memory plot = cityRegistry.getPlotCore(plotId);
        return feeByPlotType[uint8(plot.plotType)];
    }

    function canPayMaintenance(uint256 plotId)
        external
        view
        returns (bool allowed, uint256 amount, uint256 nextAllowedAt)
    {
        amount = previewMaintenanceCost(plotId);
        nextAllowedAt = lastPitPaymentOf[plotId] + minSecondsBetweenPayments;
        allowed = amount > 0 && block.timestamp >= nextAllowedAt;
    }

    function secondsUntilNextMaintenancePayment(uint256 plotId) external view returns (uint256) {
        uint256 nextAllowedAt = lastPitPaymentOf[plotId] + minSecondsBetweenPayments;
        if (block.timestamp >= nextAllowedAt) {
            return 0;
        }
        return nextAllowedAt - block.timestamp;
    }

    function payMaintenance(uint256 plotId, uint256 amount) external nonReentrant {
        CityTypes.PlotCore memory plot = cityRegistry.getPlotCore(plotId);

        if (!allowThirdPartyPayer && plot.owner != msg.sender) {
            revert NotAuthorized();
        }

        uint256 requiredAmount = feeByPlotType[uint8(plot.plotType)];
        if (requiredAmount == 0) revert InvalidConfig();
        if (amount != requiredAmount) {
            revert IncorrectMaintenanceAmount(requiredAmount, amount);
        }

        uint256 lastPaidAt = lastPitPaymentOf[plotId];
        uint256 nextAllowedAt = lastPaidAt + minSecondsBetweenPayments;
        if (lastPaidAt != 0 && block.timestamp < nextAllowedAt) {
            revert MaintenanceTooSoon(plotId, nextAllowedAt);
        }

        address pitAddr = cityConfig.getAddressConfig(cityConfig.KEY_PITRONE());
        address treasury = cityConfig.getAddressConfig(cityConfig.KEY_TREASURY());
        if (pitAddr == address(0) || treasury == address(0)) {
            revert InvalidConfig();
        }

        IERC20(pitAddr).safeTransferFrom(msg.sender, treasury, amount);

        lastPitPaymentOf[plotId] = block.timestamp;
        paymentCountOf[plotId] += 1;
        cityStatus.recordMaintenance(plotId);

        uint256 upkeepPoints = pointsByPlotType[uint8(plot.plotType)];
        if (cityPoints != address(0) && upkeepPoints > 0) {
            try ICityPoints(cityPoints).addPoints(msg.sender, upkeepPoints, CATEGORY_UPKEEP_POINTS) {} catch {}
        }

        emit MaintenancePaid(plotId, msg.sender, amount, block.timestamp);
    }

    function adminRecordMaintenance(uint256 plotId) external onlyAuthorized {
        cityRegistry.getPlotCore(plotId);
        cityStatus.recordMaintenance(plotId);
    }
}
