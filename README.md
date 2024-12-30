
# Fully Noded - Join Market

FN-Join Market is a [Join Market](https://github.com/JoinMarket-Org/joinmarket-clientserver) client. Meaning it connects to your Join Market server
and issues API commands over Tor or localhost to your JM Server via the [JM API](https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/api/wallet-rpc.yaml) to power all functionality of the app.

FN-Join Market is different from other FN wallets in that it is a hot wallet by design, Join market is itself a hot wallet. There is no getting around this for now as funds need to be online and ready to sign for decentralized coinjoins. Your seed can be protected with an optional passphrase and is always protected by an encryption password.

You may use Join Market as a normal wallet or as a decentralized coinjoin coordinator where makers and takers coordinate via bots to partake in coinjoins. Makers can earn a small fee and takers must pay a fee.

In FN-Join Market you can eaily create a Fidelity Bond and start the maker to potentially earn sats, you can also easily initiate a coinjoin via the coinjoin button in the UI. The UI is self explanatory.

The easiest way to get up and running for Mac users is via [Fully Noded - Server](https://github.com/Fonta1n3/FullyNoded-Server), you can also install Join Market manually with this [guide](https://github.com/JoinMarket-Org/joinmarket-clientserver/tree/master?tab=readme-ov-file#quickstart---recommended-installation-method-linux-and-macos-only).

There is ample reading and nuance to consider when using Join Market, see the [main repo](https://github.com/JoinMarket-Org/joinmarket-clientserver) for a deep dive.


