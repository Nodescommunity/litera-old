
// SPDX-License-Identifier: MIT
// 0x25c.com
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract Litera is ERC1155, Ownable {
    using Strings for uint256;
    string private _collectionName;
    string private _tokenSymbol;

    mapping(uint256 => string) private _tokenURIs;
    uint256 private _tokenCounter;

    address private _proxyOwner;

    constructor(string memory baseURI, string memory collectionName, string memory tokenSymbol) ERC1155(baseURI) {
        _proxyOwner = _msgSender();
        _collectionName = collectionName; // Set the collection name
        _tokenSymbol = tokenSymbol;
    }

    modifier onlyProxyOwner() {
        require(_msgSender() == _proxyOwner, "ERC1155NFT: Caller is not the proxy owner");
        _;
    }

    function setProxyOwner(address proxyOwner) external onlyOwner {
        _proxyOwner = proxyOwner;
    }

    function setTokenURI(uint256 tokenId, string memory newURI) external onlyProxyOwner {
        string memory baseURI = super.uri(tokenId);
        _tokenURIs[tokenId] = string(abi.encodePacked(baseURI, newURI));
    }


    function uri(uint256 tokenId) public view override  returns (string memory) {
        string memory ipfsCID = _tokenURIs[tokenId];
        return string(abi.encodePacked(ipfsCID));
    }

    function name() public view returns (string memory) {
        return _collectionName;
    }

    // Override the symbol function to return your desired symbol
    function symbol() public view returns (string memory) {
        return _tokenSymbol; // Replace with your desired symbol
    }


    function mint(address to, uint256 tokenId, uint256 amount, bytes memory data) external onlyProxyOwner {
        _mint(to, tokenId, amount, data);
    }

    function getLastTokenId() public view returns (uint256) {
        return _tokenCounter;
    }

    function updateTokenCounter() external onlyProxyOwner {
        _tokenCounter += 1;
    }

}

pragma solidity ^0.8.0;

contract ERC20Token {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalSupply
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalSupply * 10**uint256(decimals);
        balanceOf[msg.sender] = totalSupply;
    }

    function transfer(address _to, uint256 _value) external returns (bool) {
        require(_to != address(0), "ERC20: Invalid address");
        require(balanceOf[msg.sender] >= _value, "ERC20: Insufficient balance");

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) external returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool) {
        require(_from != address(0), "ERC20: Invalid address");
        require(_to != address(0), "ERC20: Invalid address");
        require(balanceOf[_from] >= _value, "ERC20: Insufficient balance");
        require(allowance[_from][msg.sender] >= _value, "ERC20: Not allowed to transfer");

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }
}



pragma solidity ^0.8.4;

contract Writer is Ownable {
    struct ArticleInfo {
        uint256 idnft;
        address writerAddress;
        string externalURI;
        bool fee;
        address creator;
        uint256 price;
        uint256 UserMintShared;
        uint256 CreatorMintShared;
        uint256 _MaxMinted;
        uint256 _Minted;
        string _Info;
        string _CID;
    }

    address public erc20TokenAddress; 
    address public carityaddress; 
    
    Litera public assetContract;
    mapping(address => bool) public writerWhitelist;
    mapping(address => mapping(uint256 => bool)) public hasMinted;
    mapping(string => ArticleInfo) public articleInfo;
    address public adminProxy;

    event NFTMinted(address indexed owner, uint256 tokenId, string url);
    event ArticleAdded(
    uint256 indexed idnft,
    address indexed writerAddress,
    string externalURI,
    bool fee,
    uint256 price,
    uint256 UserMintShared,
    uint256 CreatorMintShared,
    uint256 creatorShared,
    uint256 MaxMinted,
    uint256 Minted
);

event ERC20Transfer(address indexed from, address indexed to, uint256 amount);



    constructor(Litera _contractAddress, address _erc20TokenAddress, address _carityAddress) {
        assetContract = _contractAddress;
        erc20TokenAddress = _erc20TokenAddress;
        carityaddress = _carityAddress;
        adminProxy = msg.sender;
    }

    modifier onlyWhitelisted() {
        require(writerWhitelist[msg.sender], "writer: Caller is not whitelisted.");
        _;
    }


    function writerAddToWhitelist(address account) public onlyOwner {
        writerWhitelist[account] = true;
    }

    function writerRemoveFromWhitelist(address account) public onlyOwner {
        delete writerWhitelist[account];
    }

    function Mint(string memory _url, bytes memory _data) external {
        require(address(assetContract) != address(0), "AssetContract address is not set.");
        // Convert the URL string to a unique uint256 value
        uint256 urlHash = uint256(keccak256(abi.encodePacked(_url)));
        require(articleInfo[_url].idnft != 0, "URL does not exist");
        uint256 _Price = articleInfo[_url].price; 
        require(!hasMinted[msg.sender][urlHash], "writer: NFT with this URL has already been minted by the account.");
    
        
        ERC20Token erc20Token = ERC20Token(erc20TokenAddress);
        require(erc20Token.transferFrom(msg.sender, address(this), _Price), "Transfer of ERC20 tokens failed");

        hasMinted[msg.sender][urlHash] = true;
        uint256 tokenId = getIdFromArticleURL(_url);
        assetContract.mint(msg.sender, tokenId, 1, _data);
        // Increment the _Minted field in ArticleInfo by 1
        articleInfo[_url]._Minted += 1;

        // Get the creator and creatorShared from articleInfo
        address _creator = articleInfo[_url].creator;
        uint256 _creatorShared = articleInfo[_url].CreatorMintShared;
        uint256 _UserMinterReward = articleInfo[_url].UserMintShared; 
    
        if (_creatorShared > 0) {
            require(erc20Token.transfer(_creator, _creatorShared), "Transfer to creator failed");
            require(erc20Token.transfer(msg.sender, _UserMinterReward), "Transfer to Minter failed");
        }

        emit NFTMinted(msg.sender, tokenId, _url);
        emit ERC20Transfer(msg.sender, address(this), _Price);
    }


    function AdminMint(string memory _url, address _MinterAddress) public onlyWhitelisted {
        require(address(assetContract) != address(0), "AssetContract address is not set.");
        require(articleInfo[_url].idnft != 0, "URL does not exist");
        // Convert the URL string to a unique uint256 value
        uint256 urlHash = uint256(keccak256(abi.encodePacked(_url)));
        require(!hasMinted[_MinterAddress][urlHash], "writer: NFT with this URL has already been minted by the account.");
        
        hasMinted[_MinterAddress][urlHash] = true;
        uint256 tokenId = getIdFromArticleURL(_url);
        assetContract.mint(_MinterAddress, tokenId, 1, "0x");

        articleInfo[_url]._Minted += 1;

         // Get the creator and creatorShared from articleInfo
        address _creator = articleInfo[_url].creator;
        uint256 _creatorShared = articleInfo[_url].CreatorMintShared;
        uint256 _UserMinterReward = articleInfo[_url].UserMintShared; 

        if (_creatorShared > 0) {
            ERC20Token erc20Token = ERC20Token(erc20TokenAddress);
            require(erc20Token.transfer(_creator, _creatorShared), "Transfer to creator failed");
            require(erc20Token.transfer(_MinterAddress, _UserMinterReward), "Transfer to Minter failed");
        }

        emit NFTMinted(msg.sender, tokenId, _url);
    }



    function getIdFromArticleURL(string memory _url) public view returns (uint256) {
        return articleInfo[_url].idnft;
    }

    function getWriterAddressFromArticleURL(string memory _url) public view returns (address) {
        return articleInfo[_url].writerAddress;
    }

    function addArticle(
        string memory _url, 
        string memory _ipfsCID, 
        address _creator, 
        string memory _externalURI, 
        bool _Fee, 
        uint256 _price, 
        uint256 _UserMintShared, 
        uint256 _CreatorMintShared, 
        uint256 _creatorShared, 
        uint256 _MaxMinted,
        string memory _info
        ) public onlyWhitelisted {
        require(articleInfo[_url].idnft == 0, "URL already exists");
        uint256 _idnft = assetContract.getLastTokenId() + 1; 
        while (articleInfo[_url].idnft != 0) {
            _idnft++; // Increment the ID if already assigned
        }

        uint256 _Minted = 0;

        articleInfo[_url] = ArticleInfo(
            _idnft, 
            msg.sender, 
            _externalURI, 
            _Fee, 
            _creator, 
            _price, 
            _UserMintShared,
            _CreatorMintShared,
            _MaxMinted,
            _Minted,
            _info,
            _ipfsCID
            );
        
        // Set the URI for the NFT
        assetContract.setTokenURI(_idnft, _ipfsCID);
        
        // Increment the _tokenCounter by 1
        assetContract.updateTokenCounter();

         // Transfer ERC20 tokens to the creator
        ERC20Token erc20Token = ERC20Token(erc20TokenAddress);
        require(erc20Token.transfer(_creator, _creatorShared), "Transfer to creator failed");

        // Emit the ArticleAdded event
        emit ArticleAdded(
            _idnft,
            msg.sender,
            _externalURI,
            _Fee,
            _price,
            _UserMintShared,
            _CreatorMintShared,
            _creatorShared,
            _MaxMinted,
            _Minted
        );

    }

    function withdrawalfund() external onlyOwner {
        // Pastikan ada Ether yang dapat ditarik sebelum melakukan operasi berikutnya
        require(address(this).balance > 0, "Tidak ada Ether yang dapat ditarik");

        // Lakukan penarikan (withdraw) Ether
        // Jumlah Ether yang akan ditarik sesuai dengan saldo contract saat ini
        // Saldo akan dikirim ke carityaddress contract (owner)
        payable(carityaddress).transfer(address(this).balance);
    }

    function withdrawalERC20(uint256 amount) external onlyOwner {
        ERC20Token erc20Token = ERC20Token(erc20TokenAddress);

        // Check the balance of the contract
        uint256 contractBalance = erc20Token.balanceOf(address(this));
        require(contractBalance >= amount, "Insufficient ERC20 token balance");

        // Transfer ERC20 tokens to the designated address
        require(erc20Token.transfer(carityaddress, amount), "Transfer of ERC20 tokens failed");
    }

    function updateCarityAddress(address _newCarityAddress) external onlyOwner {
        carityaddress = _newCarityAddress;
    }

}



