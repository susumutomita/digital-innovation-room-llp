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
///         - Lock split table
///         - Accept ERC20 deposits
///         - Distribute pro-rata based on locked shares
contract Engagement {
    enum Status {
        OPEN,
        LOCKED,
        CANCELLED
    }

    event SplitUpdated(address[] recipients, uint256[] sharesBps);
    event Locked();
    event Cancelled();
    event Deposited(address indexed payer, uint256 amount);
    event Distributed(address indexed token, uint256 amount);
    event Paid(address indexed token, address indexed to, uint256 amount);

    uint256 public constant TOTAL_BPS = 10_000;

    address public immutable admin;
    IERC20 public immutable token;
    Status public status;

    address[] public recipients;
    uint256[] public sharesBps;

    constructor(address _admin, IERC20 _token) {
        admin = _admin;
        token = _token;
        status = Status.OPEN;
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
