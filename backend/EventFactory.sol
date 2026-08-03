// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EventFactory
 * @notice Factory contract to create and track ticketed events
 * @dev Used alongside NFTTicket for event management
 */
contract EventFactory is Ownable {

    struct Event {
        string name;
        uint256 date;
        uint256 totalTickets;
        address ticketContract;
        bool isActive;
    }

    Event[] public events;
    mapping(string => uint256) public eventNameToId;

    event EventCreated(uint256 indexed eventId, string name, uint256 date);
    event EventStatusChanged(uint256 indexed eventId, bool isActive);

    constructor() Ownable(msg.sender) {}

    function createEvent(
        string memory name,
        uint256 date,
        uint256 totalTickets,
        address ticketContract
    ) external onlyOwner returns (uint256) {
        uint256 eventId = events.length;

        events.push(Event({
            name: name,
            date: date,
            totalTickets: totalTickets,
            ticketContract: ticketContract,
            isActive: true
        }));

        eventNameToId[name] = eventId;

        emit EventCreated(eventId, name, date);
        return eventId;
    }

    function toggleEventStatus(uint256 eventId) external onlyOwner {
        require(eventId < events.length, "Event does not exist");
        events[eventId].isActive = !events[eventId].isActive;
        emit EventStatusChanged(eventId, events[eventId].isActive);
    }

    

    function getEvent(uint256 eventId) external view returns (Event memory) {
        require(eventId < events.length, "Event does not exist");
        return events[eventId];
    }
}
