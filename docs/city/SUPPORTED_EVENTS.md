# Supported Events

## Config
- `ConfigInitialized(address admin)`
- `CoreAddressSet(bytes32 key, address value)`
- `UintConfigSet(bytes32 key, uint256 value)`

## City Key / Faction
- `CityKeyTokenSet(address user, uint256 tokenId)`
- `FactionChosen(address user, Faction faction)`

## Plot Reservation
- `PersonalPlotReserved(address owner, uint256 plotId, uint8 slotIndex, Faction faction)`
- `CommunityPlotReserved(uint256 plotId, CommunityBuildingKind buildingKind)`

## Plot Status
- `PlotStatusUpdated(uint256 plotId, PlotStatus oldStatus, PlotStatus newStatus)`
- `ManualStatusCleared(uint256 plotId)`

## Ownership / History
- `PlotOwnerTransferred(uint256 plotId, address oldOwner, address newOwner)`
- `PlotHistoryInitialized(uint256 plotId, address firstBuilder, Faction faction, bool genesisEra)`
- `OwnershipTransferRecorded(uint256 plotId, uint32 transferCount)`
- `LayerAdded(uint256 plotId, uint32 newLayerCount)`
- `AetherUseRecorded(uint256 plotId, uint32 totalAetherUses)`

## Qubiq / Build Progress
- `QubiqContributed(uint256 plotId, uint32 x, uint32 y, address contributor, uint256 oil, uint256 lemons, uint256 iron)`
- `QubiqCompleted(uint256 plotId, uint32 x, uint32 y, bool usedAether)`
- `PlotCompleted(uint256 plotId)`
- `AetherUsed(uint256 plotId, uint32 x, uint32 y, address user)`