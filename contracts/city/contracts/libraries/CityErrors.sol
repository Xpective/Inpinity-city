// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library CityErrors {
    error ZeroAddress();
    error InvalidValue();
    error InvalidPlotType();
    error InvalidFaction();
    error InvalidPlotStatus();
    error PlotAlreadyExists();
    error PlotNotFound();
    error NotPlotOwner();
    error PlotSlotOccupied();
    error MaxPersonalPlotsReached();
    error InvalidConfig();
}