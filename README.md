# Proof of Humanity Group Currency

## **Proof of Humanity**

In order to register on Proof of Humanity, the users upload a photo and a video of themselves which should prove their uniqueness in the registry. Afterwards, they need a deposit and a vouch from someone already registered. A challenging period follows where others can challenge the submission for certain mistakes or sybil attack, in which case a dispute is created in the Kleros Court. If the court decides that the challenger is right, he gets the submission deposit. Registrants that passed the challenge period without being challenged for a good reason will become part of the registry.

### **Proof of Humanity v2**

The new version of Proof of Humanity extends the registry to Gnosis Chain, allowing registrations and relaying of profile state between Ethereum mainnet and Gnosis Chain. 

It also implements a new feature of a soulbound ID - POH ID. The POH ID is an ID permanently unique per human. When registering for the first time, it is derived automatically from the address. Otherwise it must be specified by the user, with the challenging mechanism incentivising the user to choose the correct POH ID assigned to his identity.

The POH ID allows for a sybil resistant digital identity and serves as a very robust solution to social recovery for the crypto ecosystem.


## **Circles**
Circles is an alternative currency system. It is based on individualized currencies and a social graph of trust between these currencies. It is unconditionally paid at regular intervals to individuals, functioning as a globally accessible Universal Basic Income.


### **Trust**

With Circles, each person exercises the power to issue credit to peers. Alone these are called personal currencies. Personal currency starts to circulate once somebody trusts them in a network whose structure depends on the trust people have with each other.

### **Personal currency**

When a person joins, a new personal cryptocurrency is created for them on the blockchain via a smart contract. The currency can then be regularly minted to increase the balance of the owner.

<br>

You can find more about Circles by visiting [the website](https://joincircles.net) or get an in-depth understanding by reading [the whitepaper](https://handbook.joincircles.net/docs/developers/whitepaper).

<br>


## **Proof of Humanity <-> Circles**

Group currency is a Circles primitive that allows exchanging personal tokens for group tokens

### **Becoming member**

In order for the personal token to become member of the Proof of Humanity group and be able to mint group tokens, it must correspond to a PoH ID. The user must have a wallet registered on Proof of Humanity and another one (or the same) owning a personal Circles currency.

If the PoH registered wallet also owns the personal token, a single transaction is needed to add the token as member. Otherwise 2 are required:
- *from PoH wallet* - confirm personal token
- *from wallet owning personal token* - confirm humanity

### **Minting group tokens**

Once a personal currency has been added as member to the group it is possible to use it as collateral to mint Proof of Humanity Group Tokens ($HGT). The personal tokens are sent to the treasury and, in exchange, the person receives the same amount of group currency.

>- Alice is registered in Proof of Humanity
>- Bob has 10 AliceCoin
>- Bob uses 10 AliceCoin to mint $POH
>- Now Bob has 10 $POH
>- The group currency treasury has 10 (more) AliceCoin

### **Redeeming personal tokens**

The group tokens can further be used to redeem personal tokens from the treasury. Thus when the user has group currency, he can get any of the personal currency tokens in the treasury in the same amount as the number of group tokens offered, which will be burned.

>- There are 10 AliceCoin and 5 BobCoin in treasury
>- Carol has 8 $POH
>- Carol uses the 8 $POH to redeem 3 AliceCoin and 5 BobCoin
>- Carol now has 3 AliceCoin and 5 BobCoin
>- The treasury is left with 7 AliceCoin

### **Replacing the token**

