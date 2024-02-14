# Aztec Noir Lottery 

This project implements a decentralized lottery system on the Aztec Network, leveraging the power of zero-knowledge proofs for privacy.

## Core Features

* **Ticket Purchases:** Users can purchase lottery tickets using your Token contract. Verification ensures that each user can only buy one ticket per lottery drawing.
* **Public Entry:** Participants enter the lottery via a public function call. Users must hold a valid lottery ticket at the time of entry. 
* **Time-Based Logic:** The lottery executes periodically (using a passed-in block timestamp from outside the ZKP environment). When the interval since the last lottery exceeds a threshold, the smart contract determines a winner.
* **Secure Winner Selection:** A hash-based mechanism (replace with an oracle like Chainlink VRF in production) selects a winner from the entered participants.
* **Transparency:** While preserving privacy, relevant lottery information can be logged for debugging and potential auditing.

## Smart Contract Overview

* **Token Contract (`contracts/Token.no`)** 
    * **`buy_Tickets()`**: Handles the purchase of lottery tickets using the token.  Implements price determination and user balance checks.
    * **`transfer_public()`:** Facilitates token transfers between users as needed (e.g., for sending winnings).
    * **`balance_of_public()`:**  Allows checking a user's token balance. 
    * **... (Add descriptions for other relevant functions in your Token contract)** 

* **Lottery Contract (`contracts/Lottery.no`)**
    * **`enter_lottery()`** 
        * Verifies the prospective entrant holds a valid lottery ticket.
        * Records the entrant's address.
        * Transfers the ticket cost to the lottery contract's balance.
        * Implements the core time-based lottery execution trigger.
    * **`some_hash()`** [Placeholder]: Function responsible for generating a pseudo-random number to aid in winner selection.  **Important:**  Replace with a secure mechanism, preferably  an oracle, in production.
    * **`_initialize()`**: Handles smart contract setup, such as setting an initial admin.

## Getting Started

### Prerequisites
* Node.js and npm (or yarn)
* Basic understanding of Aztec Noir and zero-knowledge proof concepts

### Try it on Gitpod

Click here to launch a pre-configured development environment in Gitpod!: [https://gitpod.io/#https://github.com/Lottery-Aztec-Noir/Lottery](https://gitpod.io/#https://github.com/Lottery-Aztec-Noir/Lottery)

### Setting Up a Local Development Environment

1. **Clone the repository:**
   ```bash
   git clone [https://gitpod.io/#https://github.com/Lottery-Aztec-Noir/Lottery](https://gitpod.io/#https://github.com/Lottery-Aztec-Noir/Lottery)
