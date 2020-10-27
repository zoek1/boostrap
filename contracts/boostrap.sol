pragma solidity >=0.4.22 <0.7.0;


import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

contract Boostrap is IERC721Receiver {
    struct Lender {
        uint start;
        address payable owner;
        uint tokenId;
        address contractAddress;
        uint lendingPrice;
        bool available;
    }

    struct Requester {
        address requester;
        uint period;
        uint start;
    }

    // Data info of the transferred tokens
    Lender[] public nfts;
    // All transfered tokens
    mapping (bytes32 => uint) hashes;

    // Current tokens lended
    mapping (bytes32 => Requester) lends;

    // Tokens lended by address
    mapping (address => uint[]) lenders;
    // Tokens requested by address
    mapping (address => uint[]) requesters;

    event Tokens(address _address, uint tokenId, address contractAddress, uint lendingPrice);
    event Lend(address _address, uint tokenId, address contractAddress, uint period, uint price);

    function onERC721Received(address, address, uint256, bytes calldata) external override returns(bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

    constructor() public {
        Lender memory lend = Lender(now, address(0x0), 0, address(0x0), 0, false);
        nfts.push(lend);
    }


    function lendToken(address payable _address, uint tokenId, address contractAddress, uint lendingPrice) public {
        IERC721 nftContract = IERC721(contractAddress);
        bytes32 hash = keccak256(abi.encodePacked(contractAddress, tokenId));
        Lender memory lend = Lender(now, _address, tokenId, contractAddress, lendingPrice, true);

        require(hashes[hash] == 0, "Token already lended");

        // nftContract.safeTransferFrom(_address, address(this), tokenId);
        nfts.push(lend);
        // lenders[_address].append(nfts.length);
        hashes[hash] = nfts.length - 1;

        emit Tokens(_address, tokenId, contractAddress, lendingPrice);

    }


    function requestToken(uint tokenId, address contractAddress, uint period) public payable {
        bytes32 hash = keccak256(abi.encodePacked(contractAddress, tokenId));
        Requester storage lend = lends[hash];
        uint index = hashes[hash];
        Lender storage token = nfts[index];

        require(hashes[hash] != 0, "Token doesn't exist");
        require((now + period) > now, "Period should be greater than 0");
        require((lend.start + lend.period) < now, "The token isn't available");
        require(msg.value == (token.lendingPrice * period), string(abi.encodePacked("The amount doesn't match math amount", (token.lendingPrice * period))));

        // Transfer value
        //token.owner.transfer(token.lendingPrice * period);

        lend.requester = msg.sender;
        lend.start = now;
        lend.period = period;

        emit Lend(msg.sender, tokenId, token.contractAddress, lend.period, token.lendingPrice * period);
    }

    function unlend(uint tokenId, address contractAddress) public {
        bytes32 hash = keccak256(abi.encodePacked(contractAddress, tokenId));
        uint256 index = hashes[hash];
        Requester storage lend = lends[hash];
        Lender storage  token = nfts[index];
        IERC721 nftContract = IERC721(contractAddress);

        hashes[hash] = 0;

        require(msg.sender == token.owner, "Wrong owner");
        require((lend.start + lend.period) < now, "The token is lended");
        // nftContract.safeTransferFrom(address(this), msg.sender, tokenId);
    }

    function hasPermission(uint tokenId, address contractAddress, address requester) public view returns (bool) {
        bytes32 hash = keccak256(abi.encodePacked(contractAddress, tokenId));
        Requester storage lend = lends[hash];
        Lender storage  token = nfts[hashes[hash]];

        require(hashes[hash] != 0, "Token doesn't exist");

        if (requester == lend.requester && (lend.start + lend.period) > now) {
            return true;
        }

        return false;
    }
}