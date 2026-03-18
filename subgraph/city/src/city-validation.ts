import {
    OwnershipTransferred,
    SetHooksCall
  } from "../generated/CityValidation/CityValidation";
  import {
    ValidationHooks,
    CityValidationOwnershipTransferredEvent
  } from "../generated/schema";
  
  // --------------------------------------------------
  // Helpers
  // --------------------------------------------------
  
  function getOrCreateValidationHooks(): ValidationHooks {
    let entity = ValidationHooks.load("current");
  
    if (entity == null) {
      entity = new ValidationHooks("current");
      entity.cityStatus = "0x0000000000000000000000000000000000000000";
      entity.cityLand = "0x0000000000000000000000000000000000000000";
      entity.updatedAtBlock = "0";
      entity.updatedAtTimestamp = "0";
    }
  
    return entity as ValidationHooks;
  }
  
  // --------------------------------------------------
  // Call Handlers
  // --------------------------------------------------
  
  export function handleSetHooks(call: SetHooksCall): void {
    let entity = getOrCreateValidationHooks();
  
    entity.cityStatus = call.inputs.cityStatusAddress.toHexString();
    entity.cityLand = call.inputs.cityLandAddress.toHexString();
    entity.updatedAtBlock = call.block.number.toString();
    entity.updatedAtTimestamp = call.block.timestamp.toString();
    entity.save();
  }
  
  // --------------------------------------------------
  // Event Handlers
  // --------------------------------------------------
  
  export function handleOwnershipTransferred(event: OwnershipTransferred): void {
    let entity = new CityValidationOwnershipTransferredEvent(
      event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
    );
  
    entity.previousOwner = event.params.previousOwner;
    entity.newOwner = event.params.newOwner;
    entity.blockNumber = event.block.number;
    entity.timestamp = event.block.timestamp;
    entity.txHash = event.transaction.hash;
    entity.save();
  }