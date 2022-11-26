pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./IERC4907.sol";

contract SZooNFT is ERC721URIStorage, ERC721Burnable, AccessControl, IERC4907 {
    using Counters for Counters.Counter;
    address vaultContract;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    Counters.Counter private _tokenIdCounter;

    struct UserInfo {
    address user; // address of user role
    uint64 expires; // unix timestamp, user expires
    }

    mapping(uint256 => UserInfo) internal _users;

    constructor(address vault) ERC721("SocialZoo", "SZOO") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        vaultContract = vault;
    }

    function safeMint(address to, string memory uri) public onlyRole(MINTER_ROLE) returns (uint){
        uint256 newTokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, newTokenId);
        _setTokenURI(newTokenId, uri);
        setApprovalForAll(vaultContract, true);
        return newTokenId;
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
      return
        interfaceId == type(IERC4907).interfaceId ||
        super.supportsInterface(interfaceId);
    }
    
    /// @notice set the user and expires of a NFT
    /// @dev The zero address indicates there is no user
    /// Throws if `tokenId` is not valid NFT
    /// @param user  The new user of the NFT
    /// @param expires  UNIX timestamp, The new user could use the NFT before expires
    function setUser(uint256 tokenId, address user, uint64 expires) public virtual override {
      require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
      UserInfo storage info = _users[tokenId];
      info.user = user;
      info.expires = expires;
      emit UpdateUser(tokenId, user, expires);
    }

    /// @notice Get the user address of an NFT
    /// @dev The zero address indicates that there is no user or the user is expired
    /// @param tokenId The NFT to get the user address for
    /// @return The user address for this NFT
    function userOf(uint256 tokenId) public view virtual override returns (address){
      if (uint256(_users[tokenId].expires) >= block.timestamp) {
        return _users[tokenId].user;
      } else {
        return address(0);
      }
    }

    /// @notice Get the user expires of an NFT
    /// @dev The zero value indicates that there is no user
    /// @param tokenId The NFT to get the user expires for
    /// @return The user expires for this NFT
    function userExpires(uint256 tokenId)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _users[tokenId].expires;
    }  

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
      super._beforeTokenTransfer(from, to, tokenId);

      if (from != to && _users[tokenId].user != address(0)) {
        delete _users[tokenId];
        emit UpdateUser(tokenId, address(0), 0);
      }
    }
}