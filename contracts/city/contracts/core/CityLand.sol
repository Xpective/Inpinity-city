// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IResourceToken.sol";
import "../interfaces/ICityStatus.sol";
import "../interfaces/ICityHistory.sol";
import "../libraries/CityTypes.sol";
import "../libraries/CityErrors.sol";
import "../libraries/CityEvents.sol";
import "./CityConfig.sol";
import "./CityRegistry.sol";

contract CityLand is Ownable {
    uint256 public constant RESOURCE_OIL = 0;
    uint256 public constant RESOURCE_LEMONS = 1;
    uint256 public constant RESOURCE_IRON = 2;
    uint256 public constant RESOURCE_AETHER = 9;

    struct QubiqProgress {
        uint256 oilDeposited;
        uint256 lemonsDeposited;
        uint256 ironDeposited;
        bool completed;
        bool usedAether;
        address lastContributor;
        uint64 completedAt;
    }

    CityConfig public immutable cityConfig;
    CityRegistry public immutable cityRegistry;

    ICityStatus public cityStatus;
    ICityHistory public cityHistory;

    mapping(uint256 => mapping(uint32 => mapping(uint32 => QubiqProgress))) private _qubiqProgress;
    mapping(uint256 => uint256) public completedQubiqCountOf;
    mapping(uint256 => uint256) public aetherUsesOf;

    constructor(
        address initialOwner,
        address cityConfigAddress,
        address cityRegistryAddress
    ) Ownable(initialOwner) {
        if (
            initialOwner == address(0) ||
            cityConfigAddress == address(0) ||
            cityRegistryAddress == address(0)
        ) {
            revert CityErrors.ZeroAddress();
        }

        cityConfig = CityConfig(cityConfigAddress);
        cityRegistry = CityRegistry(cityRegistryAddress);
    }

    function setHooks(address cityStatusAddress, address cityHistoryAddress) external onlyOwner {
        if (cityStatusAddress != address(0)) {
            cityStatus = ICityStatus(cityStatusAddress);
        }
        if (cityHistoryAddress != address(0)) {
            cityHistory = ICityHistory(cityHistoryAddress);
        }
    }

    function getQubiq(
        uint256 plotId,
        uint32 x,
        uint32 y
    ) external view returns (QubiqProgress memory) {
        CityTypes.PlotCore memory plot = cityRegistry.getPlotCore(plotId);
        _validateWithinPlot(plot, x, y);
        return _qubiqProgress[plotId][x][y];
    }

    function contributeQubiq(
        uint256 plotId,
        uint32 x,
        uint32 y,
        uint256 oilAmount,
        uint256 lemonsAmount,
        uint256 ironAmount
    ) external {
        CityTypes.PlotCore memory plot = cityRegistry.getPlotCore(plotId);
        _validateWithinPlot(plot, x, y);

        if (plot.plotType == CityTypes.PlotType.Personal && plot.owner != msg.sender) {
            revert CityErrors.NotPlotOwner();
        }

        QubiqProgress storage q = _qubiqProgress[plotId][x][y];
        if (q.completed) revert CityErrors.InvalidValue();

        uint256 oilCost = cityConfig.getUintConfig(cityConfig.KEY_QUBIQ_OIL_COST());
        uint256 lemonsCost = cityConfig.getUintConfig(cityConfig.KEY_QUBIQ_LEMONS_COST());
        uint256 ironCost = cityConfig.getUintConfig(cityConfig.KEY_QUBIQ_IRON_COST());

        uint256 oilNeeded = oilCost > q.oilDeposited ? oilCost - q.oilDeposited : 0;
        uint256 lemonsNeeded = lemonsCost > q.lemonsDeposited ? lemonsCost - q.lemonsDeposited : 0;
        uint256 ironNeeded = ironCost > q.ironDeposited ? ironCost - q.ironDeposited : 0;

        if (oilNeeded == 0 && lemonsNeeded == 0 && ironNeeded == 0) {
            revert CityErrors.InvalidValue();
        }

        if (oilAmount > oilNeeded) oilAmount = oilNeeded;
        if (lemonsAmount > lemonsNeeded) lemonsAmount = lemonsNeeded;
        if (ironAmount > ironNeeded) ironAmount = ironNeeded;

        if (oilAmount == 0 && lemonsAmount == 0 && ironAmount == 0) {
            revert CityErrors.InvalidValue();
        }

        address resourceTokenAddr = cityConfig.getAddressConfig(cityConfig.KEY_RESOURCE_TOKEN());
        if (resourceTokenAddr == address(0)) revert CityErrors.InvalidConfig();

        IResourceToken resourceToken = IResourceToken(resourceTokenAddr);

        if (oilAmount > 0) {
            resourceToken.safeTransferFrom(msg.sender, address(this), RESOURCE_OIL, oilAmount, "");
        }
        if (lemonsAmount > 0) {
            resourceToken.safeTransferFrom(msg.sender, address(this), RESOURCE_LEMONS, lemonsAmount, "");
        }
        if (ironAmount > 0) {
            resourceToken.safeTransferFrom(msg.sender, address(this), RESOURCE_IRON, ironAmount, "");
        }

        q.oilDeposited += oilAmount;
        q.lemonsDeposited += lemonsAmount;
        q.ironDeposited += ironAmount;
        q.lastContributor = msg.sender;

        emit CityEvents.QubiqContributed(
            plotId,
            x,
            y,
            msg.sender,
            oilAmount,
            lemonsAmount,
            ironAmount
        );

        _tryCompleteQubiq(plotId, x, y, q);

        if (address(cityStatus) != address(0)) {
            cityStatus.touchActivity(plotId);
        }
    }

    function useAetherOnQubiq(
        uint256 plotId,
        uint32 x,
        uint32 y
    ) external {
        CityTypes.PlotCore memory plot = cityRegistry.getPlotCore(plotId);
        _validateWithinPlot(plot, x, y);

        if (plot.plotType == CityTypes.PlotType.Personal && plot.owner != msg.sender) {
            revert CityErrors.NotPlotOwner();
        }

        QubiqProgress storage q = _qubiqProgress[plotId][x][y];
        if (q.completed) revert CityErrors.InvalidValue();

        address resourceTokenAddr = cityConfig.getAddressConfig(cityConfig.KEY_RESOURCE_TOKEN());
        if (resourceTokenAddr == address(0)) revert CityErrors.InvalidConfig();

        IResourceToken(resourceTokenAddr).safeTransferFrom(
            msg.sender,
            address(this),
            RESOURCE_AETHER,
            1,
            ""
        );

        q.oilDeposited = cityConfig.getUintConfig(cityConfig.KEY_QUBIQ_OIL_COST());
        q.lemonsDeposited = cityConfig.getUintConfig(cityConfig.KEY_QUBIQ_LEMONS_COST());
        q.ironDeposited = cityConfig.getUintConfig(cityConfig.KEY_QUBIQ_IRON_COST());
        q.usedAether = true;
        q.lastContributor = msg.sender;

        aetherUsesOf[plotId] += 1;

        emit CityEvents.AetherUsed(plotId, x, y, msg.sender);

        _tryCompleteQubiq(plotId, x, y, q);

        if (address(cityHistory) != address(0)) {
            cityHistory.recordAetherUse(plotId);
        }

        if (address(cityStatus) != address(0)) {
            cityStatus.touchActivity(plotId);
        }
    }

    function isPlotFullyCompleted(uint256 plotId) external view returns (bool) {
        CityTypes.PlotCore memory plot = cityRegistry.getPlotCore(plotId);
        uint256 totalQubiqs = uint256(plot.width) * uint256(plot.height);
        return completedQubiqCountOf[plotId] >= totalQubiqs;
    }

    function getPlotCompletionBps(uint256 plotId) external view returns (uint256) {
        CityTypes.PlotCore memory plot = cityRegistry.getPlotCore(plotId);
        uint256 totalQubiqs = uint256(plot.width) * uint256(plot.height);
        if (totalQubiqs == 0) return 0;
        return (completedQubiqCountOf[plotId] * 10_000) / totalQubiqs;
    }

    function _tryCompleteQubiq(
        uint256 plotId,
        uint32 x,
        uint32 y,
        QubiqProgress storage q
    ) internal {
        uint256 oilCost = cityConfig.getUintConfig(cityConfig.KEY_QUBIQ_OIL_COST());
        uint256 lemonsCost = cityConfig.getUintConfig(cityConfig.KEY_QUBIQ_LEMONS_COST());
        uint256 ironCost = cityConfig.getUintConfig(cityConfig.KEY_QUBIQ_IRON_COST());

        if (
            q.oilDeposited >= oilCost &&
            q.lemonsDeposited >= lemonsCost &&
            q.ironDeposited >= ironCost
        ) {
            q.completed = true;
            q.completedAt = uint64(block.timestamp);
            completedQubiqCountOf[plotId] += 1;

            emit CityEvents.QubiqCompleted(plotId, x, y, q.usedAether);
        }
    }

    function _validateWithinPlot(
        CityTypes.PlotCore memory plot,
        uint32 x,
        uint32 y
    ) internal pure {
        if (!plot.exists) revert CityErrors.PlotNotFound();
        if (x >= plot.width || y >= plot.height) revert CityErrors.InvalidValue();
    }
}