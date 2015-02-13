module.exports =
  mail: require "../mail"
  ecc: require "../ecc"
  common: require "../common"
  wallet: require "../wallet"
  client: require "../client"
  hash: require '../ecc/hash'
  secureRandom: require 'secure-random'
  developer:
    password: 'Password00'
    brainkey: 'WARNING: Anyone with access to your brain key will have access to this wallet.'
