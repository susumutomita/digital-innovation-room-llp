// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @title Engagement
/// @notice Per-engagement revenue splitter.
///         - Set split table while OPEN
///         - (Optionally) set match window + metadataURI while OPEN
///         - Lock split table (manual) or finalize after deadline (permissionless)
///         - Accept ERC20 deposits
///         - Distribute pro-rata based on locked shares
contract Engagement {
    enum Status {
        OPEN,
        LOCKED,
        CANCELLED
    }

    event MetadataURIUpdated(string metadataURI);
    event MatchWindowUpdated(uint64 startAt, uint64 endAt);

    event SplitUpdated(address[] recipients, uint256[] sharesBps);
    event Locked();
    event Cancelled();
    event Finalized(Status status);

    event Deposited(address indexed payer, uint256 amount);
    event Distributed(address indexed token, uint256 amount);
    event Paid(address indexed token, address indexed to, uint256 amount);

    uint256 public constant TOTAL_BPS = 10_000;

    address public immutable admin;
    IERC20 public immutable token;
    Status public status;

    /// @notice Off-chain reference (e.g. MoneyForward invoice id / bank transfer reference)
    ///         or an IPFS/HTTPS URL containing richer metadata.
    string public metadataURI;

    /// @notice Matching window. Before endAt: members coordinate & set split.
    /// After endAt: anyone can finalize (LOCK if split set, otherwise CANCEL).
    uint64 public startAt;
    uint64 public endAt;

    address[] public recipients;
    uint256[] public sharesBps;

    constructor(address _admin, IERC20 _token, uint64 _startAt, uint64 _endAt, string memory _metadataURI) {
        admin = _admin;
        token = _token;
        status = Status.OPEN;

        require(_endAt == 0 || _endAt >= _startAt, "BAD_WINDOW");
        startAt = _startAt;
        endAt = _endAt;
        metadataURI = _metadataURI;

        emit MatchWindowUpdated(_startAt, _endAt);
        emit MetadataURIUpdated(_metadataURI);
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "NOT_ADMIN");
        _;
    }

    modifier inStatus(Status s) {
        require(status == s, "BAD_STATUS");
        _;
    }

    function recipientsLength() external view returns (uint256) {
        return recipients.length;
    }

    function setMetadataURI(string calldata _metadataURI) external onlyAdmin inStatus(Status.OPEN) {
        metadataURI = _metadataURI;
        emit MetadataURIUpdated(_metadataURI);
    }

    function setMatchWindow(uint64 _startAt, uint64 _endAt) external onlyAdmin inStatus(Status.OPEN) {
        require(_endAt == 0 || _endAt >= _startAt, "BAD_WINDOW");
        startAt = _startAt;
        endAt = _endAt;
        emit MatchWindowUpdated(_startAt, _endAt);
    }

    function setSplit(address[] calldata _recipients, uint256[] calldata _sharesBps)
        external
        onlyAdmin
        inStatus(Status.OPEN)
    {
        require(_recipients.length > 0, "EMPTY");
        require(_recipients.length == _sharesBps.length, "LEN_MISMATCH");

        uint256 sum;
        for (uint256 i = 0; i < _recipients.length; i++) {
            require(_recipients[i] != address(0), "ZERO_RECIPIENT");
            require(_sharesBps[i] > 0, "ZERO_SHARE");
            sum += _sharesBps[i];
        }
        require(sum == TOTAL_BPS, "BPS_NOT_100");

        recipients = _recipients;
        sharesBps = _sharesBps;

        emit SplitUpdated(_recipients, _sharesBps);
    }

    function lock() external onlyAdmin inStatus(Status.OPEN) {
        require(recipients.length > 0, "SPLIT_NOT_SET");
        status = Status.LOCKED;
        emit Locked();
    }

    function cancel() external onlyAdmin inStatus(Status.OPEN) {
        status = Status.CANCELLED;
        emit Cancelled();
    }

    /// @notice Finalize after matching window ends.
    /// Anyone can call this to avoid “backend admin work”.
    /// - If split was set => LOCKED
    /// - If no split => CANCELLED (NO-GO)
    function finalize() external inStatus(Status.OPEN) {
        require(endAt != 0, "NO_DEADLINE");
        require(block.timestamp >= endAt, "TOO_EARLY");

        if (recipients.length > 0) {
            status = Status.LOCKED;
            emit Locked();
        } else {
            status = Status.CANCELLED;
            emit Cancelled();
        }

        emit Finalized(status);
    }

    function deposit(uint256 amount) external inStatus(Status.LOCKED) {
        require(amount > 0, "ZERO_AMOUNT");
        bool ok = token.transferFrom(msg.sender, address(this), amount);
        require(ok, "TRANSFER_FROM_FAILED");
        emit Deposited(msg.sender, amount);
    }

    /// @notice Distribute the entire current token balance according to shares.
    ///         Remainder (due to rounding) goes to the last recipient.
    function distribute() external inStatus(Status.LOCKED) {
        uint256 bal = token.balanceOf(address(this));
        require(bal > 0, "NO_BALANCE");

        uint256 sent;
        uint256 n = recipients.length;
        for (uint256 i = 0; i < n; i++) {
            uint256 amt;
            if (i == n - 1) {
                amt = bal - sent;
            } else {
                amt = (bal * sharesBps[i]) / TOTAL_BPS;
                sent += amt;
            }

            bool ok = token.transfer(recipients[i], amt);
            require(ok, "TRANSFER_FAILED");
            emit Paid(address(token), recipients[i], amt);
        }

        emit Distributed(address(token), bal);
    }
}
