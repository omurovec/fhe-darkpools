# FHE Dark Pools

This is a hackathon project for the ethcc6 Fhenix & ZAMA hackathon.

This project is an effort to recreate Dark Pools in a decentralized form.
Dark Pools are a popular offering in tradfi where parties can create buy or sell orders without revealing the size or price of their order.
This is very beneficial for large trades which would drastically impact the market causing an unsatisfactory execution price or otherwise suffer from high frequency trading.

As far as I know, Dark pools are not possible within the contraints of the EVM since there is no way to obfuscate the order size or price while allowing buy & sell orders to be matched with eachother unless there is a singular party who can see the orders.

With FHE, we can encrypt the order size & price while still allowing solvers/market makers to match orders.
Using FHE, solvers can watch new orders and check for orders with equal prices then fill those orders.

This repo only contains the contracts for the dark pools.
Given more time, I would build out a front-end and solvers to match the orders.

## Setup

### 1. Start local network

```sh
docker run -it -p 8545:8545 -p 6000:6000 \
  --name localfhenix ghcr.io/fhenixprotocol/fhenix-devnet:0.1.6
```

### 2. Grab funds from faucet

```sh
curl "http://localhost:6000/faucet?address=${ADDRESS}"
```

## Notes

- Tests don't seem to be working properly, could be due to the TFHE lib or I could be dumb 🫠🤷
