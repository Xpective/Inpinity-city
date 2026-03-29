// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/ICityConfig.sol";
import "../interfaces/ICityPoints.sol";

contract CityMarketplace is Ownable, ERC1155Holder, ERC721Holder, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_BPS = 10_000;
    uint8 public constant CATEGORY_TRADE_POINTS = 3;

    enum PaymentToken {
        None,
        INPI,
        PIT
    }

    enum AssetStandard {
        None,
        ERC1155,
        ERC721
    }

    enum AssetClass {
        None,
        Resource,
        Component,
        Blueprint,
        Weapon,
        EnchantmentItem,
        MateriaItem,
        Building
    }

    enum ListingState {
        None,
        Active,
        SoldOut,
        Cancelled,
        Expired
    }

    struct Listing {
        uint256 id;
        address seller;
        address assetToken;
        uint256 assetId;
        uint256 amountTotal;
        uint256 amountRemaining;
        uint256 unitPrice;
        uint64 createdAt;
        uint64 expiry;
        PaymentToken paymentToken;
        AssetStandard assetStandard;
        AssetClass assetClass;
        ListingState state;
    }

    struct CollectionConfig {
        bool enabled;
        AssetStandard standard;
        AssetClass assetClass;
    }

    ICityConfig public immutable cityConfig;

    uint256 public nextListingId = 1;
    uint96 public protocolFeeBps;
    uint256 public tradePointsUnit;
    uint32 public tradePointsPerUnit;
    address public cityPoints;

    mapping(uint256 => Listing) public listingOf;
    mapping(address => uint256[]) public listingsBySeller;
    mapping(address => CollectionConfig) public collectionConfigOf;

    event ListingCreated(
        uint256 indexed listingId,
        address indexed seller,
        uint256 indexed resourceId,
        uint256 amount,
        uint256 unitPrice,
        PaymentToken paymentToken
    );
    event ListingCancelled(uint256 indexed listingId);
    event ListingPurchased(
        uint256 indexed listingId,
        address indexed buyer,
        uint256 amount,
        uint256 totalPrice
    );
    event ListingCreatedV2(
        uint256 indexed listingId,
        address indexed seller,
        address indexed assetToken,
        uint256 assetId,
        uint256 amount,
        uint256 unitPrice,
        PaymentToken paymentToken,
        AssetStandard assetStandard,
        AssetClass assetClass,
        uint64 expiry
    );
    event ListingFilled(
        uint256 indexed listingId,
        address indexed buyer,
        uint256 amount,
        uint256 grossPrice,
        uint256 protocolFee,
        uint256 sellerProceeds
    );
    event ListingExpired(uint256 indexed listingId);
    event CollectionConfigured(
        address indexed token,
        bool enabled,
        AssetStandard standard,
        AssetClass assetClass
    );
    event ProtocolFeeBpsSet(uint96 newFeeBps);
    event TradePointsConfigSet(uint256 tradePointsUnit, uint32 tradePointsPerUnit);
    event CityPointsSet(address indexed cityPointsAddress);

    error InvalidValue();
    error InvalidConfig();
    error InvalidPaymentToken();
    error InvalidCollection(address token);
    error ListingNotActive(uint256 listingId);
    error ListingExpiredOrUnavailable(uint256 listingId);
    error InvalidBuyAmount(uint256 requestedAmount, uint256 availableAmount);
    error SelfPurchase();
    error NotSeller();
    error FeeTooHigh(uint256 feeBps);

    constructor(address initialOwner, address cityConfigAddress) Ownable(initialOwner) {
        if (cityConfigAddress == address(0)) revert InvalidValue();
        cityConfig = ICityConfig(cityConfigAddress);
        tradePointsUnit = 1e18;
        tradePointsPerUnit = 1;
    }

    function setProtocolFeeBps(uint96 feeBps) external onlyOwner {
        if (feeBps > MAX_BPS) revert FeeTooHigh(feeBps);
        protocolFeeBps = feeBps;
        emit ProtocolFeeBpsSet(feeBps);
    }

    function setTradePointsConfig(uint256 pointsUnit, uint32 pointsPerUnit) external onlyOwner {
        if (pointsUnit == 0) revert InvalidValue();
        tradePointsUnit = pointsUnit;
        tradePointsPerUnit = pointsPerUnit;
        emit TradePointsConfigSet(pointsUnit, pointsPerUnit);
    }

    function setCityPoints(address cityPointsAddress) external onlyOwner {
        cityPoints = cityPointsAddress;
        emit CityPointsSet(cityPointsAddress);
    }

    function setCollection(
        address token,
        bool enabled,
        AssetStandard standard,
        AssetClass assetClass
    ) external onlyOwner {
        if (token == address(0)) revert InvalidValue();
        if (enabled && standard == AssetStandard.None) revert InvalidValue();

        collectionConfigOf[token] = CollectionConfig({
            enabled: enabled,
            standard: standard,
            assetClass: assetClass
        });

        emit CollectionConfigured(token, enabled, standard, assetClass);
    }

    function syncDefaultCollections() external onlyOwner {
        address resourceToken = _resourceTokenAddress();
        if (resourceToken != address(0)) {
            collectionConfigOf[resourceToken] = CollectionConfig({
                enabled: true,
                standard: AssetStandard.ERC1155,
                assetClass: AssetClass.Resource
            });
            emit CollectionConfigured(
                resourceToken,
                true,
                AssetStandard.ERC1155,
                AssetClass.Resource
            );
        }
    }

    function getCollection(address token)
        external
        view
        returns (bool enabled, AssetStandard standard, AssetClass assetClass)
    {
        CollectionConfig memory cfg = _collectionConfig(token);
        return (cfg.enabled, cfg.standard, cfg.assetClass);
    }

    function createListing(
        uint256 resourceId,
        uint256 amount,
        uint256 unitPrice,
        PaymentToken paymentToken
    ) external returns (uint256 listingId) {
        address resourceToken = _resourceTokenAddress();
        if (resourceToken == address(0)) revert InvalidConfig();
        listingId = _createERC1155Listing(
            resourceToken,
            resourceId,
            amount,
            unitPrice,
            paymentToken,
            0
        );
    }

    function createERC1155Listing(
        address token,
        uint256 assetId,
        uint256 amount,
        uint256 unitPrice,
        PaymentToken paymentToken,
        uint64 expiry
    ) external returns (uint256 listingId) {
        listingId = _createERC1155Listing(token, assetId, amount, unitPrice, paymentToken, expiry);
    }

    function createERC721Listing(
        address token,
        uint256 assetId,
        uint256 totalPrice,
        PaymentToken paymentToken,
        uint64 expiry
    ) external nonReentrant returns (uint256 listingId) {
        if (totalPrice == 0) revert InvalidValue();
        _requirePaymentToken(paymentToken);

        CollectionConfig memory cfg = _collectionConfig(token);
        if (!cfg.enabled || cfg.standard != AssetStandard.ERC721) {
            revert InvalidCollection(token);
        }
        if (expiry != 0 && expiry <= block.timestamp) revert InvalidValue();

        IERC721(token).safeTransferFrom(msg.sender, address(this), assetId);

        listingId = nextListingId++;
        listingOf[listingId] = Listing({
            id: listingId,
            seller: msg.sender,
            assetToken: token,
            assetId: assetId,
            amountTotal: 1,
            amountRemaining: 1,
            unitPrice: totalPrice,
            createdAt: uint64(block.timestamp),
            expiry: expiry,
            paymentToken: paymentToken,
            assetStandard: AssetStandard.ERC721,
            assetClass: cfg.assetClass,
            state: ListingState.Active
        });

        listingsBySeller[msg.sender].push(listingId);

        emit ListingCreatedV2(
            listingId,
            msg.sender,
            token,
            assetId,
            1,
            totalPrice,
            paymentToken,
            AssetStandard.ERC721,
            cfg.assetClass,
            expiry
        );
    }

    function cancelListing(uint256 listingId) external nonReentrant {
        _cancelListing(listingId, false);
    }

    function reclaimExpiredListing(uint256 listingId) external nonReentrant {
        _cancelListing(listingId, true);
    }

    function buyListing(uint256 listingId, uint256 amountToBuy) external nonReentrant {

        Listing storage listing = listingOf[listingId];
        _syncListingState(listing);

        if (listing.state != ListingState.Active) {
            revert ListingExpiredOrUnavailable(listingId);
        }
        if (listing.seller == msg.sender) revert SelfPurchase();

        uint256 buyAmount = _validateBuyAmount(listing, amountToBuy);
        uint256 totalPrice = buyAmount * listing.unitPrice;

        (IERC20 paymentToken, address treasury) = _paymentTokenAndTreasury(listing.paymentToken);
        uint256 protocolFee = (totalPrice * protocolFeeBps) / MAX_BPS;
        uint256 sellerProceeds = totalPrice - protocolFee;

        if (protocolFee > 0) {
            paymentToken.safeTransferFrom(msg.sender, treasury, protocolFee);
        }
        paymentToken.safeTransferFrom(msg.sender, listing.seller, sellerProceeds);

        _transferAssetOut(listing, msg.sender, buyAmount);

        listing.amountRemaining -= buyAmount;
        if (listing.amountRemaining == 0) {
            listing.state = ListingState.SoldOut;
        }

        emit ListingPurchased(listingId, msg.sender, buyAmount, totalPrice);
        emit ListingFilled(listingId, msg.sender, buyAmount, totalPrice, protocolFee, sellerProceeds);

        _awardTradePoints(msg.sender, listing.seller, totalPrice);
    }

    function getSellerListings(address seller) external view returns (uint256[] memory) {
        return listingsBySeller[seller];
    }

    function isListingActive(uint256 listingId) external view returns (bool) {
        Listing memory listing = listingOf[listingId];
        if (listing.state != ListingState.Active) return false;
        if (listing.expiry != 0 && block.timestamp > listing.expiry) return false;
        return true;
    }

    function _createERC1155Listing(
        address token,
        uint256 assetId,
        uint256 amount,
        uint256 unitPrice,
        PaymentToken paymentToken,
        uint64 expiry
    ) internal nonReentrant returns (uint256 listingId) {
        if (amount == 0 || unitPrice == 0) revert InvalidValue();
        _requirePaymentToken(paymentToken);

        CollectionConfig memory cfg = _collectionConfig(token);
        if (!cfg.enabled || cfg.standard != AssetStandard.ERC1155) {
            revert InvalidCollection(token);
        }
        if (expiry != 0 && expiry <= block.timestamp) revert InvalidValue();

        IERC1155(token).safeTransferFrom(msg.sender, address(this), assetId, amount, "");

        listingId = nextListingId++;
        listingOf[listingId] = Listing({
            id: listingId,
            seller: msg.sender,
            assetToken: token,
            assetId: assetId,
            amountTotal: amount,
            amountRemaining: amount,
            unitPrice: unitPrice,
            createdAt: uint64(block.timestamp),
            expiry: expiry,
            paymentToken: paymentToken,
            assetStandard: AssetStandard.ERC1155,
            assetClass: cfg.assetClass,
            state: ListingState.Active
        });

        listingsBySeller[msg.sender].push(listingId);

        if (cfg.assetClass == AssetClass.Resource && token == _resourceTokenAddress()) {
            emit ListingCreated(listingId, msg.sender, assetId, amount, unitPrice, paymentToken);
        }

        emit ListingCreatedV2(
            listingId,
            msg.sender,
            token,
            assetId,
            amount,
            unitPrice,
            paymentToken,
            AssetStandard.ERC1155,
            cfg.assetClass,
            expiry
        );
    }

    function _cancelListing(uint256 listingId, bool requireExpired) internal {
        Listing storage listing = listingOf[listingId];
        _syncListingState(listing);

        if (listing.seller != msg.sender) revert NotSeller();
        if (requireExpired) {
            if (listing.state != ListingState.Expired) revert ListingNotActive(listingId);
        } else if (listing.state != ListingState.Active && listing.state != ListingState.Expired) {
            revert ListingNotActive(listingId);
        }

        uint256 remaining = listing.amountRemaining;
        listing.state = ListingState.Cancelled;
        if (remaining > 0) {
            _transferAssetOut(listing, msg.sender, remaining);
        }

        emit ListingCancelled(listingId);
    }

    function _requirePaymentToken(PaymentToken paymentToken) internal pure {
        if (paymentToken != PaymentToken.INPI && paymentToken != PaymentToken.PIT) {
            revert InvalidPaymentToken();
        }
    }

    function _collectionConfig(address token) internal view returns (CollectionConfig memory cfg) {
        cfg = collectionConfigOf[token];
        if (cfg.enabled) {
            return cfg;
        }

        address resourceToken = _resourceTokenAddress();
        if (token == resourceToken && resourceToken != address(0)) {
            return CollectionConfig({
                enabled: true,
                standard: AssetStandard.ERC1155,
                assetClass: AssetClass.Resource
            });
        }
    }

    function _syncListingState(Listing storage listing) internal {
        if (listing.id == 0) revert ListingExpiredOrUnavailable(0);
        if (
            listing.state == ListingState.Active &&
            listing.expiry != 0 &&
            block.timestamp > listing.expiry
        ) {
            listing.state = ListingState.Expired;
            emit ListingExpired(listing.id);
        }
    }

    function _validateBuyAmount(Listing storage listing, uint256 amountToBuy) internal view returns (uint256) {
        if (listing.assetStandard == AssetStandard.ERC721) {
            if (amountToBuy != 1 || listing.amountRemaining != 1) {
                revert InvalidBuyAmount(amountToBuy, listing.amountRemaining);
            }
            return 1;
        }

        if (amountToBuy == 0 || amountToBuy > listing.amountRemaining) {
            revert InvalidBuyAmount(amountToBuy, listing.amountRemaining);
        }
        return amountToBuy;
    }

    function _transferAssetOut(Listing storage listing, address to, uint256 amount) internal {
        if (listing.assetStandard == AssetStandard.ERC1155) {
            IERC1155(listing.assetToken).safeTransferFrom(address(this), to, listing.assetId, amount, "");
            return;
        }

        IERC721(listing.assetToken).safeTransferFrom(address(this), to, listing.assetId);
    }

    function _paymentTokenAndTreasury(PaymentToken paymentToken)
        internal
        view
        returns (IERC20 token, address treasury)
    {
        address paymentTokenAddress;
        if (paymentToken == PaymentToken.INPI) {
            paymentTokenAddress = cityConfig.getAddressConfig(cityConfig.KEY_INPI());
        } else if (paymentToken == PaymentToken.PIT) {
            paymentTokenAddress = cityConfig.getAddressConfig(cityConfig.KEY_PITRONE());
        } else {
            revert InvalidPaymentToken();
        }

        if (paymentTokenAddress == address(0)) revert InvalidConfig();
        treasury = cityConfig.getAddressConfig(cityConfig.KEY_TREASURY());
        if (protocolFeeBps > 0 && treasury == address(0)) revert InvalidConfig();

        token = IERC20(paymentTokenAddress);
    }

    function _resourceTokenAddress() internal view returns (address) {
        return cityConfig.getAddressConfig(cityConfig.KEY_RESOURCE_TOKEN());
    }

    function _awardTradePoints(address buyer, address seller, uint256 totalPrice) internal {
        if (cityPoints == address(0) || tradePointsUnit == 0 || tradePointsPerUnit == 0) {
            return;
        }

        uint256 points = (totalPrice / tradePointsUnit) * tradePointsPerUnit;
        if (points == 0) return;

        try ICityPoints(cityPoints).addPoints(buyer, points, CATEGORY_TRADE_POINTS) {} catch {}
        try ICityPoints(cityPoints).addPoints(seller, points, CATEGORY_TRADE_POINTS) {} catch {}
    }
}
