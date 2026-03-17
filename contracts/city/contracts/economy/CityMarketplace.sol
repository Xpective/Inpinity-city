// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../libraries/CityErrors.sol";
import "../interfaces/IResourceToken.sol";
import "../interfaces/IINPI.sol";
import "../interfaces/IPIT.sol";
import "../core/CityConfig.sol";

contract CityMarketplace is Ownable, ERC1155Holder {
    enum PaymentToken {
        None,
        INPI,
        PIT
    }

    struct Listing {
        uint256 id;
        address seller;
        uint256 resourceId;
        uint256 amount;
        uint256 unitPrice;
        PaymentToken paymentToken;
        bool active;
    }

    CityConfig public immutable cityConfig;

    uint256 public nextListingId = 1;
    mapping(uint256 => Listing) public listingOf;
    mapping(address => uint256[]) public listingsBySeller;

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

    constructor(address initialOwner, address cityConfigAddress) Ownable(initialOwner) {
        if (initialOwner == address(0) || cityConfigAddress == address(0)) {
            revert CityErrors.ZeroAddress();
        }

        cityConfig = CityConfig(cityConfigAddress);
    }

    function createListing(
        uint256 resourceId,
        uint256 amount,
        uint256 unitPrice,
        PaymentToken paymentToken
    ) external returns (uint256 listingId) {
        if (amount == 0 || unitPrice == 0) revert CityErrors.InvalidValue();
        if (paymentToken != PaymentToken.INPI && paymentToken != PaymentToken.PIT) {
            revert CityErrors.InvalidValue();
        }

        address resourceTokenAddr = cityConfig.getAddressConfig(cityConfig.KEY_RESOURCE_TOKEN());
        if (resourceTokenAddr == address(0)) revert CityErrors.InvalidConfig();

        IResourceToken(resourceTokenAddr).safeTransferFrom(
            msg.sender,
            address(this),
            resourceId,
            amount,
            ""
        );

        listingId = nextListingId++;

        listingOf[listingId] = Listing({
            id: listingId,
            seller: msg.sender,
            resourceId: resourceId,
            amount: amount,
            unitPrice: unitPrice,
            paymentToken: paymentToken,
            active: true
        });

        listingsBySeller[msg.sender].push(listingId);

        emit ListingCreated(
            listingId,
            msg.sender,
            resourceId,
            amount,
            unitPrice,
            paymentToken
        );
    }

    function cancelListing(uint256 listingId) external {
        Listing storage listing = listingOf[listingId];
        if (!listing.active) revert CityErrors.InvalidValue();
        if (listing.seller != msg.sender) revert CityErrors.NotAuthorized();

        listing.active = false;

        address resourceTokenAddr = cityConfig.getAddressConfig(cityConfig.KEY_RESOURCE_TOKEN());
        if (resourceTokenAddr == address(0)) revert CityErrors.InvalidConfig();

        IResourceToken(resourceTokenAddr).safeTransferFrom(
            address(this),
            msg.sender,
            listing.resourceId,
            listing.amount,
            ""
        );

        emit ListingCancelled(listingId);
    }

    function buyListing(uint256 listingId, uint256 amountToBuy) external {
        Listing storage listing = listingOf[listingId];
        if (!listing.active) revert CityErrors.InvalidValue();
        if (amountToBuy == 0 || amountToBuy > listing.amount) revert CityErrors.InvalidValue();

        uint256 totalPrice = amountToBuy * listing.unitPrice;

        if (listing.paymentToken == PaymentToken.INPI) {
            address inpiAddr = cityConfig.getAddressConfig(cityConfig.KEY_INPI());
            if (inpiAddr == address(0)) revert CityErrors.InvalidConfig();

            bool ok = IINPI(inpiAddr).transferFrom(msg.sender, listing.seller, totalPrice);
            if (!ok) revert CityErrors.InvalidValue();
        } else if (listing.paymentToken == PaymentToken.PIT) {
            address pitAddr = cityConfig.getAddressConfig(cityConfig.KEY_PITRONE());
            if (pitAddr == address(0)) revert CityErrors.InvalidConfig();

            bool ok = IPIT(pitAddr).transferFrom(msg.sender, listing.seller, totalPrice);
            if (!ok) revert CityErrors.InvalidValue();
        } else {
            revert CityErrors.InvalidValue();
        }

        address resourceTokenAddr = cityConfig.getAddressConfig(cityConfig.KEY_RESOURCE_TOKEN());
        if (resourceTokenAddr == address(0)) revert CityErrors.InvalidConfig();

        IResourceToken(resourceTokenAddr).safeTransferFrom(
            address(this),
            msg.sender,
            listing.resourceId,
            amountToBuy,
            ""
        );

        listing.amount -= amountToBuy;
        if (listing.amount == 0) {
            listing.active = false;
        }

        emit ListingPurchased(listingId, msg.sender, amountToBuy, totalPrice);
    }

    function getSellerListings(address seller) external view returns (uint256[] memory) {
        return listingsBySeller[seller];
    }
}