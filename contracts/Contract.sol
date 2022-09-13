// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/base/ERC721Drop.sol";
import "@thirdweb-dev/contracts/extension/PlatformFee.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Contract is ERC721Drop, PlatformFee, VRFConsumerBaseV2{
    VRFCoordinatorV2Interface COORDINATOR;
    address vrfCoordinator = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;

    bytes32 keyHash = 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;
    uint32 callbackGasLimit = 2500000; 
    uint16 requestConfirmations = 316;
    uint32 numWords =  10;

    mapping (uint256 => string) private _uris;
    mapping(uint256 => address) public s_requestIdToUserAddress;
    uint256[] private s_randomWords;
    uint256 private s_requestId;
    uint256 private s_tokenId;
    uint64 public s_subscriptionId;
    address s_owner;
    uint256 public remaining;    
    mapping(uint256 => uint256) private movedCards;

    constructor(
        string memory _name,
        string memory _symbol,
        address _royaltyRecipient,
        uint128 _royaltyBps,
        address _primarySaleRecipient,
        uint64 subscriptionId
    )
        ERC721Drop(
            _name,
            _symbol,
            _royaltyRecipient,
            _royaltyBps,
            _primarySaleRecipient
        )
        VRFConsumerBaseV2(vrfCoordinator)
    {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
        // The number of cards in the deck
        remaining = 10; 
    }
    function _canSetPlatformFeeInfo() internal view override returns (bool) {
        return msg.sender == owner();
    }
    function cardAt(uint256 i) private view returns (uint256){
        if (movedCards[i] != 0) {
            return movedCards[i];
        } else {
            return i;
        }
    }

    // Draw another "card" without replacement
    function _draw(uint256 randomTokenId) private returns (uint256) {
        require(remaining > 0, "All cards drawn");
        uint256 i = randomTokenId;
        uint256 outCard = cardAt(i);
        movedCards[i] = cardAt(remaining - 1);
        movedCards[remaining - 1] = 0;
        remaining -= 1;
        return outCard;
    }

    function _mintTo(address owner, uint256 randomTokenId) private {
        _mint(owner, _draw(randomTokenId));
    }

    function uri(uint256 tokenId) public view returns (string memory) {
        return(_uris[tokenId]);
    }
    
    function setTokenUri(uint256 tokenId, string memory newUri) public onlyOwner {
        require(bytes(_uris[tokenId]).length == 0, "Cannot set uri twice"); 
        _uris[tokenId] = newUri; 
    }
    
    // Assumes the subscription is funded sufficiently.
    function requestRandomWords() external onlyOwner {
        s_requestId = COORDINATOR.requestRandomWords(
        keyHash,
        s_subscriptionId,
        requestConfirmations,
        callbackGasLimit,
        numWords
        );
        require(remaining > 0, "All cards drawn");
        s_requestIdToUserAddress[s_requestId] = msg.sender;
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        s_randomWords = randomWords;
        s_tokenId = (s_randomWords[0] % remaining);          
        _mintTo(s_requestIdToUserAddress[requestId], s_tokenId); 
    }
}