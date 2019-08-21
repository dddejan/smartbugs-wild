{"PLincSlots.sol":{"content":"pragma solidity 0.5.8;\r\n\r\nimport \"./SafeMath.sol\";\r\n\r\ncontract PLincSlots {\r\n    \r\n    using SafeMath for uint256;\r\n    \r\n    struct Spin {\r\n        uint256 betValue;\r\n        uint256 numberOfBets;\r\n        uint256 startBlock;\r\n        bool open;\r\n    }\r\n    \r\n    mapping(address =\u003e Spin) public playerSpin;\r\n    \r\n    uint256 public totalSpins;\r\n    \r\n    address private hubAddress;\r\n    IGamesHub private hubContract;\r\n    \r\n    uint256 public maxBet;\r\n    \r\n    event Win(address indexed player, uint256 amount, uint256 reel1, uint256 reel2, uint256 reel3);\r\n    event Loss(address indexed player, uint256 amount);\r\n    \r\n    constructor(address gameHubAddress)\r\n        public\r\n    {\r\n        hubAddress = gameHubAddress;\r\n        hubContract = IGamesHub(gameHubAddress);\r\n        \r\n        maxBet = 0.1 ether;\r\n    }\r\n    \r\n    modifier onlyHub(address sender)\r\n    {\r\n        require(sender == hubAddress);\r\n        _;\r\n    }\r\n    \r\n    modifier onlyDev()\r\n    {\r\n        require(msg.sender == address(0x1EB2acB92624DA2e601EEb77e2508b32E49012ef));\r\n        _;\r\n    }\r\n    \r\n    function play(address playerAddress, uint256 totalBetValue, bytes calldata gameData)\r\n        external\r\n        onlyHub(msg.sender)\r\n    {\r\n        bytes memory data = gameData;\r\n        uint256 betValue;\r\n        assembly {\r\n            betValue := mload(add(data, add(0x20, 0)))\r\n        }\r\n        playInternal(playerAddress, totalBetValue, betValue);\r\n    }\r\n    \r\n    function playWithBalance(uint256 totalBetValue, uint256 betValue)\r\n        external\r\n    {   \r\n        hubContract.subPlayerBalance(msg.sender, totalBetValue);\r\n        playInternal(msg.sender, totalBetValue, betValue);\r\n    }\r\n    \r\n    function resolveSpin()\r\n        external\r\n    {\r\n        Spin storage spin = getCurrentPlayerSpin(msg.sender);\r\n        require(spin.open);\r\n        \r\n        resolveInternal(msg.sender, spin);\r\n    }\r\n    \r\n    function setMaxBet(uint256 newMaxBet)\r\n        external\r\n        onlyDev\r\n    {\r\n        require(newMaxBet \u003e 0);\r\n        \r\n        maxBet = newMaxBet;\r\n    }\r\n    \r\n    function hasActiveSpin()\r\n        external\r\n        view\r\n        returns (bool)\r\n    {\r\n        return getCurrentPlayerSpin(msg.sender).open \r\n        \u0026\u0026 block.number - 256 \u003c= getCurrentPlayerSpin(msg.sender).startBlock;\r\n    }\r\n    \r\n    function mySpin()\r\n        external\r\n        view\r\n        returns(uint256 numberOfBets, uint256[10] memory reel1, uint256[10] memory reel2, uint256[10] memory reel3)\r\n    {\r\n        Spin storage spin = getCurrentPlayerSpin(msg.sender);\r\n        \r\n        require(block.number - 256 \u003c= spin.startBlock);\r\n        \r\n        numberOfBets = spin.numberOfBets;\r\n        \r\n        initReels(reel1);\r\n        initReels(reel2);\r\n        initReels(reel3);\r\n        \r\n        bytes20 senderXORcontract = bytes20(msg.sender) ^ bytes20(address(this));\r\n        bytes32 hash = blockhash(spin.startBlock) ^ senderXORcontract;\r\n        \r\n        if(block.number \u003e spin.startBlock) {\r\n            uint256 counter = 0;\r\n            for(uint256 i = 0; i \u003c numberOfBets; i++) {\r\n                reel1[i] = uint8(hash[counter++]) % 5;\r\n                reel2[i] = uint8(hash[counter++]) % 5;\r\n                reel3[i] = uint8(hash[counter++]) % 5;\r\n            }\r\n        }\r\n    }\r\n    \r\n    function initReels(uint256[10] memory reel)\r\n        private\r\n        pure\r\n    {\r\n        for(uint256 i = 0; i \u003c 10; i++) {\r\n            reel[i] = 42;\r\n        }\r\n    }\r\n    \r\n    function getCurrentPlayerSpin(address playerAddress)\r\n        private\r\n        view\r\n        returns (Spin storage)\r\n    {\r\n        return playerSpin[playerAddress];\r\n    }\r\n    \r\n    function playInternal(address playerAddress, uint256 totalBetValue, uint256 betValue)\r\n        private\r\n    {\r\n        require(betValue \u003c= maxBet);\r\n        \r\n        uint256 numberOfBets = totalBetValue / betValue;\r\n        require(numberOfBets \u003e 0 \u0026\u0026 numberOfBets \u003c= 10);\r\n        \r\n        Spin storage spin = getCurrentPlayerSpin(playerAddress);\r\n        \r\n        if(spin.open) {\r\n            resolveInternal(playerAddress, spin);\r\n        }\r\n        \r\n        playerSpin[playerAddress] = Spin(betValue, numberOfBets, block.number, true);\r\n        \r\n        totalSpins+= numberOfBets;\r\n    }\r\n    \r\n    function resolveInternal(address playerAddress, Spin storage spin)\r\n        private\r\n    {\r\n        require(block.number \u003e spin.startBlock);\r\n        \r\n        spin.open = false;\r\n        \r\n        if(block.number - 256 \u003e spin.startBlock) {\r\n            emit Loss(playerAddress, spin.betValue.mul(spin.numberOfBets));\r\n            return;\r\n        }\r\n        \r\n        bytes20 senderXORcontract = bytes20(playerAddress) ^ bytes20(address(this));\r\n        bytes32 hash = blockhash(spin.startBlock) ^ senderXORcontract;\r\n        \r\n        uint256 counter = 0;\r\n        uint256 totalAmountWon = 0;\r\n        for(uint256 i = 0; i \u003c spin.numberOfBets; i++) {\r\n            uint8 reel1 = uint8(hash[counter++]) % 5;\r\n            uint8 reel2 = uint8(hash[counter++]) % 5;\r\n            uint8 reel3 = uint8(hash[counter++]) % 5;\r\n            uint256 multiplier = 0;\r\n            if(reel1 + reel2 + reel3 == 0) {\r\n                multiplier = 20;\r\n            } else if(reel1 == reel2 \u0026\u0026 reel1 == reel3) {\r\n                multiplier = 7;\r\n            } else if(reel1 + reel2 == 0 || reel1 + reel3 == 0 || reel2 + reel3 == 0) {\r\n                multiplier = 2;\r\n            } else if(reel1 == 0 || reel2 == 0 || reel3 == 0) {\r\n                multiplier = 1;\r\n            }\r\n            \r\n            if(multiplier \u003e 0) {\r\n                uint256 amountWon = spin.betValue.mul(multiplier);\r\n                totalAmountWon = totalAmountWon.add(amountWon);\r\n                emit Win(playerAddress, amountWon, reel1, reel2, reel3);\r\n            } else {\r\n                emit Loss(playerAddress, spin.betValue);\r\n            } \r\n        }\r\n        \r\n        if(totalAmountWon \u003e 0) {\r\n            hubContract.addPlayerBalance(playerAddress, totalAmountWon);\r\n        }\r\n    }\r\n}\r\n\r\ninterface IGamesHub {\r\n    function addPlayerBalance(address playerAddress, uint256 value) external;\r\n    function subPlayerBalance(address playerAddress, uint256 value) external;\r\n}\r\n"},"SafeMath.sol":{"content":"pragma solidity 0.5.8;\r\n\r\nlibrary SafeMath {\r\n    \r\n    function mul(uint256 a, uint256 b) \r\n        internal \r\n        pure \r\n        returns (uint256 c) \r\n    {\r\n        if (a == 0) {\r\n            return 0;\r\n        }\r\n        c = a * b;\r\n        require(c / a == b, \"SafeMath mul failed\");\r\n        return c;\r\n    }\r\n\r\n    function sub(uint256 a, uint256 b)\r\n        internal\r\n        pure\r\n        returns (uint256) \r\n    {\r\n        require(b \u003c= a, \"SafeMath sub failed\");\r\n        return a - b;\r\n    }\r\n    \r\n    function add(uint256 a, uint256 b)\r\n        internal\r\n        pure\r\n        returns (uint256 c) \r\n    {\r\n        c = a + b;\r\n        require(c \u003e= a, \"SafeMath add failed\");\r\n        return c;\r\n    }\r\n}"}}