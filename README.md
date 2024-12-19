# Monorail Contracts

## Installation

Run clone the repo and run `nvm install && nvm use && npm install` if you have nvm installed.
If you don't ensure that you have the proper version in .nvmrc set and run
`npm install`.

## Deployment

### Deploy to Testnet

```shell
chmod +x ./deploy.sh && deploy.sh testnet
```

### Deploy to Mainnet

```shell
chmod +x ./deploy.sh && deploy.sh
```

## Testing

```shell
forge test
```