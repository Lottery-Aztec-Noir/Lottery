# Token Contract

This repository contains a smart contract for a token system built on the Aztec protocol. The contract allows users to buy tickets for a lottery, with the winner being chosen by the admin. The contract also includes functionality for transferring tokens and checking balances.

## Features

- **Ticket Purchase**: Users can buy lottery tickets if they are over  18 and under  100 years old.
- **Lottery Winner Selection**: The admin can choose the winner of the lottery using a random number.
- **Token Transfer**: Users can transfer tokens to other addresses.
- **Balance Checking**: Users can check their token balance.

## Installation

To interact with this contract, you will need to have the Aztec protocol installed and configured on your system. Follow the instructions provided by the Aztec protocol documentation to set up your environment.

## Usage

### Buying Tickets

To buy a ticket, call the `buy_Tickets` function with the current date and your birth date. Ensure you are over  18 and under  100 years old.



### Choosing the Winner

The admin can choose the winner of the lottery by calling the `chooseWinner` function with a random number.


### Transferring Tokens

To transfer tokens, call the `transfer_public` function with the recipient's address and the amount to transfer.


## Gitpod

[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#https://github.com/Lottery-Aztec-Noir/Lottery)

Click the button above to open this project in a new Gitpod workspace. Gitpod is an online IDE that allows you to develop directly in your browser without the need to set up a local development environment.


## Contributing

If you would like to contribute to this project, please fork the repository, make your changes, and create a pull request to the main branch.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

