// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TraceableTransactions {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    struct Transaction {
        string txId;
        address sender;
        address receiver;
        uint amount;
        uint timestamp;
        bool flagged;
        string flagReason;
    }

    struct KYCData {
        string tag; // KYC/PASSPORT/etc
    }

    mapping(string => Transaction) public transactions;
    mapping(address => string[]) public userTxs;
    mapping(address => KYCData) public kycData;

    event TransactionRecorded(
        string txId,
        address from,
        address to,
        uint amount,
        uint timestamp
    );
    event TransactionFlagged(
        string txId,
        string reason
    );
    event KYCAdded(address user, string tag);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    // --- MANDATORY ---

    function recordTransaction(
        string calldata txId,
        address from,
        address to,
        uint amount
    ) external onlyOwner {
        require(transactions[txId].timestamp == 0, "Tx exists");
        transactions[txId] = Transaction(
            txId, from, to, amount, block.timestamp, false, ""
        );
        userTxs[from].push(txId);
        userTxs[to].push(txId);
        emit TransactionRecorded(txId, from, to, amount, block.timestamp);
    }

    function getTransaction(string calldata txId)
        external
        view
        returns (
            address from,
            address to,
            uint amount,
            uint timestamp,
            bool flagged,
            string memory flagReason
        )
    {
        Transaction memory t = transactions[txId];
        return (t.sender, t.receiver, t.amount, t.timestamp, t.flagged, t.flagReason);
    }

    function getUserTransactions(address user) external view returns (string[] memory) {
        return userTxs[user];
    }

    // Get all sent (downstream) transactions from an address
    function getSentTransactions(address user) public view returns (string[] memory) {
        uint count = 0;
        for (uint i = 0; i < userTxs[user].length; i++) {
            if (transactions[userTxs[user][i]].sender == user)
                count++;
        }
        string[] memory result = new string[](count);
        uint idx = 0;
        for (uint i = 0; i < userTxs[user].length; i++) {
            if (transactions[userTxs[user][i]].sender == user)
                result[idx++] = userTxs[user][i];
        }
        return result;
    }

    // --- BONUS ---

    function traceFlow(address root)
        external
        view
        returns (string[] memory)
    {
        // Use an expanding array for simplicity (return list of txIds in flow)
        string[] memory result = new string[](100); // Max flow depth 100
        bool[] memory visited = new bool[](100);    // For loop detection and to avoid double-counting
        uint pos = 0;
        _dfsTrace(root, result, pos, visited);
        // Compact result for returning only non-empty txIds
        uint cnt = 0;
        for (uint i = 0; i < result.length; i++) {
            if (bytes(result[i]).length != 0)
                cnt++;
        }
        string[] memory cleanResult = new string[](cnt);
        cnt = 0;
        for (uint i = 0; i < result.length; i++) {
            if (bytes(result[i]).length != 0)
                cleanResult[cnt++] = result[i];
        }
        return cleanResult;
    }

    // Depth-limited, linear memory DFS
    function _dfsTrace(address curr, string[] memory result, uint pos, bool[] memory visited)
        internal
        view
    {
        string[] memory sent = getSentTransactions(curr);
        for (uint i = 0; i < sent.length; i++) {
            // Avoid double-counting if already seen
            bool already = false;
            for (uint k = 0; k < result.length; k++) {
                if (keccak256(bytes(result[k])) == keccak256(bytes(sent[i])))
                    already = true;
            }
            if (!already && pos < result.length) {
                result[pos++] = sent[i];
                address next = transactions[sent[i]].receiver;
                if (next != curr) { // loop prevention by self-transfer
                    _dfsTrace(next, result, pos, visited);
                }
            }
        }
    }

    function flagTransaction(string calldata txId, string calldata reason) external onlyOwner {
        require(transactions[txId].timestamp != 0, "Tx does not exist");
        transactions[txId].flagged = true;
        transactions[txId].flagReason = reason;
        emit TransactionFlagged(txId, reason);
    }

    function updateKYC(address user, string calldata tag) external onlyOwner {
        kycData[user].tag = tag;
        emit KYCAdded(user, tag);
    }

    function getKYC(address user) external view returns (string memory) {
        return kycData[user].tag;
    }
}
