# FHE Dark Pools

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
