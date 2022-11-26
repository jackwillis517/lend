// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0; 

contract Lend {
    uint256 LendJTokenBalance = 1000000000000;
    mapping (address => uint256) Worthiness;
    mapping (address => uint256) Staked;
    mapping (address => uint256) TimeStaked;
    mapping (address => uint256) Borrowed;
    mapping (address => uint256) Debt;
    mapping (address => uint256) Collateral;
    mapping (address => bool) Blacklist;  

    //-------------------------------Utility functions-------------------------------//
    receive() external payable {}

    fallback() external payable {}

    // Adds a new borrower to the system with an initial worthiness of 500
    function addNewBorrower() public {
        require(Worthiness[msg.sender] == 0, "This user is already registered.");
        Worthiness[msg.sender] = 500;
    }

    // Checks if a minute has passed since a lender has provided liquidity
    function isTime(address lender) public view returns (bool) {
        if(block.timestamp >= TimeStaked[lender] + 60) {
            return true;
        } else {
            return false;
        }
    }

    function isBlacklisted(address person) public view returns (bool) {
        return Blacklist[person];
    }

    function fundContract() public payable {
        payable(address(this)).transfer(msg.value);
    }


    //-------------------------------View functions-------------------------------//
    // Allows a borrower to view their current worthiness
    function viewWorthiness() public view returns (uint256) {
        require(Worthiness[msg.sender] > 0, "User not found.");
        return Worthiness[msg.sender];
    }

    // Allows a lender to view their current Jtoken balance
    function viewJtokenBalance() public view returns (uint256) {
        return Staked[msg.sender];
    }

    function viewLiquidityTime() public view returns (uint256) {
        return TimeStaked[msg.sender];
    }

    function viewContractBalance() public view returns (uint256) {
        return LendJTokenBalance; 
    }

    function viewCollateral() public view returns (uint256) {
        return Collateral[msg.sender];
    } 

    function viewDebt() public view returns (uint256) {
        return Debt[msg.sender];
    }


    //-------------------------------Lending workflow-------------------------------//
    // Allows a lender to provide liquidity to Lend in return for redeemable interest tokens
    // A lender can only lend once for now and each JToken is worth 2 ETH for now
    function provideLiquidity() public payable {
        require(LendJTokenBalance > 0, "Lend is out of redeemable tokens at this time.");
        require(Staked[msg.sender] == 0, "You have already provided liquidity and must wait to do it again.");
        Staked[msg.sender] += msg.value / 1e18;
        LendJTokenBalance -= msg.value / 1e18;
        TimeStaked[msg.sender] = block.timestamp;
        payable(address(this)).transfer(msg.value); 
    }

    // Allows a lender to claim their interest token's value after the loan expires
    // Right now a loan expires after a minute, ideally I'd like to add a more robust
    // liquidation scheme in the future based on time and value from a price oracle
    function claimInterest() public payable {
        require(isTime(msg.sender), "You need to wait until the loan expires.");
        require(Staked[msg.sender] > 0, "No liquidity was provided to collect interest on.");
        LendJTokenBalance += Staked[msg.sender];
        payable(msg.sender).transfer((Staked[msg.sender] * 2) * 1e18); 
        Staked[msg.sender] = 0;
    } 


    //-------------------------------Borrowing workflow-------------------------------//
    // Allows a borrow to see how much collateral and debt would be incurred to borrow a specific amount
    function checkBorrow (uint256 amount) public view returns (uint256, uint256) {
        require(Blacklist[msg.sender] != true, "This borrower cannot be trusted, loan denied.");
        require(Worthiness[msg.sender] > 0, "This user hasn't registered yet, please register your wallet.");
        require(Debt[msg.sender] == 0, "This person has already borrowed ether.");
        uint256 amountInEther = amount * 1e18;

        // Debt & Collateral are recorded in Finney because of fractional values
        // Debt = (1 + (worthiness/1000)) * amount borrowed
        // Collateral = (worthiness/1000) * amount borrowed
        uint256 projectedDebt = ((1000 + Worthiness[msg.sender]) * (amountInEther / 1e15)) / 1e3;
        uint256 projectedCollateral = ((Worthiness[msg.sender]) * (amountInEther / 1e15)) / 1e3;

        return (projectedDebt, projectedCollateral);
    }
    
    // Allows a borrower to borrow ether from the protocol
    function borrowLiquidity (uint256 amount) public payable returns (bool) {
        require(Blacklist[msg.sender] != true, "This borrower cannot be trusted, loan denied.");
        require(Worthiness[msg.sender] > 0, "This user hasn't registered yet, please register your wallet.");
        require(Debt[msg.sender] == 0, "This person has already borrowed ether.");
        uint256 amountInEther = amount * 1e18;
        require((msg.value / 1e15) == ((Worthiness[msg.sender]) * (amountInEther / 1e15)) / 1e3, "The amount of collateral isn't enough.");
        Borrowed[msg.sender] = block.timestamp;
        

        // Debt & Collateral are recorded in Finney because of fractional values
        // Debt = (1 + (worthiness/1000)) * amount borrowed
        // Collateral = (worthiness/1000) * amount borrowed
        // Record the amount a borrower has to repay with interest in FINNEY
        Debt[msg.sender] = ((1000 + Worthiness[msg.sender]) * (amountInEther / 1e15)) / 1e3;

        // Record the amount a borrower must provide as collateral in order to borrow in FINNEY
        Collateral[msg.sender] = ((Worthiness[msg.sender]) * (amountInEther / 1e15)) / 1e3;


        // Transfer the required collateral from the borrower to the contract
        payable(address(this)).transfer(msg.value);
                               
        // Transfer the desired borrow amount to the borrower
        payable(msg.sender).transfer(amountInEther);


        return true;
    }
    
    // Allows a borrower to pay off their debt
    function makePayment() public payable returns (bool) {
        require(Debt[msg.sender] > 0, "The loan is already paid off.");

        if(block.timestamp <= Borrowed[msg.sender] + 60){
            // Update the users debt
            Debt[msg.sender] -= (msg.value / 1e15);
            payable(address(this)).transfer(msg.value);

            // If the user settles all of their debt then return their collateral and halve their worthiness
            if(Debt[msg.sender] == 0){
                payable(msg.sender).transfer(Collateral[msg.sender] * 1e15);
                Worthiness[msg.sender] = Worthiness[msg.sender] / 2;

                // Ensure their Worthiness doesn't drop below 50
                if(Worthiness[msg.sender] < 50){
                    Worthiness[msg.sender] = 50;
                }
            }

          // If the user attempts to make a payment after the loan expires double their worthiness
          // If their worthiness exceeds 1000 mark them blacklisted
          // Reset the users Collateral and Debt obligation
        } else {
            Collateral[msg.sender] = 0;
            Debt[msg.sender] = 0;
            Worthiness[msg.sender] = Worthiness[msg.sender] * 2;
            if(Worthiness[msg.sender] >= 1000){
                Blacklist[msg.sender] = true;
            }
        }

        return true;
    }
}