// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Base URI
    string private _baseURIextended;

    // Mapping from token ID to owner address
    mapping(uint256 => address) internal _owners;

    // Mapping owner address to token count
    mapping(address => uint256) internal _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(),".json")) : "ipfs://QmNcwxnVMRZMGGbDqEM6KUZWGgMDWfJLeJbnQgPFNJ6Z7K";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return _baseURIextended;
    }

    /**
    * @dev Updating the Base URI from main contract. It will change the URI for
    * each token. 
    */
    function setBaseURI(string memory baseURI_) internal virtual {
        _baseURIextended = baseURI_;
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enumerable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}

abstract contract ERC721Royalty is ERC2981, ERC721Enumerable {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {ERC721-_burn}. This override additionally clears the royalty information for the token.
     */
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);
        _resetTokenRoyalty(tokenId);
    }
}

abstract contract ContextMixin {
    function msgSender()
        internal
        view
        returns (address payable sender)
    {
        if (msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
                sender := and(
                    mload(add(array, index)),
                    0xffffffffffffffffffffffffffffffffffffffff
                )
            }
        } else {
            sender = payable(msg.sender);
        }
        return sender;
    }
}


interface IAstroSapiens_NFT {

    function withdraw() external;

    function AllowSaleAction() external;

    function VIPSaleAction() external;

    function VIPSale2Action() external;

    function GiftList(uint256 _start, uint256 end) external;

    function OnwershipChange(address _newOnwer) external;
}

contract AstroSapiens_NFT is ERC721Royalty, Ownable, ContextMixin, ReentrancyGuard, AccessControl {

    using SafeMath for uint256;
    using Strings for uint256;
    using Counters for Counters.Counter;

    address MultiSigWallet;

    Counters.Counter private _tokenIds;

    uint256 public MAX_QTY = 10500; // Maximum NFT minted

    uint256 public MAX_VIP_Allow_List = 10000; // Maximum NFT minted

    uint256 public price = 1 ether; // NFT PRICE

    uint96 public royaltyPer = 1000; // Royalty Percentage

    bool public _saleStatus; // Show Current Sale status VIP

    bool public _saleStatus2; // Show Current Sale status VIP

    bool public _saleStatus3; // Show Current Sale status Allow

    // To increment the vip and allow list
    uint256 public totalMintedNumber = 0;

    mapping(address=>uint) public isVIPlist; // USER VIP LIST WALLET ADDRESS

    mapping(address=>uint) public isVIPlist2; // USER SECOND VIP LIST WALLET ADDRESS

    mapping(address=>uint) public isAllowlist; // USER Allow LIST WALLET ADDRESS

    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant ADDING_LIST_ROLE = keccak256("DEVELOPER_ROLE");
    bytes32 public constant FEE_CHANGER_ROLE = keccak256("FEE_CHANGER_ROLE");

    constructor() ERC721("AstroSapiens","ASTRO") {
        _grantRole(URI_SETTER_ROLE, msg.sender);
        _grantRole(ADDING_LIST_ROLE, msg.sender);
        _grantRole(FEE_CHANGER_ROLE, msg.sender);
    }

    event Gifted(address indexed sender, uint256 nftStart, uint256 nftEnd);
    event AllowedMint(address indexed sender, uint256 count, uint256 charge);
    event VIPMint(address indexed sender, uint256 count, uint256 charge);
    event VIP2Mint(address indexed sender, uint256 count, uint256 charge);
    event WithdrawFee(address indexed sender, uint256 amount);
    event AllowSaleMode(address indexed sender, bool status);
    event VIPSaleMode(address indexed sender, bool status);
    event VIP2SaleMode(address indexed sender, bool status);
    event NewPrice(address indexed sender, uint256 amount);
    event NewRoyalty(address indexed sender, uint256 NewPercentage);
    event NewBaseURI(address indexed sender, string NewURI);
    event Receive(address, uint);

    receive() external payable {
        emit Receive(msg.sender, msg.value);
    }

    modifier saleFlip() {
        require(_saleStatus, "VIP list Sale has not been started");
        _;
    }

    modifier saleFlip2() {
        require(_saleStatus2, "VIP list2 Sale has not been started");
        _;
    }

    modifier saleFlip3() {
        require(_saleStatus3, "Allow list Sale has not been started");
        _;
    }

    // @dev Withdraw in wei by owner of the Contract
    function withdraw() external {
        require(msg.sender == MultiSigWallet, "Calller is not the Owner");
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
        emit WithdrawFee(msg.sender, balance);
    }

    function AddMultiWallet(address _multiSign) public onlyRole(FEE_CHANGER_ROLE) {
        MultiSigWallet = _multiSign;
    }

    // @dev override ERC721 transfer function for implementing EIP2981 Royalty
    function _transfer(address from, address to, uint256 tokenId) internal override(ERC721) virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        ERC721._balances[from] -= 1;
        ERC721._balances[to] += 1;
        ERC721._owners[tokenId] = to;
        _resetTokenRoyalty(tokenId);
        _setTokenRoyalty(tokenId, to, royaltyPer);

        emit Transfer(from, to, tokenId);
        
        _afterTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Royalty, AccessControl) returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    //  @dev Start/Stop VIP list sale
    function VIPSaleAction() external {
        require(msg.sender == MultiSigWallet, "Caller is not the Owner");
        _saleStatus = !_saleStatus;
        emit VIPSaleMode(msg.sender, _saleStatus);
    }

    //  @dev Start/Stop VIP2 list sale
    function VIPSale2Action() external {
        require(msg.sender == MultiSigWallet, "Caller is not the Owner");
        _saleStatus2 = !_saleStatus2;
        emit VIP2SaleMode(msg.sender, _saleStatus);
    }
    
    //  @dev Start/Stop Allow list sale
    function AllowSaleAction() external {
        require(msg.sender == MultiSigWallet, "Caller is not the Owner");
        _saleStatus3 = !_saleStatus3;
        emit AllowSaleMode(msg.sender, _saleStatus);
    }

    // @dev Change mint NFT price in wei 
    function priceChange(uint256 _price) public onlyRole(FEE_CHANGER_ROLE) {
        price = _price;
        emit NewPrice(msg.sender, price);
    }

    // @dev Change Royalty Percentage
    function setRoyaltyPer(uint96 _royaltyPer) public onlyRole(FEE_CHANGER_ROLE) {
        require(_royaltyPer <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        royaltyPer = _royaltyPer;
        emit NewRoyalty(msg.sender, royaltyPer);
    }

    // @dev Update baseURI
     function _setBaseURI(string memory baseURI) public onlyRole(URI_SETTER_ROLE) {
        setBaseURI(baseURI);
        emit NewBaseURI(msg.sender, baseURI);
    }

    function isApprovedForAll(address _owner, address _operator) public override view returns (bool isOperator) {
      // if OpenSea's ERC721 Proxy Address is detected, auto-return true
      // for Polygon's Mumbai testnet, use 0xff7Ca10aF37178BdD056628eF42fD7F799fAc77c
      // for Polygon Mainnet, use 0x58807baD0B376efc12F5AD86aAc70E78ed67deaE
        if (_operator == address(0xff7Ca10aF37178BdD056628eF42fD7F799fAc77c)) {
            return true;
        }
        
        // otherwise, use the default ERC721.isApprovedForAll()
        return ERC721.isApprovedForAll(_owner, _operator);
    }

    function _msgSender() internal override view returns (address sender) {
        return ContextMixin.msgSender();
    }

    // @dev Add wallet address of VIPList
    function addVIPList(address[] memory _users) public onlyRole(ADDING_LIST_ROLE) nonReentrant {
        for (uint i = 0; i < _users.length; i++) {
            isVIPlist[_users[i]] = 0;
        }
    }

    // @dev Add wallet address of VIPList2
    function addVIPList2(address[] memory _users) public onlyRole(ADDING_LIST_ROLE) nonReentrant {
        for (uint i = 0; i < _users.length; i++) {
            isVIPlist2[_users[i]] = 0;
        }
    }

    // @dev Add wallet address of AllowList
    function addAllowList(address[] memory _users) public onlyRole(ADDING_LIST_ROLE) nonReentrant {
        for (uint i = 0; i < _users.length; i++) {
            isAllowlist[_users[i]] = 0;
        }
    }

    // @dev Only wallet addres added in addVIPList added able to mint
    function VIPList() public saleFlip nonReentrant payable {
        require(totalMintedNumber.add(2) <= MAX_VIP_Allow_List, "Max limit of NFTs");
        require(msg.value >= price.mul(2), "Ether value sent is not correct");
        require(isVIPlist[msg.sender].add(2) <= 2, "User exceed Max limit");
        for(uint i = 0; i < 2; i++) {
            uint256 newItemId = _tokenIds.current();
            _safeMint(msg.sender, newItemId+1);
            _setTokenRoyalty(newItemId+1, msg.sender, royaltyPer);
            _tokenIds.increment();
        }
        isVIPlist[msg.sender] += 2;
        totalMintedNumber += 2;
        emit VIPMint(msg.sender, 2, msg.value);
    }

    // @dev Only wallet addres added in addVIPList added able to mint
    function VIPList2(uint256 numberOfTokens) public saleFlip2 nonReentrant payable {
        require(numberOfTokens > 0,"Zero is not allowed");
        require(totalMintedNumber.add(numberOfTokens) <= MAX_VIP_Allow_List, "Max limit of NFTs");
        require(msg.value >= price.mul(numberOfTokens), "Ether value sent is not correct");
        require(isVIPlist2[msg.sender].add(numberOfTokens) <= 2, "User exceed Max limit");
        for(uint i = 0; i < numberOfTokens; i++) {
            uint256 newItemId = _tokenIds.current();
            _safeMint(msg.sender, newItemId+1);
            _setTokenRoyalty(newItemId+1, msg.sender, royaltyPer);
            _tokenIds.increment();
        }
        isVIPlist2[msg.sender] += numberOfTokens;
        totalMintedNumber += numberOfTokens;
        emit VIP2Mint(msg.sender, numberOfTokens, msg.value);
    }


    // @dev Only wallet addres added in addAllowList added able to mint
    function AllowList(uint256 numberOfTokens) public saleFlip3 nonReentrant payable {
        require(numberOfTokens > 0,"Zero is not allowed");
        require(totalMintedNumber.add(numberOfTokens) <= MAX_VIP_Allow_List, "Max limit of NFTs");
        require(msg.value >= price.mul(numberOfTokens), "Ether value sent is not correct");
        require(isAllowlist[msg.sender].add(numberOfTokens) <= 5, "User exceed Max limit");
        for(uint i = 0; i < numberOfTokens; i++) {
            uint256 newItemId = _tokenIds.current();
            _safeMint(msg.sender, newItemId+1);
            _setTokenRoyalty(newItemId+1, msg.sender, royaltyPer);
            _tokenIds.increment();
        }
        isAllowlist[msg.sender] += numberOfTokens;
        totalMintedNumber += numberOfTokens;
        emit AllowedMint(msg.sender, numberOfTokens, msg.value);
    }

    // @dev Owner has reserve few new
    function GiftList(uint256 _startingNumber, uint256 _endNumber) external onlyOwner nonReentrant {
        require(_startingNumber > 10000, "Lower Number should be more than 10000");
        require(_endNumber <= 10500, "Lower Number should be more than 10000");
        for(uint256 i = _startingNumber; i <= _endNumber; i++) {
            _safeMint(msg.sender, i);
            _setTokenRoyalty(i, msg.sender, royaltyPer);
        }
        emit Gifted(msg.sender, _startingNumber, _endNumber);
    }

    function OnwershipChange(address _newOnwer) external onlyOwner nonReentrant {
        transferOwnership(_newOnwer);
    }
}
