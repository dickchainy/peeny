// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Peeny is ERC20, Ownable {
    uint256 private constant MILLION = 1000000;
    uint256 private constant NUMBER_OF_COINS_MINTED = 100 * MILLION;

    // How many Peeny have been claimed through contribute()
    uint256 public peenyReserved = 0;
    // How many Peeny have been given out through issue()
    uint256 public peenyDistributed = 0;
    uint256 private numberOfContributions = 1;

    // Each contribution must be at least minimumContributionWei or it will fail.
    uint256 private minimumContributionWei = 100000000000000;

    // How much WEI has been received by the ICO.
    uint256 public contributionsReceived = 0;

    bool private icoOpen = true;

    // When <i> million Peeny have been sold, exchangeRate[i] contains the price
    // in Wei of one MicroPeeny (10^12) until the next million Peeny is sold,
    // after which exchangeRate[i+1] will be used for the next million Peeny.
    uint256[90] exchangeRates = [300, 360, 432, 518, 622, 746, 895, 1074, 1289, 1547, 1857, 2229, 2674, 3209, 3851, 4622, 5546, 6655, 7986, 9584, 11501, 13801, 16561, 19874, 23849, 28618, 34342, 41211, 49453, 59344, 71212, 85455, 102546, 123055, 147667, 177200, 212640, 255168, 306202, 367442, 440931, 529117, 634941, 761929, 914315, 1097178, 1316614, 1579937, 1895924, 2275109, 2730131, 3276157, 3931389, 4717667, 5661200, 6793440, 8152128, 9782554, 11739065, 14086878, 16904254, 20285105, 24342126, 29210551, 35052661, 42063194, 50475832, 60570999, 72685199, 87222239, 104666687, 125600024, 150720029, 180864035, 217036842, 260444210, 312533052, 375039663, 450047596, 540057115, 648068538, 777682246, 933218695, 1119862434, 1343834921, 1612601905, 1935122287, 2322146744, 2786576093, 3343891312];

    struct Funder {
        uint256 donation;
        uint256 numberOfCoins;
        // Add date
    }

    event LogUint256(uint256 val, string message);
    event Issue(Funder funder);

    mapping(address => Funder) public contributions;

    // List of contributors who have contributed and need to be issued Peeny.
    address[] contributors;
    constructor() ERC20("Peeny", "PP") {
        _mint(msg.sender, NUMBER_OF_COINS_MINTED * 10 ** decimals());
    }

    // Suport the Peeny ICO! Thank you for your support of the Dick Chainy foundation.
    // If you've altready contributed, you can't contribute again until your coins have
    // been distributed.
    function contribute() public payable {
        require(icoOpen, "The Peeny ICO has now ended.");
        require(msg.value >= minimumContributionWei, "Minimum contribution must be at least getMinimumContribution(). ");
        Funder storage funder = contributions[address(msg.sender)];
        require(funder.numberOfCoins == 0 && funder.donation == 0, "You have already contributed a donation and will be receiving your Peeny shortly. Please wait until you receive your Peeny before making another contribution. Thanks for supporting the Dick Chainy Foundation!");
        funder.donation = msg.value;
        contributionsReceived += funder.donation;
        funder.numberOfCoins = donationInWeiToPeeny(msg.value);

        contributors.push(msg.sender);

        peenyReserved += funder.numberOfCoins;
        numberOfContributions++;
    }
    
    // When donating Wei, the user will receive Peeny according to the exchange rate.
    // The current exchange rate is stored in the public variable weiToMicroPeeny, but
    // every 1 million Peeny that are sold will decrease the amount of MicroPeeny granted
    // for the same amount of Wei.
    // Note that contribute will add the user's contribution to a the contributions mapping,
    // but coins are not guaranteed based on the response of this function. They will be
    // granted in order based on when Funders were added to the contributions mapping, so
    // this function will be an upper bound on the amount of Peeny granted. The amount of
    // Peeny can be less if another contribution is made in the same block which causes the
    // number of coins granted to go beyond the next million Peeny because the exchange rate
    // will change due to the other contribution.
    function _donationInWeiToPeeny(uint256 donation, uint256 inPeenyDistributed) view public returns (uint256) {
        // This can be peenyReserved (from contribute) or peenyDistributed (from issue).
        uint256 tempPeenyDistributed = inPeenyDistributed;

        uint256 estimatedPeeny = 0;

        uint256 numLoops = 0;
        while (donation > 0 && tempPeenyDistributed <= NUMBER_OF_COINS_MINTED * 10**decimals() * 9 / 10) {
            // Integer 0-90, how many millions of peeny have been sold
            uint256 currentMillionPeeny = tempPeenyDistributed / MILLION / 10 ** decimals();
            assert(currentMillionPeeny <= 89);
            uint256 nextMillionPeeny = currentMillionPeeny + 1;
            uint256 tempExchangeRate = exchangeRates[currentMillionPeeny];

            // peeny = wei * wei / micropeeny * peeny / micropeeny
            uint256 peenyAtCurrentExchangeRate = donation * 10**12  / tempExchangeRate;

            // If we don't go over to the next million)
            if (peenyAtCurrentExchangeRate + tempPeenyDistributed <= nextMillionPeeny * MILLION * 10 ** decimals()) {
                tempPeenyDistributed += peenyAtCurrentExchangeRate;
                estimatedPeeny += peenyAtCurrentExchangeRate;
                donation -= donation;
            } else {
                estimatedPeeny += nextMillionPeeny * MILLION * 10 ** decimals() - tempPeenyDistributed;
                donation -= (nextMillionPeeny * MILLION * 10 ** decimals() - tempPeenyDistributed) * tempExchangeRate / 10**12;
                tempPeenyDistributed = nextMillionPeeny * MILLION * 10 ** decimals();
            }

            // tempExchangeRate = (tempExchangeRate * 120 / 100);
            numLoops++;
        }
        return estimatedPeeny;
    }
    
    function donationInWeiToPeeny(uint256 donation) view public returns (uint256) {
        return _donationInWeiToPeeny(donation, peenyReserved);
    }

    function issue() onlyOwner public payable {
        address funderAddress = contributors[contributors.length- 1];
        Funder memory funder = contributions[funderAddress];

        transfer(funderAddress, funder.numberOfCoins);
        peenyDistributed += funder.numberOfCoins;

        emit Issue(funder);
        contributors.pop();
        delete contributions[funderAddress];
    }

    function withdrawPartialFunds(uint256 balance) onlyOwner public {
        require(address(this).balance > 0, "withdrawFunds(): Cannot withdraw when balance is zero.");
        payable(owner()).transfer(balance);
    }

    function withdrawFunds() onlyOwner public {
        require(address(this).balance > 0, "withdrawFunds(): Cannot withdraw when balance is zero.");

        uint balance = address(this).balance;
        payable(owner()).transfer(balance);
    }

    // Just in case someone tries to be mean.
    function setMinContributionWei(uint256 minContribution) onlyOwner public {
        minimumContributionWei = minContribution;
    }

    function closeIco() onlyOwner public {
        icoOpen = false;
    }

    function reopenIco() onlyOwner public {
        icoOpen = true;
    }

    // The minimum amount of value allowed in a contribute() call.
    function getMinimumContribution() public view returns (uint256) {
        return minimumContributionWei;
    }
}
