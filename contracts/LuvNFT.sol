pragma solidity >=0.4.22 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./GenerativeNFT.sol";

library IterableMapping {
    // Iterable mapping from address to uint;
    struct Map {
        address[] keys;
        mapping(address => uint256) values;
        mapping(address => uint256) indexOf;
        mapping(address => bool) inserted;
    }

    function get(Map storage map, address key) public view returns (uint256) {
        return map.values[key];
    }

    function getKeyAtIndex(Map storage map, uint256 index)
        public
        view
        returns (address)
    {
        return map.keys[index];
    }

    function size(Map storage map) public view returns (uint256) {
        return map.keys.length;
    }

    function set(
        Map storage map,
        address key,
        uint256 val
    ) public {
        if (map.inserted[key]) {
            map.values[key] = val;
        } else {
            map.inserted[key] = true;
            map.values[key] = val;
            map.indexOf[key] = map.keys.length;
            map.keys.push(key);
        }
    }

    function remove(Map storage map, address key) public {
        if (!map.inserted[key]) {
            return;
        }

        delete map.inserted[key];
        delete map.values[key];

        uint256 index = map.indexOf[key];
        uint256 lastIndex = map.keys.length - 1;
        address lastKey = map.keys[lastIndex];

        map.indexOf[lastKey] = index;
        delete map.indexOf[key];

        map.keys[index] = lastKey;
        map.keys.pop();
    }
}

contract LuvNFT is ERC721, Ownable {
    using IterableMapping for IterableMapping.Map;

    constructor() public ERC721("WorldNFT", "WNFT") {}

    struct Location {
        string nft_info; //contains name, long and lati
        bool isExist;
    }
    struct Auction {
        uint256 tokenId;
        address beneficiary;
        bool auctionGoingOn;
        bool auctionEnded;
        uint256 auctionEndTime;
        uint256 biddingTime;
        address highestBidder;
        uint256 highestBid;
        bool isExist;
    }
    struct Bid {
        uint256 tokenId;
        address bidder;
        uint256 bidValue;
        uint256 timeBid;
    }

    uint256 public nextId = 0;
    uint256 public acceptedBidsIdx = 0;

    event NftBought(address _seller, address _buyer, uint256 _price);
    event AuctionStarted(address ownerAddress, uint256 _biddingTime);
    event BidIncrease(address bidAddress, uint256 bidValue);
    event AuctionEnded(address bidAddress, uint256 bidValue);
    event BidRejected(address bidAddress, uint256 bidValue);
    event BidWithdrawn(address bidAddress, uint256 bidValue);
    event ChangeNFTInfo(uint256 changedId);

    mapping(uint256 => Location) private _locationDetails;
    mapping(uint256 => uint256) public tokenIdToPrice;
    mapping(uint256 => Auction) private _auctions;
    mapping(uint256 => Bid) private _biddingLogs;

    // IterableMapping.Map private _pendingReturns;
    mapping(uint256 => IterableMapping.Map) private _tokenPendingReturns;

    function getTokenDetails(uint256 tokenId)
        public
        view
        returns (Location memory)
    {
        return _locationDetails[tokenId];
    }

    //create svg file automatically.
    function getSVG(
        uint256 tokenId,
        string memory latitude,
        string memory longitude,
        string memory name
    ) public view returns (string memory) {
        return
            NFTDescriptor.constructTokenURI(
                NFTDescriptor.URIParams({
                    tokenId: tokenId,
                    blockNumber: block.number,
                    latitude: latitude,
                    longitude: longitude,
                    name: name
                })
            );
    }

    function getPriceOf(uint256 tokenId) public view returns (uint256) {
        return tokenIdToPrice[tokenId];
    }

    function getOwnerOf(uint256 tokenId) public view returns (address) {
        return ownerOf(tokenId);
    }

    function getAuctionInfo(uint256 tokenId)
        public
        view
        returns (Auction memory)
    {
        return _auctions[tokenId];
    }

    function getBiddingLog(uint256 bidId) public view returns (Bid memory) {
        return _biddingLogs[bidId];
    }

    function getPendingReturnsCount(uint256 tokenId)
        public
        view
        returns (uint256)
    {
        IterableMapping.Map storage pendingReturnForIdx = _tokenPendingReturns[
            tokenId
        ];
        return pendingReturnForIdx.size();
    }

    function getPendingReturnValue(uint256 tokenId, address addr)
        public
        view
        returns (uint256)
    {
        IterableMapping.Map storage pendingReturnForIdx = _tokenPendingReturns[
            tokenId
        ];
        return pendingReturnForIdx.get(addr);
    }

    function mint(string memory nft_info, uint256 price) public onlyOwner {
        _locationDetails[nextId] = Location(nft_info, true);
        // tokenIdToPrice[nextId] = 2000000000000000000; //1 ONE=1e18 wei
        tokenIdToPrice[nextId] = price; //1 ONE=1e18 wei
        _safeMint(msg.sender, nextId);
        nextId++;
    }

    function changeNftInfo(string nft_info, uint256 tokenId) external onlyOwner {
        require(_locationDetails[_tokenId].isExist, "Token doesn't exist");
        _locationDetails[tokenId] = Location(nft_info, true);
        emit ChangeNFTInfo(tokenId);
    }

    function buy(uint256 _tokenId) external payable {
        uint256 price = tokenIdToPrice[_tokenId];
        require(price > 0, "This token is not for sale");
        require(msg.value == price, "Incorrect value");
        address seller = ownerOf(_tokenId);
        _transfer(seller, msg.sender, _tokenId);
        tokenIdToPrice[_tokenId] = 0;
        payable(seller).transfer(msg.value);
        emit NftBought(seller, msg.sender, msg.value);
    }

    function startAuction(uint256 _tokenId, uint256 _biddingTime) external {
        uint256 auctionEndTime = block.timestamp + _biddingTime;
        require(_locationDetails[_tokenId].isExist, "Token doesn't exist");
        require(
            msg.sender == ownerOf(_tokenId),
            "Cannot start auction for token you don't own"
        );
        if (_auctions[_tokenId].isExist && !_auctions[_tokenId].auctionEnded) {
            revert("The auction has not ended yet");
        }
        _auctions[_tokenId] = Auction(
            _tokenId,
            msg.sender,
            true,
            false,
            auctionEndTime,
            _biddingTime,
            address(0x0),
            0,
            true
        );
        emit AuctionStarted(msg.sender, _biddingTime);
    }

    function endAuction(uint256 _tokenId) external {
        Auction memory auc = getAuctionInfo(_tokenId);
        require(auc.isExist, "Auction doesn't exist");
        if (block.timestamp < auc.auctionEndTime) {
            revert("The auction has not ended yet");
        }
        if (auc.auctionEnded) {
            revert("The auction has ended");
        }
        IterableMapping.Map storage pr = _tokenPendingReturns[_tokenId];
        if (auc.highestBid == 0) {
            auc.auctionEnded = true;
            auc.auctionGoingOn = false;
            _auctions[_tokenId] = auc;
            emit AuctionEnded(auc.highestBidder, auc.highestBid);
        } else {
            auc.auctionEnded = true;
            auc.auctionGoingOn = false;
            payable(auc.beneficiary).transfer(auc.highestBid);
            _transfer(auc.beneficiary, auc.highestBidder, _tokenId);
            auc.beneficiary = auc.highestBidder;
            _auctions[_tokenId] = auc;
            tokenIdToPrice[_tokenId] = auc.highestBid;
            pr.set(auc.highestBidder, 0);
            emit AuctionEnded(auc.highestBidder, auc.highestBid);
        }

        for (uint256 i = 0; i < pr.size(); i++) {
            address returnAddr = pr.getKeyAtIndex(i);
            uint256 returnVal = getPendingReturnValue(_tokenId, returnAddr);
            if (returnVal > 0) {
                payable(returnAddr).transfer(returnVal);
                emit BidRejected(returnAddr, returnVal);
            }
        }
    }

    function placeBid(uint256 _tokenId) external payable {
        Auction memory auc = getAuctionInfo(_tokenId);
        require(auc.isExist, "Auction doesn't exist");
        require(
            msg.value > tokenIdToPrice[_tokenId],
            "Bid price must be higher"
        );
        if (msg.value <= auc.highestBid) {
            revert("Higher bid exists");
        }
        auc.highestBid = msg.value;
        auc.highestBidder = msg.sender;
        _auctions[_tokenId] = auc;
        IterableMapping.Map storage pr = _tokenPendingReturns[_tokenId];
        pr.set(msg.sender, msg.value);
        emit BidIncrease(msg.sender, msg.value);

        //Log bid into bidHistory
        _biddingLogs[acceptedBidsIdx] = Bid(
            _tokenId,
            msg.sender,
            msg.value,
            block.timestamp
        );
        acceptedBidsIdx++;
    }

    function withdrawBid(uint256 _tokenId) external payable {
        Auction memory auc = getAuctionInfo(_tokenId);
        require(auc.isExist, "Auction doesn't exist");
        IterableMapping.Map storage pr = _tokenPendingReturns[_tokenId];
        uint256 nextHighestBid = 0;
        for (uint256 i = 0; i < pr.size(); i++) {
            address returnAddr = pr.getKeyAtIndex(i);
            uint256 returnVal = getPendingReturnValue(_tokenId, returnAddr);
            if (returnVal > 0) {
                if (returnAddr == msg.sender) {
                    payable(returnAddr).transfer(returnVal);
                    pr.remove(returnAddr);
                    emit BidWithdrawn(returnAddr, returnVal);
                } else {
                    if (nextHighestBid < returnVal) {
                        auc.highestBid = returnVal;
                        auc.highestBidder = returnAddr;
                        nextHighestBid = returnVal;
                    }
                }
            }
        }
        if (nextHighestBid == 0) {
            auc.highestBid = 0;
            auc.highestBidder = address(0);
        }
        //set highest bid as the next highest
        _auctions[_tokenId] = auc;
    }

    function increaseBid(uint256 _tokenId) external payable {
        
    }

    // function setPrice(uint256 _tokenId) external payable {
        
    // }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {}
}
